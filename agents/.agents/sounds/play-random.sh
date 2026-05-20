#!/usr/bin/env bash
# Play a random sound from the catalog.
# Used by Claude Code Stop hook and Pi sound-on-end extension.
#
# Usage: play-random.sh [category]
#   category: ready | death | pissed | what | attack | yes  (default: all)
#
# Catalog lives next to this script as catalog.json. Each category is a list
# of { desc, file } entries; file paths are relative to this script's dir.

set -euo pipefail

dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
catalog="$dir/catalog.json"
category="${1:-}"

[[ -r "$catalog" ]] || exit 0
command -v jq >/dev/null 2>&1 || exit 0

# Pick a random file from the requested category, or from all categories.
if [[ -n "$category" ]]; then
  query=".\"$category\" // [] | .[].file"
else
  query="[.[][].file] | .[]"
fi

mapfile -t files < <(jq -r "$query" "$catalog")
[[ ${#files[@]} -gt 0 ]] || exit 0

pick="$dir/${files[RANDOM % ${#files[@]}]}"
[[ -r "$pick" ]] || exit 0

# Pick a player based on OS. Detached + silenced so the hook returns instantly.
play() {
  case "${OSTYPE:-}" in
    darwin*) command -v afplay >/dev/null && { afplay "$pick" >/dev/null 2>&1 & disown; return; } ;;
    linux*)  command -v mpg123 >/dev/null && { mpg123 -q "$pick" >/dev/null 2>&1 & disown; return; } ;;
  esac
}

play
exit 0
