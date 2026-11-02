#!/usr/bin/env bash
# pi-typecheck.sh: check our pi extensions, pi packages and anvil against a
# pi release, and diff the gateway model catalog against the previous one.
# Used by the /pi-update prompt after `pi update`.
#
# Usage: pi-typecheck.sh [version]      (default: `pi --version`)
#
# Typecheck: each target compiles with its own tsconfig, but the pi modules
# (@earendil-works/*, typebox, @types/node) resolve to the release under
# ~/.pi/agent/install/releases/<version>, not to the repo's pinned copy. A
# package's `pi.extensions` entries are added, so extensions its tsconfig
# leaves out (sigil's integrations/pi) are checked too. Temp configs live in
# a mktemp dir; no repo file is written.
#
# Targets: ~/.dotfiles/pi/.pi/agent/extensions/*.ts, then each repo in
# PI_TYPECHECK_REPOS (space-separated; default: the ~/dev checkouts of
# bonfire/pi pi-prose pi-post pi-counsel pi-redact sigil anvil that exist).
#
# Catalog: vercel-ai-gateway model ids added or removed since the previous
# release on disk, and every gateway id we name (models.json overrides,
# hosts/enabledModels*.json, summon-familiar.sh, anvil's aliases) that is
# missing from the new catalog. Also prints the pi version each repo pins.
#
# Exit: 0 when every typecheck passes and no named id is missing, 1 otherwise.

set -uo pipefail

releases="${HOME}/.pi/agent/install/releases"
version="${1:-$(pi --version 2>/dev/null)}"
nm="${releases}/${version}/node_modules"
[[ -d "$nm/@earendil-works/pi-coding-agent" ]] || { echo "error: no pi release at $nm" >&2; exit 2; }
command -v jq >/dev/null || { echo "error: jq is required" >&2; exit 2; }

dev="${HOME}/dev"
agentDir="${HOME}/.dotfiles/pi/.pi/agent"
repos=()
if [[ -n "${PI_TYPECHECK_REPOS:-}" ]]; then
  read -r -a repos <<<"$PI_TYPECHECK_REPOS"
else
  for r in bonfire/pi pi-prose pi-post pi-counsel pi-redact sigil anvil; do
    [[ -f "$dev/$r/tsconfig.json" ]] && repos+=("$dev/$r")
  done
fi

tsc="${TSC:-}"
if [[ -z "$tsc" ]]; then
  for c in "$(command -v tsc 2>/dev/null)" "$dev"/{anvil,pi-counsel,pi-post,pi-redact,sigil}/node_modules/.bin/tsc; do
    [[ -n "$c" && -x "$c" ]] && { tsc="$c"; break; }
  done
fi
[[ -n "$tsc" ]] || { echo "error: no tsc found; set TSC=/path/to/tsc" >&2; exit 2; }

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
fail=0

piPaths="$(jq -n --arg nm "$nm" '{
  "@earendil-works/*": ["\($nm)/@earendil-works/*"],
  "typebox": ["\($nm)/typebox"],
  "typebox/*": ["\($nm)/typebox/*"]
}')"

# run <label> <config>: typecheck one config, print ok or the first errors.
run() {
  local out
  if out="$("$tsc" -p "$2" 2>&1)"; then
    echo "ok    $1"
  else
    fail=1
    echo "FAIL  $1 ($(grep -c 'error TS' <<<"$out") errors)"
    grep 'error TS' <<<"$out" | head -8 | sed 's/^/      /'
  fi
}

echo "pi ${version} types: ${nm}"
echo "tsc: ${tsc} ($("$tsc" -v))"
echo

# Dotfiles extensions: no tsconfig of their own.
jq -n --arg nm "$nm" --argjson paths "$piPaths" --args '{
  compilerOptions: {
    target: "ES2022", module: "NodeNext", moduleResolution: "NodeNext",
    strict: true, noEmit: true, skipLibCheck: true,
    typeRoots: ["\($nm)/@types"], types: ["node"], paths: $paths
  },
  files: $ARGS.positional
}' "$agentDir"/extensions/*.ts >"$work/dotfiles.json"
run "dotfiles extensions" "$work/dotfiles.json"

