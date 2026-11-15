#!/usr/bin/env bash
# pr-merge.sh -- squash-merge a green PR and close the loop: confirm the
# merge, report the linked Linear issue's state, remove the worktree, delete
# the branch locally and on origin. The merge sequence from the global
# AGENTS.md ("PR announcements"), as one command.
#
# Usage:
#   pr-merge.sh <pr> [--allow-unstable] [--keep-branch] [--no-linear]
#
#   Run it inside the repo (main checkout or any worktree of it).
#   --allow-unstable  merge when GitHub reports UNSTABLE (required checks
#                     pass, a non-required one failed). Default: refuse.
#   --keep-branch     merge only; leave worktree and branches alone.
#   --no-linear       skip the Linear state check.
#
# It never bypasses anything: no --admin, no force. A PR that is not CLEAN
# (BLOCKED, BEHIND, DIRTY, a pending check) exits 1 with the reason; wait
# with pr-wait first. A PR that is already merged skips to the cleanup, so a
# rerun after a partial cleanup is safe.
#
# Linear: the GitHub integration moves a linked issue to Done about 3 s after
# the merge (measured 2026-11-15 on 7 PRs). The script waits up to 30 s and
# reports the state; it does not change it. Agents that set Done in the same
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

pr="" allow_unstable=0 keep_branch=0 linear=1
while [[ $# -gt 0 ]]; do
  case "$1" in
    --allow-unstable) allow_unstable=1 ;;
    --keep-branch) keep_branch=1 ;;
    --no-linear) linear=0 ;;
    -h|--help) sed -n '2,34p' "$0"; exit 0 ;;
    -*) die "unknown flag $1" ;;
    *) [[ -z "$pr" ]] || die "one PR at a time"; pr=${1#\#} ;;
  esac
  shift
done
[[ "$pr" =~ ^[0-9]+$ ]] || die "usage: pr-merge.sh <pr number> [--allow-unstable] [--keep-branch] [--no-linear]"
command -v gh >/dev/null || die "gh not found"
git rev-parse --git-dir >/dev/null 2>&1 || die "run it inside the repo"

info=$(gh pr view "$pr" --json state,mergeStateStatus,headRefName,baseRefName,isCrossRepository,url,mergeCommit 2>&1) ||
  { echo "[ERROR] gh pr view $pr: $info"; exit 1; }
field() { jq -r "$1" <<<"$info"; }
state=$(field .state) mss=$(field .mergeStateStatus) head=$(field .headRefName) cross=$(field .isCrossRepository)

if [[ "$state" == MERGED ]]; then
  echo "[INFO] #$pr is already merged; cleanup only"
elif [[ "$state" != OPEN ]]; then
  echo "[ERROR] #$pr is $state"; exit 1
else
  case "$mss" in
    CLEAN|HAS_HOOKS) ;;
    UNSTABLE) (( allow_unstable )) || { echo "[ERROR] #$pr is UNSTABLE: a non-required check failed. Rerun with --allow-unstable if that is expected."; exit 1; } ;;
    *) echo "[ERROR] #$pr is not mergeable: $mss (BLOCKED = checks or review pending, BEHIND = update the branch, DIRTY = conflicts)"; exit 1 ;;
  esac
  out=$(gh pr merge "$pr" --squash 2>&1) || { echo "[ERROR] gh pr merge: $out"; exit 1; }
  for _ in {1..15}; do
    info=$(gh pr view "$pr" --json state,mergeStateStatus,headRefName,baseRefName,isCrossRepository,url,mergeCommit 2>/dev/null) || continue
    [[ "$(field .state)" == MERGED ]] && break
    sleep 2
  done
  [[ "$(field .state)" == MERGED ]] || { echo "[ERROR] #$pr did not reach MERGED within 30 s (state $(field .state))"; exit 1; }
fi
sha=$(field '.mergeCommit.oid // ""' | cut -c1-10)
echo "[OK] #$pr merged ${sha:+as $sha}"

# Linear: the issue key comes from the branch (vieko/gtmeng-4761 -> GTMENG-4761).
if (( linear )) && key=$(grep -oiE '[a-z]{2,10}-[0-9]+' <<<"$head" | head -1) && [[ -n "$key" ]] && command -v linear >/dev/null; then
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
fi

(( keep_branch )) && exit 0

left=0
# Worktree of the head branch, if any.
wt=$(git worktree list --porcelain | awk -v b="refs/heads/$head" '/^worktree /{p=substr($0,10)} $0=="branch "b{print p}')
main_wt=$(git worktree list --porcelain | awk '/^worktree /{print substr($0,10); exit}')
if [[ -n "$wt" && "$wt" != "$main_wt" ]]; then
  if lsof -d cwd 2>/dev/null | grep -qF "$wt"; then echo "[WARN] worktree $wt: a process has its cwd there; left it"; left=1
  elif [[ -n "$(git -C "$wt" status --porcelain 2>/dev/null)" ]]; then echo "[WARN] worktree $wt has uncommitted changes; left it"; left=1
  elif git worktree remove "$wt" 2>/dev/null || git worktree remove --force "$wt" 2>/dev/null; then echo "[OK] removed worktree $wt"
  else echo "[WARN] could not remove worktree $wt"; left=1; fi
elif [[ "$wt" == "$main_wt" && -n "$wt" ]]; then
  echo "[WARN] the main checkout is on $head; switch it off the branch to delete it"; left=1
fi
git worktree prune 2>/dev/null

if git show-ref --verify --quiet "refs/heads/$head"; then
  if git branch -D "$head" >/dev/null 2>&1; then echo "[OK] deleted local branch $head"
  else echo "[WARN] could not delete local branch $head"; left=1; fi
fi

if [[ "$cross" == true ]]; then
  echo "[INFO] head is on a fork; remote branch left to its owner"
elif [[ -n "$(gh pr list --base "$head" --state open --json number --jq '.[].number' 2>/dev/null)" ]]; then
  echo "[INFO] open PRs are stacked on $head; remote branch kept until they are retargeted"
elif git ls-remote --exit-code --heads origin "$head" >/dev/null 2>&1; then
  if out=$(timeout 180 git push -q origin --delete "$head" 2>&1); then echo "[OK] deleted origin/$head"
  else echo "[WARN] could not delete origin/$head: $(grep -v '^remote:' <<<"$out" | tail -1)"; left=1; fi
else
  echo "[OK] origin/$head already gone"
fi

(( left )) && exit 3
exit 0
