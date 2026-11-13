#!/usr/bin/env bash
# pr-lowrisk-check.sh: say whether a PR qualifies for the low-risk merge lane.
# Dry run only: it prints QUALIFIES or REFUSES with reasons and the merge
# command it would run. It never merges. Spec: ~/.dotfiles/docs/lowrisk-merge-lane.md
#
# Usage: pr-lowrisk-check.sh <number|url|branch> [--repo owner/name] [--max-lines 200]
#
# Qualifies only when all hold:
#   - every changed path is docs or copy (*.md, *.mdx, *.txt, docs/, content/)
#   - no path is an instruction, skill, spec, prompt, settings, CI, migration,
#     dependency, or secret path (agents read those as behavior)
#   - additions + deletions under --max-lines
#   - the PR is open, not a draft, and every check passed
# A fresh-context review verdict is a separate requirement the script cannot
# see; the lane spec covers it.
# Exit: 0 qualifies; 1 refuses; 3 usage/dependency.
# Requires: gh (authenticated), jq.
set -euo pipefail

usage() { sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//'; exit 3; }

pr="" repo="" maxLines=200
while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo) repo="${2:?}"; shift 2 ;;
    --max-lines) maxLines="${2:?}"; shift 2 ;;
    -h|--help) usage ;;
    -*) echo "unknown option: $1" >&2; usage ;;
    *) [[ -z "$pr" ]] || usage; pr="$1"; shift ;;
  esac
done
[[ -n "$pr" ]] || usage
command -v gh >/dev/null && command -v jq >/dev/null || { echo "needs gh and jq" >&2; exit 3; }

repoArgs=()
[[ -n "$repo" ]] && repoArgs=(--repo "$repo")

json="$(gh pr view "$pr" "${repoArgs[@]}" --json number,url,state,isDraft,additions,deletions,files,statusCheckRollup)"

# Paths that look like docs but change agent or build behavior.
denyRe='(^|/)(AGENTS|CLAUDE|GEMINI|PHYREXIA|CHAOS)\.md$|(^|/)SKILL\.md$|(^|/)\.(agents|claude|pi|codex|cursor|opencode|github|bonfire)/|(^|/)(skills|prompts|specs?|contracts?|migrations?|drizzle|hooks)/|spec|settings[^/]*\.json$|(^|/)package\.json$|lock(file)?|\.lock$|(^|/)\.env|secret|vercel\.json$|turbo\.json$'
allowRe='\.(md|mdx|txt)$|(^|/)(docs|content)/'

reasons=()
state="$(jq -r .state <<<"$json")"
[[ "$state" == "OPEN" ]] || reasons+=("PR is $state")
[[ "$(jq -r .isDraft <<<"$json")" == "false" ]] || reasons+=("PR is a draft")

lines=$(( $(jq -r .additions <<<"$json") + $(jq -r .deletions <<<"$json") ))
(( lines < maxLines )) || reasons+=("$lines changed lines (limit $maxLines)")

while IFS= read -r path; do
  [[ -z "$path" ]] && continue
  if grep -Eiq "$denyRe" <<<"$path"; then
    reasons+=("behavior path: $path")
  elif ! grep -Eq "$allowRe" <<<"$path"; then
    reasons+=("not docs or copy: $path")
  fi
done < <(jq -r '.files[].path' <<<"$json")
[[ "$(jq '.files | length' <<<"$json")" -gt 0 ]] || reasons+=("no changed files")

# Checks: every one must be complete and successful (or skipped/neutral).
bad="$(jq -r '[.statusCheckRollup[]? | {n: (.name // .context), s: ((.conclusion // .state) | ascii_upcase)}
  | select(.s | IN("SUCCESS","SKIPPED","NEUTRAL") | not) | "\(.n)=\(.s)"] | join(", ")' <<<"$json")"
[[ -z "$bad" ]] || reasons+=("checks not green: $bad")
[[ "$(jq '.statusCheckRollup | length' <<<"$json")" -gt 0 ]] || reasons+=("no checks ran")

url="$(jq -r .url <<<"$json")"
if [[ ${#reasons[@]} -eq 0 ]]; then
  echo "QUALIFIES $url ($lines lines)"
  echo "would run: gh pr merge $(jq -r .number <<<"$json") ${repoArgs[*]} --auto --squash"
  echo "still needed: a SHIP verdict from a fresh-context review (see the lane spec)"
  exit 0
fi
echo "REFUSES $url"
printf '  - %s\n' "${reasons[@]}"
exit 1