for repo in "${repos[@]}"; do
  name="${repo#"$dev"/}"
  cfg="$work/$(tr '/' '-' <<<"$name").json"
  # A repo's own relative `paths` (anvil's @anvil/core) would be replaced, not
  # merged, by ours; carry them over as absolute paths. Extra files come from
  # package.json `pi.extensions`, ignored when the package has none.
  ownPaths="$(jq --arg r "$repo" '(.compilerOptions.paths // {})
    | map_values(map(if startswith("/") then . else "\($r)/\(ltrimstr("./"))" end))' \
    "$repo/tsconfig.json" 2>/dev/null || echo '{}')"
  files="$(jq --arg r "$repo" '[.pi.extensions // [] | .[] | select(endswith(".ts")) | "\($r)/\(ltrimstr("./"))"]' \
    "$repo/package.json" 2>/dev/null || echo '[]')"
  # `types` entries resolve from the config's directory, which is now the
  # temp dir: point typeRoots at the repo's @types and the release's, and
  # turn subpath entries (sigil's vite/client) into absolute paths.
  types="$(jq --arg r "$repo" '.compilerOptions.types // null
    | if . == null then null else map(if test("/") then "\($r)/node_modules/\(.)" else . end) end' \
    "$repo/tsconfig.json" 2>/dev/null || echo null)"
  jq -n --arg base "$repo/tsconfig.json" --arg r "$repo" --arg nm "$nm" --argjson paths "$piPaths" \
    --argjson own "$ownPaths" --argjson files "$files" --argjson types "$types" '{
      extends: $base,
      compilerOptions: ({
        noEmit: true, skipLibCheck: true, paths: ($own + $paths),
        typeRoots: ["\($r)/node_modules/@types", "\($nm)/@types"]
      } + (if $types == null then {} else { types: $types } end))
    } + (if ($files | length) > 0 then { files: $files } else {} end)' >"$cfg" ||
    { fail=1; echo "FAIL  $name (could not build its temp tsconfig)"; continue; }
  run "$name" "$cfg"
done

echo
echo "pi SDK each repo has installed (its own node_modules, else its parent's):"
for repo in "${repos[@]}"; do
  v="-"
  for d in "$repo" "$(dirname "$repo")"; do
    f="$d/node_modules/@earendil-works/pi-coding-agent/package.json"
    [[ -f "$f" ]] && { v="$(jq -r .version "$f")"; break; }
  done
  echo "  ${repo#"$dev"/}: ${v}"
done

# Catalog diff against the previous release on disk.
catalog() { jq -r '[.. | objects | .id? // empty] | unique[]' \
  "$1/@earendil-works/pi-ai/dist/providers/data/vercel-ai-gateway.json" 2>/dev/null; }
catalog "$nm" >"$work/new.txt"
prev="$(ls -t "$releases" | grep -vx "$version" | head -1)"
echo
if [[ -n "$prev" ]] && catalog "$releases/$prev/node_modules" >"$work/old.txt" && [[ -s "$work/old.txt" ]]; then
  echo "Gateway catalog ${prev} -> ${version}:"
  comm -13 "$work/old.txt" "$work/new.txt" | sed 's/^/  + /'
  comm -23 "$work/old.txt" "$work/new.txt" | sed 's/^/  - /'
else
  echo "Gateway catalog: no previous release on disk to diff against."
fi

# Every gateway id we name, with where it is named.
{
  jq -r '.providers["vercel-ai-gateway"].modelOverrides // {} | keys[] | "\(.)\tmodels.json"' "$agentDir/models.json"
  for f in "$agentDir"/hosts/enabledModels.*.json; do
    jq -r --arg f "${f##*/}" '.[] | sub(":[a-z]+$"; "") | "\(.)\t\($f)"' "$f"
  done
  grep -oE '"(anthropic|openai|google|moonshotai|spacexai|zai|xai|deepseek|mistral|alibaba)/[^":]+' \
    "${HOME}/.dotfiles/scripts/.scripts/summon-familiar.sh" | tr -d '"' | sed 's/$/\tsummon-familiar.sh/'
  [[ -f "$dev/anvil/packages/core/src/node/model-resolver.ts" ]] &&
    grep -oE 'vercel-ai-gateway:[^"]+' "$dev/anvil/packages/core/src/node/model-resolver.ts" |
    sed 's/^vercel-ai-gateway://; s/$/\tanvil aliases/'
} | sort -u >"$work/named.txt"

# Custom `models` entries are not in the catalog by design; skip them.
jq -r '.providers["vercel-ai-gateway"].models // [] | .[].id' "$agentDir/models.json" >"$work/custom.txt"
missing="$(awk -F'\t' 'NR==FNR { have[$1]=1; next } !($1 in have)' <(cat "$work/new.txt" "$work/custom.txt") "$work/named.txt")"
echo
if [[ -n "$missing" ]]; then
  fail=1
  echo "Named gateway ids missing from the ${version} catalog:"
  sed 's/\t/  (/; s/$/)/; s/^/  /' <<<"$missing"
else
  echo "Every named gateway id is in the ${version} catalog."
fi

exit "$fail"
