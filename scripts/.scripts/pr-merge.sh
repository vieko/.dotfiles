#!/usr/bin/env bash
# pr-merge.sh -- squash-merge a green PR and close the loop: confirm the
# merge, report the linked Linear issue's state, remove the worktree, delete
# the branch locally and on origin. The merge sequence from the global
# AGENTS.md ("PR announcements"), as one command.
#
# Usage:
#   pr-merge.sh <pr> [--dry-run] [--allow-unstable] [--keep-branch] [--no-linear]
#
#   Run it inside the repo (main checkout or any worktree of it).
#   --dry-run         print what it would do; change nothing.
#   --allow-unstable  merge when GitHub reports UNSTABLE (required checks
#                     pass, a non-required one failed). Default: refuse.
#   --keep-branch     merge only; leave worktree and branches alone.
#   --no-linear       skip the Linear state check and the cycle step.
#
# It never bypasses anything: no --admin, no force. A PR that is not CLEAN
# (BLOCKED, BEHIND, DIRTY, a pending check) exits 1 with the reason; wait
# with pr-wait first. A PR that is already merged skips to the cleanup, so a
# rerun after a partial cleanup is safe.
#
# Security (vercel/* repos, Vercel CLI 65.17+): any open critical or high
# Vercel Security Review finding on the head branch refuses the merge (a
# fixed one blocks until the rescan closes it); other open findings print as
# warnings. If the lookup cannot run (old or
# missing vc, expired login), it says so and does not block. It only reads:
# dismissing a finding is the user's decision (vc security vulnerabilities
# dismiss). PR_WAIT_VERCEL_SCOPE overrides the Vercel team.
#
# Linear: the GitHub integration moves a linked issue to Done about 3 s after
# the merge (measured 2026-11-15 on 7 PRs). The script waits up to 30 s and
# reports the state; it does not change it, but it adds my GTMENG issue to
# the active cycle (linear-cycle-sync.sh). Agents that set Done in the same
# batch as the merge raced the integration and reported "left at In Progress"
# 10 times in week 46.
#
# Cleanup safety: a worktree stays when a process has its cwd in it (lsof) or
# it has uncommitted changes. The remote branch stays when an open PR uses it
# as its base (a stacked PR) or the PR comes from a fork. `gh pr merge
# --delete-branch` is not used: since gh 2.99 it also removes the head
# branch's worktree, even when a job runs from it.
#
# Exit: 0 merged and clean, 1 not mergeable or the merge failed, 2 usage,
# 3 merged but some cleanup was left (the output says what).

set -uo pipefail

die() { echo "error: $*" >&2; exit 2; }

