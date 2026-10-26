#!/usr/bin/env bash
# pr-wait.sh: wait for a GitHub PR, then print and optionally send its status.
# One-time extraction from vercel/gtm@933f64adc319b1afe2d5eac7342f808d23c1d0b5.
# No gtm dependency, review-bot pool, or security acknowledgment policy.
#
# Usage: pr-wait.sh <number|url|branch> [--repo owner/name] [options]
#   --for checks,review,mergeable,merged   All listed conditions must hold.
#                                       Default: checks only.
#   --interval 30 --timeout 1800 --grace 180   Durations in seconds.
#   --detach                            Run in the background; print PID/log.
#   --notify [--notify-to target]        Message Pi or Claude Code on resolve.
#   --then command                      Run bash -c after the final report.
#
# checks: wait for all pending checks. Required failures gate; when none is
# required, every failure gates. Optional failures appear in the report.
# No checks waits for --grace; every new head restarts the grace period.
# review: GitHub reviewDecision must be APPROVED; CHANGES_REQUESTED fails.
# mergeable: mergeStateStatus must be CLEAN. merged: wait for MERGED.
# MERGED/CLOSED resolves early; CLOSED fails only when waiting for merged.
# --notify chooses CLAUDE_CODE_MESSAGING_SOCKET, then PI_SESSION_ADDRESS or
# PI_POST_REPLY_TO. Explicit targets accept pi-post addresses/names/paths or
# uds:/socket. A failed delivery leaves the wait record for /waits to show.
# New base commits that touch PR files produce a log event and appear in the
# final status, notification, and PR_JSON.baseOverlapEvents. No extra messages
# are sent. API errors retry on later polls; no state persists across restarts.
# --then receives PR, PR_URL, PR_TITLE, PR_STATE, PR_MERGE_STATE, PR_CHECKS,
# PR_REVIEW_DECISION, PR_THREADS, PR_WAIT_RESULT, PR_STATUS, and PR_JSON.
# Exit: 0 ok; 1 failed; 2 timeout; 3 usage/dependency; 4 duplicate waiter.
# Requires: gh (authenticated), jq, Bash. Notification dependencies are optional.
set -euo pipefail

