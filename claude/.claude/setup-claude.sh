#!/usr/bin/env bash
# Generate claude/.claude/settings.json from a shared base + a per-host fragment.
#
# Why: Claude Code has no machine-local user settings layer
# (~/.claude/settings.local.json is the project-local file for sessions started
# in ~, not a host override), and settings.json supports no includes. Keys that
# must differ per machine (plugin marketplace paths, autoMode rules, advisor and
# per-model settings) therefore cannot live in one tracked file.
#
# Pattern: hostname-keyed generation, mirroring pi/.pi/agent/setup-pi.sh. Only
# settings.base.json and hosts/settings.<host>.json are tracked; the generated
# settings.json is gitignored. ~/.claude/settings.json stays a stow symlink to
# it (Claude Code writes through the symlink, unlike Pi).
#
# Merge: host fragment deep-merges over the base; permissions.allow/ask/deny
# are concatenated (base first, duplicates dropped) instead of replaced.
#
# Claude Code also writes to settings.json at runtime (/model, /effort,
# "always allow"). Those writes are NOT carried over: base + fragment win. The
# previous file is saved to ~/.claude/settings.prev.json and the differing
# top-level keys are printed, so promote anything worth keeping into the base
# or the fragment and rerun.
#
# Run once after stowing, and again whenever the base or a fragment changes.
#   --check   print what would change and exit without writing

set -euo pipefail

# Resolve the script's real location: stow also links it at
# ~/.claude/setup-claude.sh, and from there the output path would be the
# ~/.claude/settings.json symlink itself. (No readlink -f: macOS lacks it.)
src="${BASH_SOURCE[0]}"
while [[ -L "$src" ]]; do
  dir="$(cd -P "$(dirname "$src")" >/dev/null 2>&1 && pwd)"
  src="$(readlink "$src")"
  [[ "$src" != /* ]] && src="${dir}/${src}"
done
SCRIPT_DIR="$(cd -P "$(dirname "$src")" >/dev/null 2>&1 && pwd)"
cd "$SCRIPT_DIR" >/dev/null

command -v jq >/dev/null 2>&1 || {
  echo "error: jq is required to generate settings.json" >&2
  exit 1
}

check=0
[[ "${1:-}" == "--check" ]] && check=1

base="settings.base.json"
host="$( (hostname -s 2>/dev/null || hostname) | tr '[:upper:]' '[:lower:]')"
fragment="hosts/settings.${host}.json"
out="${SCRIPT_DIR}/settings.json"
prev="${HOME}/.claude/settings.prev.json"

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

if [[ -f "$fragment" ]]; then
  jq -s '
    def uniq: reduce .[] as $x ([]; if index([$x]) then . else . + [$x] end);
    .[0] as $b | .[1] as $h
    | ($b * $h)
    | reduce ("allow", "ask", "deny") as $k (.;
        (($b.permissions[$k] // []) + ($h.permissions[$k] // []) | uniq) as $m
        | if ($m | length) > 0 then .permissions[$k] = $m else . end)
  ' "$base" "$fragment" >"$tmp"
else
  echo "note: no fragment for host '${host}' (${fragment}); using the base only." >&2
  jq '.' "$base" >"$tmp"
fi

jq -e 'type == "object"' "$tmp" >/dev/null || {
  echo "error: generated settings are not a JSON object; nothing written." >&2
  exit 1
}

if [[ -f "$out" ]] && jq -e . "$out" >/dev/null 2>&1; then
  drift="$(jq -n -r --slurpfile live "$out" --slurpfile new "$tmp" '
    ($live[0] | keys) + ($new[0] | keys) | unique
    | map(select($live[0][.] != $new[0][.])) | join(", ")')"
  if [[ -n "$drift" ]]; then
    echo "note: top-level keys that differ from the current settings.json: ${drift}" >&2
    echo "  (base + fragment win; the current file is kept at ${prev})" >&2
  else
    echo "${out} already matches base + fragment for host '${host}'."
    exit 0
  fi
fi

if [[ "$check" == 1 ]]; then
  echo "--check: nothing written (output would be ${out})."
  exit 0
fi

if [[ -f "$out" ]]; then
  mkdir -p "$(dirname "$prev")"
  cp -p "$out" "$prev"
fi

# Write through, never rename over: ~/.claude/settings.json is a stow symlink
# to this file and must stay one.
cat "$tmp" >"$out"

echo "Generated ${out} for host '${host}'."
