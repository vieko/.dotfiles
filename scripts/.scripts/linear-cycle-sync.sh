#!/usr/bin/env bash
# linear-cycle-sync.sh -- put my started and finished GTMENG work in the
# active cycle.
#
# GTMENG has cycle auto-add off, and most of my issues are filed and done
# inside a day, so without this the team cycle charts show about 3% of my
# work (audit 2026-11-18). Rule: an issue joins the active cycle when work
# on it starts, not when it is filed; Backlog and Todo stay out.
#
# Selects GTMENG issues assigned to me, with no cycle and no sub-issues
# (saga parents would double count), that are either started or completed
# since the active cycle began. Dry run unless --apply.
#
# Usage:
#   linear-cycle-sync.sh                    # list what would move
#   linear-cycle-sync.sh --apply            # move them
#   linear-cycle-sync.sh --issue GTMENG-123 [--apply]   # one issue (pr-merge.sh)
#   linear-cycle-sync.sh --quiet ...        # print only changes and errors
#
# Needs LINEAR_API_TOKEN (the .bash_exports bridge) or LINEAR_API_KEY.
set -euo pipefail

team="GTMENG" apply=0 issue="" quiet=0
while (($#)); do
  case "$1" in
    --apply) apply=1 ;;
    --issue) issue="${2:?--issue needs a key}"; shift ;;
    --quiet) quiet=1 ;;
    -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
    *) echo "linear-cycle-sync: unknown argument $1" >&2; exit 2 ;;
  esac
  shift
done

token="${LINEAR_API_TOKEN:-${LINEAR_API_KEY:-}}"
[[ -n "$token" ]] || { echo "linear-cycle-sync: no LINEAR_API_TOKEN or LINEAR_API_KEY" >&2; exit 1; }
[[ "$token" == lin_api_* || "$token" == Bearer\ * ]] || token="Bearer $token"

gql() { # gql <query> [jq --arg pairs...] -> response JSON on stdout
  local query="$1"; shift
  jq -n --arg q "$query" "$@" '{query: $q, variables: ($ARGS.named | del(.q))}' \
    | curl -sS -X POST https://api.linear.app/graphql \
        -H "Content-Type: application/json" -H "Authorization: $token" -d @-
}
say() { ((quiet)) || echo "$@"; }

cycle=$(gql 'query($t: String!) { teams(filter: { key: { eq: $t } }) { nodes { activeCycle { id number startsAt } } } }' --arg t "$team")
cycleId=$(jq -r '.data.teams.nodes[0].activeCycle.id // empty' <<<"$cycle")
cycleNum=$(jq -r '.data.teams.nodes[0].activeCycle.number // empty' <<<"$cycle")
cycleStart=$(jq -r '.data.teams.nodes[0].activeCycle.startsAt // empty' <<<"$cycle")
[[ -n "$cycleId" ]] || { echo "linear-cycle-sync: $team has no active cycle (or the query failed): $cycle" >&2; exit 1; }

fields='identifier title state { name type } cycle { number } children { nodes { id } } assignee { isMe } team { key } completedAt'
if [[ -n "$issue" ]]; then
  resp=$(gql "query(\$id: String!) { issue(id: \$id) { $fields } }" --arg id "$issue")
  rows=$(jq -c '[.data.issue // empty]' <<<"$resp")
else
  # Two queries: a top-level `or` here silently dropped a started issue
  # (GTMENG-1342) on 2026-11-19.
  base='team: { key: { eq: $t } }, assignee: { isMe: { eq: true } }, cycle: { null: true }'
  started=$(gql "query(\$t: String!) { issues(first: 250, filter: { $base,
      state: { type: { eq: \"started\" } } }) { nodes { $fields } } }" --arg t "$team")
  finished=$(gql "query(\$t: String!, \$since: DateTimeOrDuration!) { issues(first: 250, filter: { $base,
      state: { type: { eq: \"completed\" } }, completedAt: { gte: \$since } }) { nodes { $fields } } }" \
    --arg t "$team" --arg since "$cycleStart")
  resp="$started $finished"
  rows=$(jq -cs 'if all(.[]; .data.issues.nodes != null) then map(.data.issues.nodes) | add else empty end' <<<"$resp")
fi
[[ -n "$rows" ]] || { echo "linear-cycle-sync: query failed: $resp" >&2; exit 1; }

# Same rule for both paths; --issue also checks team, assignee and window.
picked=$(jq -c --arg t "$team" --arg since "$cycleStart" '[.[] | select(
    .team.key == $t and .assignee.isMe == true and .cycle == null
    and (.children.nodes | length) == 0
    and (.state.type == "started" or (.state.type == "completed" and (.completedAt // "") >= $since)))]' <<<"$rows")
n=$(jq 'length' <<<"$picked")
if ((n == 0)); then say "[OK] nothing to add to $team cycle $cycleNum"; exit 0; fi

((apply)) || say "[DRY] $n issue(s) would join $team cycle $cycleNum (rerun with --apply):"
fail=0
while IFS=$'\t' read -r key state title; do
  if ((apply)); then
    out=$(gql 'mutation($id: String!, $c: String!) { issueUpdate(id: $id, input: { cycleId: $c }) { success } }' --arg id "$key" --arg c "$cycleId")
    if [[ "$(jq -r '.data.issueUpdate.success // false' <<<"$out")" == true ]]; then
      echo "[OK] $key -> cycle $cycleNum ($state) $title"
    else echo "[ERROR] $key: $out" >&2; fail=1; fi
  else
    say "  $key ($state) $title"
  fi
done < <(jq -r '.[] | [.identifier, .state.name, .title[0:70]] | @tsv' <<<"$picked")
exit "$fail"
