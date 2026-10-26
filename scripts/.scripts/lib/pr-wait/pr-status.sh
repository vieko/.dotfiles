#!/usr/bin/env bash
# One-time extraction from vercel/gtm@933f64adc319b1afe2d5eac7342f808d23c1d0b5.
# Generic PR snapshot and renderer. No repository-specific bot or security policy.
# Usage: pr-status.sh <number|url|branch> [--repo owner/name] [--json] [--threads]
#        pr-status.sh --from-json < snapshot.json
set -euo pipefail

prArg=""; repo=""; emitJson=0; showThreads=0; fromJson=0
while (( $# )); do
  case "$1" in
    --repo) [[ $# -ge 2 ]] || exit 3; repo="$2"; shift 2 ;;
    --json) emitJson=1; shift ;;
    --threads) showThreads=1; shift ;;
    --from-json) fromJson=1; shift ;;
    *) [[ -z "$prArg" && "$1" != -* ]] || exit 3; prArg="$1"; shift ;;
  esac
done
command -v jq >/dev/null || { echo 'error: jq not found' >&2; exit 3; }
if (( fromJson )); then
  status=$(cat)
  jq -e '.number' <<<"$status" >/dev/null
else
  [[ -n "$prArg" ]] || exit 3
  repoFlag=(); [[ -z "$repo" ]] || repoFlag=(--repo "$repo")
  resolved=$(gh pr view "$prArg" ${repoFlag[@]+"${repoFlag[@]}"} --json number,url)
  number=$(jq -er '.number' <<<"$resolved")
  url=$(jq -er '.url' <<<"$resolved")
  path=${url#https://}; host=${path%%/*}; path=${path#*/}
  owner=${path%%/*}; path=${path#*/}; name=${path%%/*}
  # GraphQL variable names are literal, not shell expansions.
  # shellcheck disable=SC2016
  query='
query($owner:String!,$name:String!,$number:Int!){
  repository(owner:$owner,name:$name){ pullRequest(number:$number){
    number title url state isDraft mergedAt additions deletions
    mergeStateStatus reviewDecision headRefOid headRefName baseRefName
    baseRef { target { oid } }
    mergeCommit { oid }
    autoMergeRequest { enabledAt }
    commits(last:1){ nodes { commit { statusCheckRollup { contexts(first:100){ nodes {
      __typename
      ... on CheckRun { name status conclusion isRequired(pullRequestNumber:$number) detailsUrl }
      ... on StatusContext { context state isRequired(pullRequestNumber:$number) targetUrl }
    } } } } } }
    reviews(last:100){ nodes { author { login } state submittedAt commit { oid } } }
    reviewThreads(first:100){ nodes { isResolved isOutdated comments(first:1){ nodes {
      databaseId author { login } path line originalLine body url
    } } } }
  } }
}'
  raw=$(gh api graphql --hostname "$host" -f query="$query" -F owner="$owner" -F name="$name" -F number="$number")
  status=$(jq -e --arg host "$host" --arg repo "$owner/$name" '
    .data.repository.pullRequest | select(.number != null) as $pr
    | ($pr.commits.nodes[0].commit.statusCheckRollup.contexts.nodes // [] | map(
        if .__typename == "CheckRun" then
          {name, required: .isRequired, url: .detailsUrl,
           result: (if .status != "COMPLETED" then "pending"
                    elif .conclusion == "SKIPPED" then "skip"
                    elif (.conclusion == "SUCCESS" or .conclusion == "NEUTRAL") then "pass"
                    else "fail" end)}
        else
          {name: .context, required: .isRequired, url: .targetUrl,
           result: (if .state == "SUCCESS" then "pass"
                    elif (.state == "PENDING" or .state == "EXPECTED") then "pending"
                    else "fail" end)}
        end)) as $checks
    | ($pr.reviews.nodes // [] | map(select(.author != null and .commit.oid == $pr.headRefOid))
        | group_by(.author.login) | map(max_by(.submittedAt)
          | {author: .author.login, state, submittedAt})) as $reviews
    | ($pr.reviewThreads.nodes // []
        | map(select(.isResolved == false and .isOutdated == false))
        | map(.comments.nodes[0] | select(. != null)
          | {id: .databaseId, author: (.author.login // "ghost"), path,
             line: (.line // .originalLine), url, body: (.body | gsub("\\r?\\n"; " ") | .[0:110])})) as $threads
    | {number: $pr.number, title: $pr.title, url: $pr.url, host: $host, repo: $repo,
       state: $pr.state, isDraft: $pr.isDraft, mergedAt: $pr.mergedAt,
       mergeCommit: $pr.mergeCommit.oid, autoMerge: ($pr.autoMergeRequest != null),
       additions: $pr.additions, deletions: $pr.deletions,
       head: $pr.headRefOid, headRef: $pr.headRefName, baseRef: $pr.baseRefName,
       base: $pr.baseRef.target.oid,
       mergeStateStatus: $pr.mergeStateStatus,
       reviewDecision: (if $pr.reviewDecision == "" then null else $pr.reviewDecision end),
       checks: {
         total: ($checks | length),
         pass: ($checks | map(select(.result == "pass")) | length),
         fail: ($checks | map(select(.result == "fail")) | length),
         pending: ($checks | map(select(.result == "pending")) | length),
         skip: ($checks | map(select(.result == "skip")) | length),
         required: ($checks | map(select(.required)) | length),
         failing: ($checks | map(select(.result == "fail")) | map({name, required, url})),
         pendingNames: ($checks | map(select(.result == "pending")) | map(.name)),
         summary: (if ($checks | length) == 0 then "none"
                   elif ($checks | any(.result == "fail")) then "fail"
                   elif ($checks | any(.result == "pending")) then "pending" else "pass" end)},
       reviews: {head: $reviews}, threads: {unresolved: ($threads | length), items: $threads}}
  ' <<<"$raw")
fi
if (( emitJson )); then printf '%s\n' "$status"; exit 0; fi
jq -r --argjson threads "$showThreads" '
  "#\(.number) \(.title)", .url,
  "state: \(.state)\(if .isDraft then " (draft)" else "" end)  +\(.additions) -\(.deletions)  \(.headRef) -> \(.baseRef) @ \(.head[0:9])",
  "merge: \(.mergeStateStatus)  review: \(.reviewDecision // "NONE")",
  "checks: \(.checks.summary) (\(.checks.pass) pass, \(.checks.fail) fail, \(.checks.pending) pending, \(.checks.skip) skip)",
  (.checks.failing[] | "  fail: \(.name)\(if .required then " [required]" else "" end)  \(.url // "")"),
  (if (.checks.pendingNames | length) > 0 then "  pending: \(.checks.pendingNames | join(", "))" else empty end),
  (.baseOverlapEvents[]? | "base overlap: \(.baseRef) moved to \(.newBase[0:9]) and touches files in this PR: \(.paths | join(", "))"),
  "threads: \(.threads.unresolved) unresolved",
  (if $threads == 1 or .threads.unresolved <= 5 then
    (.threads.items[] | "  \(.path):\(.line // "?") [\(.author)] comment-id \(.id)\n    \(.body)")
   else "  (pass --threads to list all)" end)
' <<<"$status"