pr="" allow_unstable=0 keep_branch=0 linear=1 dry=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) dry=1 ;;
    --allow-unstable) allow_unstable=1 ;;
    --keep-branch) keep_branch=1 ;;
    --no-linear) linear=0 ;;
    -h|--help) sed -n '2,35p' "$0"; exit 0 ;;
    -*) die "unknown flag $1" ;;
    *) [[ -z "$pr" ]] || die "one PR at a time"; pr=${1#\#} ;;
  esac
  shift
done
[[ "$pr" =~ ^[0-9]+$ ]] || die "usage: pr-merge.sh <pr number> [--allow-unstable] [--keep-branch] [--no-linear]"
command -v gh >/dev/null || die "gh not found"
git rev-parse --git-dir >/dev/null 2>&1 || die "run it inside the repo"

info=$(gh pr view "$pr" --json state,mergeStateStatus,headRefName,headRefOid,baseRefName,isCrossRepository,url,mergeCommit 2>&1) ||
  { echo "[ERROR] gh pr view $pr: $info"; exit 1; }
field() { jq -r "$1" <<<"$info"; }
here="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
# shellcheck source=scripts/.scripts/lib/pr-wait/vercel-security.sh
. "$here/lib/pr-wait/vercel-security.sh"
state=$(field .state) mss=$(field .mergeStateStatus) head=$(field .headRefName) cross=$(field .isCrossRepository)

if [[ "$state" == MERGED ]]; then
  echo "[INFO] #$pr is already merged; cleanup only"
elif [[ "$state" != OPEN ]]; then
  echo "[ERROR] #$pr is $state"; exit 1
else
  # GitHub computes mergeability lazily; UNKNOWN right after a push.
  for _ in {1..10}; do
    [[ "$mss" == UNKNOWN ]] || break
    sleep 2
    info=$(gh pr view "$pr" --json state,mergeStateStatus,headRefName,headRefOid,baseRefName,isCrossRepository,url,mergeCommit 2>/dev/null) && mss=$(field .mergeStateStatus)
  done
  case "$mss" in
    CLEAN|HAS_HOOKS) ;;
    UNSTABLE) (( allow_unstable )) || { echo "[ERROR] #$pr is UNSTABLE: a non-required check failed. Rerun with --allow-unstable if that is expected."; exit 1; } ;;
    *) echo "[ERROR] #$pr is not mergeable: $mss (BLOCKED = checks or review pending, BEHIND = update the branch, DIRTY = conflicts)"
       (( dry )) || exit 1 ;;
  esac
  # Vercel Security Review (vercel/* repos): refuse any open critical or high
  # finding on the head branch. foundIn is the FIRST commit a finding was
  # seen in and does not move on later scans, so an older foundIn does not
  # mean fixed: a fixed finding blocks only until the rescan closes it.
  # Lower severities are the user's call. A lookup that cannot run is
  # reported and does not block.
  repo_path=$(field .url); repo_path=${repo_path#https://*/}; repo_path=${repo_path%/pull/*}
  sec=$(vercelSecurityJson "$repo_path" "$head" "$(field .headRefOid)")
  if [[ "$(jq -r .available <<<"$sec")" == true ]]; then
    blocking=$(jq -r '[.findings[] | select(.severity == "critical" or .severity == "high")]
      | map("  \(.severity) \(.id) \(.title)" + (if .onHead then " (found in the head commit)"
          else " (found in \((.foundIn // "?")[0:7]), older than the head: if you fixed it, wait for the rescan, or dismiss it in Vercel)" end))
      | .[]' <<<"$sec")
    if [[ -n "$blocking" ]]; then
      echo "[ERROR] #$pr has open critical/high Vercel Security Review findings on its branch:"
      echo "$blocking"
      (( dry )) || exit 1
    fi
    jq -r '.findings[] | select(.severity != "critical" and .severity != "high")
      | "[WARN] open security finding: \(if (.severity | IN("medium", "low")) then .severity else "unknown severity \(.severity // "")" end) \(.id) \(.title)"' <<<"$sec"
    jq -r 'if (.unavailableScopes // []) | length > 0 then "[WARN] security findings not read for: \(.unavailableScopes | join(", "))" else empty end' <<<"$sec"
  elif [[ "$repo_path" == vercel/* ]]; then
    echo "[INFO] security findings unavailable: $(jq -r .reason <<<"$sec")"
  fi
  if (( dry )); then
    echo "[DRY] would squash-merge #$pr ($mss), then clean up $head"
  else
    out=$(gh pr merge "$pr" --squash 2>&1) || { echo "[ERROR] gh pr merge: $out"; exit 1; }
  fi
  for _ in {1..15}; do
    (( dry )) && break
    info=$(gh pr view "$pr" --json state,mergeStateStatus,headRefName,headRefOid,baseRefName,isCrossRepository,url,mergeCommit 2>/dev/null) || continue
    [[ "$(field .state)" == MERGED ]] && break
    sleep 2
  done
  (( dry )) || [[ "$(field .state)" == MERGED ]] || { echo "[ERROR] #$pr did not reach MERGED within 30 s (state $(field .state))"; exit 1; }
fi
sha=$(field '.mergeCommit.oid // ""' | cut -c1-10)
(( dry )) || echo "[OK] #$pr merged ${sha:+as $sha}"

# Linear: the issue key comes from the branch (vieko/gtmeng-4761 -> GTMENG-4761).
if (( linear && !dry )) && key=$(grep -oiE '[a-z]{2,10}-[0-9]+' <<<"$head" | head -1) && [[ -n "$key" ]] && command -v linear >/dev/null; then
  key=$(tr 'a-z' 'A-Z' <<<"$key") lstate=""
  # linearis returns the state name only (no type), so match final names.
  final='^(Done|Canceled|Cancelled|Duplicate|Closed|Released)$'
  for _ in {1..10}; do
    lstate=$(linear issues read "$key" --fields state.name 2>/dev/null | jq -r '.state.name // ""' 2>/dev/null) || lstate=""
    [[ -z "$lstate" || "$lstate" =~ $final ]] && break
    sleep 3
  done
  if [[ -z "$lstate" ]]; then echo "[INFO] $key: not found in Linear (or no access); check by hand if it is an issue"
  elif [[ "$lstate" =~ $final ]]; then echo "[OK] $key: $lstate"
  else echo "[WARN] $key: still $lstate after 30 s; move it only if the work is complete"; fi
  # Finished work joins the active cycle (rule (b), linear-cli skill).
  if [[ -n "$lstate" ]] && command -v linear-cycle-sync.sh >/dev/null; then
    linear-cycle-sync.sh --issue "$key" --apply --quiet || echo "[WARN] $key: could not add it to the active cycle"
  fi
fi

(( keep_branch )) && exit 0

left=0
# Worktree of the head branch, if any.
wt=$(git worktree list --porcelain | awk -v b="refs/heads/$head" '/^worktree /{p=substr($0,10)} $0=="branch "b{print p}')
main_wt=$(git worktree list --porcelain | awk '/^worktree /{print substr($0,10); exit}')
if [[ -n "$wt" && "$wt" != "$main_wt" ]]; then
  if lsof -d cwd 2>/dev/null | grep -qF "$wt"; then echo "[WARN] worktree $wt: a process has its cwd there; left it"; left=1
  elif [[ -n "$(git -C "$wt" status --porcelain 2>/dev/null)" ]]; then echo "[WARN] worktree $wt has uncommitted changes; left it"; left=1
  elif (( dry )); then echo "[DRY] would remove worktree $wt"
  elif git worktree remove "$wt" 2>/dev/null || git worktree remove --force "$wt" 2>/dev/null; then echo "[OK] removed worktree $wt"
  else echo "[WARN] could not remove worktree $wt"; left=1; fi
elif [[ "$wt" == "$main_wt" && -n "$wt" ]]; then
  echo "[WARN] the main checkout is on $head; switch it off the branch to delete it"; left=1
fi
(( dry )) || git worktree prune 2>/dev/null

if git show-ref --verify --quiet "refs/heads/$head"; then
  if (( dry )); then echo "[DRY] would delete local branch $head"
  elif git branch -D "$head" >/dev/null 2>&1; then echo "[OK] deleted local branch $head"
  else echo "[WARN] could not delete local branch $head"; left=1; fi
fi

if [[ "$cross" == true ]]; then
  echo "[INFO] head is on a fork; remote branch left to its owner"
elif ! stacked=$(gh pr list --base "$head" --state open --json number --jq '.[].number' 2>&1); then
  echo "[WARN] could not check for PRs stacked on $head ($stacked); remote branch kept"; left=1
elif [[ -n "$stacked" ]]; then
  echo "[INFO] open PRs are stacked on $head (#${stacked//$'\n'/, #}); remote branch kept until they are retargeted"
elif git ls-remote --exit-code --heads origin "$head" >/dev/null 2>&1; then
  if (( dry )); then echo "[DRY] would delete origin/$head"
  elif out=$(timeout 180 git push -q origin --delete "$head" 2>&1); then echo "[OK] deleted origin/$head"
  else echo "[WARN] could not delete origin/$head: $(grep -v '^remote:' <<<"$out" | tail -1)"; left=1; fi
else
  echo "[OK] origin/$head already gone"
fi

(( left )) && exit 3
exit 0
