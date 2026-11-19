# shellcheck shell=bash
# Vercel Security Review findings for a PR head branch, read-only.
#
# The "Vercel Security Review" check on a vercel/* PR reflects findings that
# GitHub cannot show: they live in Vercel and are read with
# `vc security vulnerabilities` (Vercel CLI 65.17+). Findings are per branch,
# not per head: a fixed finding stays open until the next scan, so each one
# carries whether it was found in the current head commit.
#
# vercelSecurityJson <owner/name> <head branch> <head sha>
#   Prints one JSON object and always returns 0:
#     {"available": true, "scope": ..., "findings": [{id, number, severity,
#      title, foundIn, onHead}]}   open findings, most severe first
#     {"available": false, "reason": "..."}   lookup skipped or failed
#   Only vercel/* repositories are looked up. The team comes from
#   PR_WAIT_VERCEL_SCOPE, else the map below. A missing or old CLI, an
#   expired login or a timeout degrades to available=false; it never fails
#   the caller. Never dismisses or reopens anything: that is the user's call.
vercelSecurityScope() {
  if [[ -n "${PR_WAIT_VERCEL_SCOPE:-}" ]]; then printf '%s' "$PR_WAIT_VERCEL_SCOPE"; return; fi
  case "$1" in
    vercel/gtm) printf 'vercel-internal-apps' ;;
    *) return 1 ;;
  esac
}

_vercelSecurityUnavailable() { jq -nc --arg r "$1" '{available: false, reason: $r}'; }

vercelSecurityJson() {
  local repo="$1" branch="$2" head="$3" scope raw
  [[ "$repo" == vercel/* ]] || { _vercelSecurityUnavailable "not a vercel repository"; return 0; }
  scope=$(vercelSecurityScope "$repo") || { _vercelSecurityUnavailable "no Vercel team for $repo (set PR_WAIT_VERCEL_SCOPE)"; return 0; }
  command -v vc >/dev/null || { _vercelSecurityUnavailable "vc not installed"; return 0; }
  local timeoutCmd=()
  command -v timeout >/dev/null && timeoutCmd=(timeout 30)
  command -v gtimeout >/dev/null && timeoutCmd=(gtimeout 30)
  if ! raw=$(${timeoutCmd[@]+"${timeoutCmd[@]}"} vc security vulnerabilities list \
      --scope "$scope" --repository "$repo" --git-branch "$branch" \
      --status open --limit 100 --json 2>/dev/null); then
    _vercelSecurityUnavailable "vc lookup failed (CLI older than 65.17, not logged in, or timed out)"
    return 0
  fi
  jq -c --arg scope "$scope" --arg head "$head" '
    def rank: {critical: 0, high: 1, medium: 2, low: 3}[.] // 4;
    {available: true, scope: $scope,
     findings: ([.vulnerabilities[]? | {
       id: .findingId, number, severity, title,
       foundIn: (.foundIn.commitSha // null),
       onHead: ((.foundIn.commitSha // "") == $head)}]
       | sort_by(.severity | rank))}
  ' <<<"$raw" 2>/dev/null || _vercelSecurityUnavailable "unexpected vc output"
}
