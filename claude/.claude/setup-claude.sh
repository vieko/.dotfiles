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
# Runtime edits: Claude Code and other tools also write to settings.json
# (/model, /effort, "always allow", `rex skill setup`). Each run saves the plain
# base + fragment result to ~/.claude/settings.generated.json. The next run
# diffs the live file against it, applies those edits on top of the new base +
# fragment, and lists them so they can be promoted into a tracked file. Arrays
# merge as sets (entries added or removed at runtime stay added or removed).
# When the base or fragment also changed the same key, the tracked value wins.
# The previous file is always kept at ~/.claude/settings.prev.json.
#
# Run once after stowing, and again whenever the base or a fragment changes.
#   --check   print what would change and exit without writing
#   --reset   drop runtime edits: write base + fragment only

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
reset=0
for arg in "$@"; do
  case "$arg" in
    --check) check=1 ;;
    --reset) reset=1 ;;
    *) echo "usage: $0 [--check] [--reset]" >&2; exit 2 ;;
  esac
done

base="settings.base.json"
host="$( (hostname -s 2>/dev/null || hostname) | tr '[:upper:]' '[:lower:]')"
fragment="hosts/settings.${host}.json"
out="${SCRIPT_DIR}/settings.json"
prev="${HOME}/.claude/settings.prev.json"
lastgen="${HOME}/.claude/settings.generated.json"

tmp="$(mktemp)"
final="$(mktemp)"
trap 'rm -f "$tmp" "$final"' EXIT

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

cp "$tmp" "$final"
live_ok=0
[[ -f "$out" ]] && jq -e . "$out" >/dev/null 2>&1 && live_ok=1

# Leaf diff: objects recurse, everything else (arrays included) is a leaf.
# Edits are runtime changes from lastgen to live; apply them to the new output.
jq_lib='
  def leaves(p): if type == "object" and length > 0
    then to_entries[] as $e | $e.value | leaves(p + [$e.key])
    else [p, .] end;
  def has_path($p): any(paths; . == $p);
  def dotted: map(tostring) | join(".");
  def edits($last; $live):
    [ ($live | leaves([])) as [$p, $v]
      | ($last | has_path($p)) as $had
      | ($last | getpath($p)) as $o
      | if $had and ($o | type) == "array" and ($v | type) == "array" then
          (($v - $o) as $add | ($o - $v) as $del
           | if ($add + $del | length) > 0
             then {op: "array", path: $p, add: $add, del: $del} else empty end)
        elif $had and $o == $v then empty
        else {op: "set", path: $p, value: $v} end ]
    + [ ($last | leaves([])) as [$p, $v]
      | select(($live | has_path($p)) | not) | {op: "del", path: $p} ];
'

if [[ "$live_ok" == 1 && -f "$lastgen" && "$reset" == 0 ]] && jq -e . "$lastgen" >/dev/null 2>&1; then
  edits="$(jq -n -c --slurpfile last "$lastgen" --slurpfile live "$out" \
    "${jq_lib} edits(\$last[0]; \$live[0])")"
  if [[ "$edits" != "[]" ]]; then
    # Apply each edit unless the tracked files changed that path too.
    jq -n --slurpfile new "$tmp" --slurpfile last "$lastgen" --argjson edits "$edits" "${jq_lib}"'
      reduce $edits[] as $e ($new[0];
        if ((getpath($e.path)) != ($last[0] | getpath($e.path))) and $e.op != "array" then .
        elif $e.op == "set" then setpath($e.path; $e.value)
        elif $e.op == "del" then delpaths([$e.path])
        else (getpath($e.path) // []) as $n
          | if ($n | type) == "array"
            then setpath($e.path; ($n - $e.del) + ($e.add - $n))
            else . end
        end)' >"$final"
    echo "note: runtime edits kept on top of base + fragment (promote them, or rerun with --reset):" >&2
    jq -r --slurpfile new "$tmp" --slurpfile last "$lastgen" "${jq_lib}"'
      .[] | .path as $p | ($p | dotted) as $k
      | if .op == "array" then
          "  \($k): " + ([(.add[] | "+" + tojson), (.del[] | "-" + tojson)] | join(" "))
        elif ($new[0] | getpath($p)) != ($last[0] | getpath($p)) then
          "  \($k): skipped, base or fragment changed it too"
        elif .op == "del" then "  \($k): removed"
        else "  \($k) = \(.value | tojson)" end' <<<"$edits" >&2
  fi
elif [[ "$live_ok" == 1 && "$reset" == 0 ]]; then
  drift="$(jq -n -r --slurpfile live "$out" --slurpfile new "$tmp" '
    ($live[0] | keys) + ($new[0] | keys) | unique
    | map(select($live[0][.] != $new[0][.])) | join(", ")')"
  if [[ -n "$drift" ]]; then
    echo "note: no ${lastgen} to tell runtime edits apart; base + fragment win for: ${drift}" >&2
  fi
fi

if [[ "$live_ok" == 1 ]] && jq -n -e --slurpfile a "$out" --slurpfile b "$final" '$a[0] == $b[0]' >/dev/null; then
  if [[ "$check" == 0 ]]; then
    cp "$tmp" "$lastgen"
  fi
  echo "${out} is up to date for host '${host}'."
  exit 0
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
cat "$final" >"$out"
mkdir -p "$(dirname "$lastgen")"
cp "$tmp" "$lastgen"

echo "Generated ${out} for host '${host}'."