# Resolve the entrypoint symlink so stow and direct checkout execution agree.
scriptPath="${BASH_SOURCE[0]}"
while [[ -L "$scriptPath" ]]; do
  scriptDir="$(cd "$(dirname "$scriptPath")" && pwd)"
  scriptPath=$(readlink "$scriptPath")
  [[ "$scriptPath" == /* ]] || scriptPath="$scriptDir/$scriptPath"
done
here="$(cd "$(dirname "$scriptPath")" && pwd)"
statusSh="$here/lib/pr-wait/pr-status.sh"
# shellcheck source=scripts/.scripts/lib/pr-wait/agent-notify.sh
. "$here/lib/pr-wait/agent-notify.sh"
# shellcheck source=scripts/.scripts/lib/pr-wait/base-overlap.sh
. "$here/lib/pr-wait/base-overlap.sh"
usage() {
  awk 'NR > 1 && !/^#/ { exit } NR > 1 { sub(/^# ?/, ""); print }' "$scriptPath" >&2
  exit "${1:-3}"
}
needValue() { [[ $# -ge 2 && -n "$2" ]] || { echo "error: $1 needs a value" >&2; exit 3; }; }
prArg=""; repo=""; forCsv="checks"; interval=30; timeout=1800; grace=180
thenCmd=""; notify=0; notifyTo=""; detach=0
origArgs=("$@")
while (( $# )); do
  case "$1" in
    --repo) needValue "$@"; repo="$2"; shift 2 ;;
    --for) needValue "$@"; forCsv="$2"; shift 2 ;;
    --interval) needValue "$@"; interval="$2"; shift 2 ;;
    --timeout) needValue "$@"; timeout="$2"; shift 2 ;;
    --grace) needValue "$@"; grace="$2"; shift 2 ;;
    --then) needValue "$@"; thenCmd="$2"; shift 2 ;;
    --notify) notify=1; shift ;;
    --notify-to) needValue "$@"; notify=1; notifyTo="$2"; shift 2 ;;
    --detach) detach=1; shift ;;
    -h|--help) usage 0 ;;
    -*) echo "error: unknown flag $1" >&2; usage ;;
    *) [[ -z "$prArg" ]] || usage; prArg="$1"; shift ;;
  esac
done
[[ -n "$prArg" ]] || usage
for duration in "$interval" "$timeout" "$grace"; do
  [[ "$duration" =~ ^(0|[1-9][0-9]{0,7})$ ]] || { echo 'error: durations must be nonnegative decimal seconds (at most 8 digits)' >&2; exit 3; }
done
(( interval > 0 )) || { echo 'error: interval must be positive' >&2; exit 3; }
wantChecks=0; wantReview=0; wantMergeable=0; wantMerged=0
[[ "$forCsv" != ,* && "$forCsv" != *, && "$forCsv" != *,,* ]] || usage
IFS=',' read -ra conditions <<<"$forCsv"
for condition in "${conditions[@]}"; do
  case "$condition" in
    checks) wantChecks=1 ;;
    review) wantReview=1 ;;
    mergeable) wantMergeable=1 ;;
    merged) wantMerged=1 ;;
    *) echo "error: unknown condition '$condition'" >&2; usage ;;
  esac
done
for dependency in gh jq; do
  command -v "$dependency" >/dev/null || { echo "error: $dependency not found" >&2; exit 3; }
done
notify_resolve "$notify" "$notifyTo"
if (( detach )); then
  detach_reexec pr-wait "$prArg" --detach "${origArgs[@]}"
  exit 0
fi
repoFlag=(); [[ -z "$repo" ]] || repoFlag=(--repo "$repo")
start=$(date +%s); headAt=$start; headSeen=""; lastSignature=""; result=""; json=""; optionalFail=0
baseSeen=""; baseRefSeen=""; overlapEvents='[]'
errFile=$(mktemp "${TMPDIR:-/tmp}/pr-wait-err.XXXXXX")
trap 'rm -f "$errFile"' EXIT
while :; do
  now=$(date +%s); elapsed=$(( now - start ))
  if ! snapshot=$("$statusSh" "$prArg" ${repoFlag[@]+"${repoFlag[@]}"} --json 2>"$errFile"); then
    echo "[pr-wait] status fetch failed (t=${elapsed}s): $(tr -d '\n' < "$errFile" | cut -c1-200)" >&2
    if (( elapsed + interval > timeout )); then result=timeout; break; fi
    sleep "$interval"; continue
  fi
  json="$snapshot"
  fields=()
  while IFS= read -r line; do fields+=("$line"); done < <(jq -r '
    (.state // "UNKNOWN"), (.mergeStateStatus // "UNKNOWN"), (.checks.summary // "none"),
    (.checks.pending // 0), (.checks.total // 0), (.checks.required // 0),
    ([.checks.failing[]? | select(.required)] | length),
    ([.checks.failing[]? | select(.required | not)] | length),
    (.reviewDecision // "NONE"), (.head // "")' <<<"$json")
  state=${fields[0]}; mergeState=${fields[1]}; checksSummary=${fields[2]}; checksPending=${fields[3]}
  checksTotal=${fields[4]}; checksRequired=${fields[5]}; requiredFail=${fields[6]}; optionalFail=${fields[7]}
  reviewDecision=${fields[8]}; head=${fields[9]}
  if [[ "$head" != "$headSeen" ]]; then
    [[ -z "$headSeen" ]] || echo "[pr-wait] new head ${head:0:9}; grace restarted" >&2
    headSeen="$head"; headAt=$now
  fi
  sinceHead=$(( now - headAt ))
  base=$(jq -r '.base // empty' <<<"$json")
  baseRef=$(jq -r '.baseRef // empty' <<<"$json")
  if [[ "$baseRef" != "$baseRefSeen" ]]; then
    baseSeen="$base"; baseRefSeen="$baseRef"
  elif [[ -n "$base" && -n "$baseSeen" && "$base" != "$baseSeen" ]]; then
    host=$(jq -r .host <<<"$json"); fullRepo=$(jq -r .repo <<<"$json"); prNumber=$(jq -r .number <<<"$json")
    if touched=$(base_overlap "$host" "$fullRepo" "$prNumber" "$baseSeen" "$base"); then
      if [[ "$touched" != '[]' ]]; then
        event=$(jq -cn --arg ref "$baseRef" --arg old "$baseSeen" --arg new "$base" --argjson paths "$touched" \
          '{baseRef:$ref, oldBase:$old, newBase:$new, paths:$paths}')
        overlapEvents=$(jq -cn --argjson events "$overlapEvents" --argjson event "$event" '$events + [$event]')
        echo "[pr-wait] $(jq -r '"\(.baseRef) moved to \(.newBase[0:9]) and touches files in this PR: \(.paths | join(", "))"' <<<"$event")" >&2
      fi
      baseSeen="$base"
    else
      echo '[pr-wait] base comparison failed; will retry without advancing the baseline' >&2
    fi
  elif [[ -n "$base" && -z "$baseSeen" ]]; then
    baseSeen="$base"
  fi
  if (( checksRequired == 0 )); then hardFail=$(( requiredFail + optionalFail )); optionalFail=0
  else hardFail=$requiredFail; fi
  if [[ "$state" == MERGED || "$state" == CLOSED ]]; then
    result=ok
    [[ "$state" != CLOSED || $wantMerged -eq 0 ]] || result=failed
    break
  fi
  met=1; failed=0
  if (( wantChecks )); then
    if (( checksTotal == 0 && sinceHead < grace )); then met=0
    elif (( checksPending > 0 )); then met=0
    elif (( hardFail > 0 )); then failed=1; fi
  fi
  if (( wantReview )); then
    case "$reviewDecision" in
      APPROVED) ;;
      CHANGES_REQUESTED) failed=1 ;;
      *) met=0 ;;
    esac
  fi
  if (( wantMergeable )) && [[ "$mergeState" != CLEAN ]]; then met=0; fi
  if (( wantMerged )); then met=0; fi
  if (( met )); then
    result=ok; (( failed == 0 )) || result=failed; break
  fi
  if (( failed && checksPending == 0 )); then result=failed; break; fi
  signature="$state/$mergeState/$checksSummary:$checksPending:$hardFail:$optionalFail/$reviewDecision/$head"
  if [[ "$signature" != "$lastSignature" ]]; then
    echo "[pr-wait] #$(jq -r .number <<<"$json") $state merge=$mergeState checks=$checksSummary ($checksPending pending, $hardFail gating failures) review=$reviewDecision @${head:0:9} (t=${elapsed}s)" >&2
    lastSignature="$signature"
  fi
  if (( elapsed + interval > timeout )); then result=timeout; break; fi
  sleep "$interval"
done
if [[ -n "$json" ]]; then
  json=$(jq --argjson events "$overlapEvents" '. + {baseOverlapEvents:$events}' <<<"$json")
  statusText=$(printf '%s' "$json" | "$statusSh" --from-json)
else
  json='{}'; statusText='No PR snapshot available; see status-fetch errors in the log.'
fi
number=$(jq -r '.number // empty' <<<"$json")
title=$(jq -r '.title // empty' <<<"$json")
url=$(jq -r '.url // empty' <<<"$json")
state=$(jq -r '.state // "UNKNOWN"' <<<"$json")
mergeState=$(jq -r '.mergeStateStatus // "UNKNOWN"' <<<"$json")
checksSummary=$(jq -r '.checks.summary // "none"' <<<"$json")
reviewDecision=$(jq -r '.reviewDecision // "NONE"' <<<"$json")
threads=$(jq -r '.threads.unresolved // 0' <<<"$json")
optionalNote=""; (( optionalFail == 0 )) || optionalNote=", $optionalFail optional check(s) failing"
headline="pr-wait #${number:-$prArg}: $result (state $state, merge $mergeState, checks $checksSummary$optionalNote, review $reviewDecision, $threads unresolved threads)"
printf '%s\n%s\n' "$headline" "$statusText"
export PR="$number" PR_URL="$url" PR_TITLE="$title" PR_STATE="$state" PR_MERGE_STATE="$mergeState"
export PR_CHECKS="$checksSummary" PR_REVIEW_DECISION="$reviewDecision" PR_THREADS="$threads"
export PR_WAIT_RESULT="$result" PR_STATUS="$statusText" PR_JSON="$json"
if (( notify )); then
  notify_send "pr-wait:#${number:-$prArg}" "$headline" "$statusText" || echo '[pr-wait] notify failed' >&2
fi
if [[ -n "$thenCmd" ]]; then bash -c "$thenCmd" || echo "[pr-wait] --then command exited $?" >&2; fi
case "$result" in ok) exit 0 ;; failed) exit 1 ;; timeout) exit 2 ;; *) exit 1 ;; esac
