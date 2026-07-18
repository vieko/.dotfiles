#!/usr/bin/env bash
# Generate ~/.pi/agent/settings.json from a shared base + a per-host
# enabledModels fragment.
#
# Why: Pi has only two settings layers (global + per-project) and settings.json
# supports no env interpolation or includes, so per-machine differences can't be
# expressed inside the tracked file. enabledModels (the /model picker + Ctrl+P
# cycle set) must differ per machine because each host's Vercel AI Gateway key
# has different model access: Chaos (unrestricted) gets Kimi K3 + Grok 4.5;
# Phyrexia (Vercel Team key) does not.
#
# Pattern: hostname-keyed generation, mirroring hypr/scripts/host.sh. Only the
# base (settings.base.json) and per-host fragments (hosts/*.json) are tracked;
# the generated settings.json is gitignored. This also removes the recurring
# lastChangelogVersion churn, since the file Pi writes to is no longer tracked.
#
# models.json stays shared across hosts -- its modelOverrides are inert unless a
# model is actually used, so the Kimi/Grok routing entries are harmless on
# Phyrexia.
#
# Run once after stowing, and again whenever the base or a fragment changes.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

command -v jq >/dev/null 2>&1 || {
  echo "error: jq is required to generate settings.json" >&2
  exit 1
}

base="settings.base.json"
host="$(hostname -s 2>/dev/null || hostname)"
fragment="hosts/enabledModels.${host}.json"

if [[ ! -f "$fragment" ]]; then
  echo "note: no enabledModels fragment for host '${host}'; using restricted default set." >&2
  fragment="hosts/enabledModels.default.json"
fi

out="settings.json"
tmp="$(mktemp)"
jq --slurpfile models "$fragment" '.enabledModels = $models[0]' "$base" >"$tmp"
mv "$tmp" "$out"

echo "Generated ${SCRIPT_DIR}/${out} for host '${host}' from ${fragment}."
