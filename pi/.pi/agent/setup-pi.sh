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

# `>/dev/null` suppresses the directory echo `cd` emits when CDPATH is set,
# which would otherwise corrupt SCRIPT_DIR (double path). See macOS default shells.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
cd "$SCRIPT_DIR" >/dev/null

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

# Write directly to the live file. ~/.pi/agent/settings.json is a real file
# (not a stow symlink): Pi's atomic writes replace symlinks, so a repo-dir
# copy silently stops propagating. Machine-local keys Pi manages
# (lastChangelogVersion) are preserved from the existing live file.
out="${HOME}/.pi/agent/settings.json"
tmp="$(mktemp)"
jq --slurpfile models "$fragment" '.enabledModels = $models[0]' "$base" >"$tmp"

# Optional per-host package overrides (hosts/packages.<host>.json): local dev
# checkouts loaded as pi packages, e.g. "../../dev/sigil" (relative to
# ~/.pi/agent, so portable across OSes but only valid where the clone exists).
# A local path replaces the shared pin with the same package name in place
# (git:github.com/vieko/bonfire@v7.5.1, npm:@vieko/pi-redact@0.1.2 and
# ../../dev/bonfire all name "bonfire" / "pi-redact"), so the working copy runs
# on that host and the pin still holds everywhere else. Loading both would
# fail: pi-prose and pi-redact register the same flags and commands twice.
# Paths without a matching pin are appended.
extras="hosts/packages.${host}.json"
if [[ -f "$extras" ]]; then
  tmp2="$(mktemp)"
  jq --slurpfile extra "$extras" '
    def pkgname:
      if startswith("git:") then ltrimstr("git:") | split("@")[0] | split("/") | last
      elif startswith("npm:") then ltrimstr("npm:") | capture("^(@[^/]+/)?(?<n>[^@]+)").n
      else rtrimstr("/") | split("/") | last end;
    ($extra[0]) as $x
    | (.packages // []) as $b
    | .packages = (
        ($b | map(. as $p | (($x | map(select(pkgname == ($p | pkgname))) | first) // $p)))
        + ($x | map(select(. as $e | ($b | map(pkgname) | index($e | pkgname)) | not)))
        | reduce .[] as $p ([]; if index($p) then . else . + [$p] end))' "$tmp" >"$tmp2"
  mv "$tmp2" "$tmp"
fi

if [[ -f "$out" ]]; then
  # Warn if `pi update` bumped package pins in the live file but the tracked
  # base is stale -- base wins, so stale base pins would downgrade packages.
  livePkgs="$(jq -c '.packages // []' "$out")"
  basePkgs="$(jq -c '.packages // []' "$tmp")"
  if [[ "$livePkgs" != "$basePkgs" ]]; then
    echo "warning: live package pins differ from settings.base.json (base wins)." >&2
    echo "  live: ${livePkgs}" >&2
    echo "  base: ${basePkgs}" >&2
    echo "  If live is newer (pi update), sync settings.base.json and rerun." >&2
  fi
  # Warn if model/thinking defaults drifted -- typically a Ctrl+S save from
  # /model or /thinking that wrote into the live file. Base wins, so the
  # save silently reverts unless promoted into settings.base.json first.
  for key in defaultModel defaultThinkingLevel modelThinkingLevels; do
    liveVal="$(jq -c --arg k "$key" '.[$k]' "$out")"
    baseVal="$(jq -c --arg k "$key" '.[$k]' "$base")"
    if [[ "$liveVal" != "$baseVal" ]]; then
      echo "warning: live ${key} differs from settings.base.json (base wins)." >&2
      echo "  live: ${liveVal}" >&2
      echo "  base: ${baseVal}" >&2
      echo "  If the live value is a Ctrl+S save you want to keep, add it to settings.base.json and rerun." >&2
    fi
  done
  tmp2="$(mktemp)"
  jq --slurpfile live "$out" \
    'if $live[0].lastChangelogVersion then .lastChangelogVersion = $live[0].lastChangelogVersion else . end' \
    "$tmp" >"$tmp2"
  mv "$tmp2" "$tmp"
fi

mv "$tmp" "$out"
chmod 600 "$out"

echo "Generated ${out} for host '${host}' from ${fragment}."

# Self-heal the vercel-plugin skills `current` symlink that per-project
# .pi/settings.json files point at (a plugin update dangles it, silently
# shrinking the Pi skill set in those repos).
# Login shells also repair this (bash/.bash_profile); doing it here too covers
# fresh-machine bootstrap. See docs/agent-maintenance.md.
vercelPluginDir="${HOME}/.claude/plugins/cache/claude-plugins-official/vercel"
if [[ -d "$vercelPluginDir" && ! -e "$vercelPluginDir/current" ]]; then
  newestVersion="$(ls -d "$vercelPluginDir"/[0-9]* 2>/dev/null | sort -V | tail -1)"
  if [[ -n "$newestVersion" ]]; then
    ln -sfn "${newestVersion##*/}" "$vercelPluginDir/current"
    echo "Re-pointed vercel-plugin skills symlink: current -> ${newestVersion##*/}"
  fi
fi
