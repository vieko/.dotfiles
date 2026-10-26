# shellcheck shell=bash
# Compare base movement with PR paths. Only stdout carries the JSON result.
# A failed or truncated read keeps the caller's old baseline for a later retry.
base_overlap() {
  local host="$1" repo="$2" number="$3" oldBase="$4" newBase="$5"
  local prPages comparePages movedFiles prFiles commitPages sha commitFiles
  prPages=$(gh api --hostname "$host" --paginate --slurp "repos/$repo/pulls/$number/files?per_page=100") || return 1
  prFiles=$(jq -ce '[.[][] | .filename, .previous_filename // empty] | unique' <<<"$prPages") || return 1
  comparePages=$(gh api --hostname "$host" --paginate --slurp "repos/$repo/compare/$oldBase...$newBase?per_page=100") || return 1
  # The compare API limits its combined file list to 300. For large changes,
  # read each commit instead; commit file pagination supports up to 3000 files.
  if jq -e 'any(.[]; (.files | length) >= 300)' <<<"$comparePages" >/dev/null; then
    movedFiles='[]'
    while IFS= read -r sha; do
      [[ -n "$sha" ]] || continue
      commitPages=$(gh api --hostname "$host" --paginate --slurp "repos/$repo/commits/$sha?per_page=100") || return 1
      if jq -e '[.[].files[]?] | length >= 3000' <<<"$commitPages" >/dev/null; then
        echo '[pr-wait] base comparison exceeds the commit file limit; cannot establish overlap' >&2
        return 1
      fi
      commitFiles=$(jq -ce '[.[].files[]? | .filename, .previous_filename // empty]' <<<"$commitPages") || return 1
      movedFiles=$(jq -cn --argjson prior "$movedFiles" --argjson added "$commitFiles" '$prior + $added | unique') || return 1
    done < <(jq -r '.[].commits[]?.sha' <<<"$comparePages")
  else
    movedFiles=$(jq -ce '[.[].files[]? | .filename, .previous_filename // empty] | unique' <<<"$comparePages") || return 1
  fi
  jq -cn --argjson pr "$prFiles" --argjson moved "$movedFiles" '$pr - ($pr - $moved) | sort'
}
