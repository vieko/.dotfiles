#!/usr/bin/env bash
# pi-halted.sh -- find the pi sessions a restart stopped, and resume them.
#
# Usage:
#   pi-halted.sh                 list sessions that were running at the last
#                                shutdown (default)
#   pi-halted.sh --tsv           the same, tab-separated, for scripts
#   pi-halted.sh --resume <addr|all> [...]
#                                resume them: each opens in a Rex session (or
#                                a tmux window), as reminders do
#   pi-halted.sh --alert         one alert listing them, with a choice of
#                                which to resume; once per boot (login job)
#   pi-halted.sh --install       install the login job (LaunchAgent)
#   pi-halted.sh --uninstall     remove it
#
# How it decides: pi-post keeps a record per session with a heartbeat
# (`lastSeen`, every 30 s) and the process id. On a clean restart macOS
# sends SIGTERM; pi-post's shutdown hook then strips the pid and stamps
# lastSeen, so the sessions running at the time were last seen within a
# minute or two of the shutdown time in `last reboot` (tested 2026-11-15:
# SIGTERM and SIGHUP both strip the pid). After a crash there is no
# shutdown line and no hook: those records keep their pid, and the ones
# seen within 20 minutes of the newest heartbeat count. Records more than
# 24 hours older than the boot never count.
#
# Before a resume, each session gets a queued pi-post note saying it was
# stopped by a restart and asking for a two-line status before it does
# anything, so a resumed session reports where it stood instead of waiting
# for "where were we?".
#
# Why it exists: week 46 had three restarts and 12 sessions that opened with
# "locate the session that was handling X" ($39). The resume itself reuses
# `remind-at.sh --open`, so window placement and launchd PATH handling live
# in one place.

set -uo pipefail

REGISTRY="${PI_HALTED_REGISTRY:-$HOME/.pi/agent/post/registry}"
SESSIONS="$HOME/.pi/agent/sessions"
PIPOST="$HOME/.pi/agent/post/bin/pi-post"
REMIND="$HOME/.scripts/remind-at.sh"
STATE_DIR="$HOME/.local/state/pi-halted"
LOG="$HOME/scratch/logs/pi-halted.log"
LABEL="dev.vieko.pi-halted"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
WINDOW_MIN=${PI_HALTED_WINDOW_MIN:-20}
MAX_AGE_H=${PI_HALTED_MAX_AGE_H:-24}

# fnm's per-shell multishell path dies with the shell; the default alias does not.
NODE=${NODE:-$HOME/.local/share/fnm/aliases/default/bin/node}
[[ -x "$NODE" ]] || NODE=$(command -v node) || { echo "error: node not found" >&2; exit 2; }
export NODE

die() { echo "error: $*" >&2; exit 2; }
log() { mkdir -p "$(dirname "$LOG")"; printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S %Z')" "$*" >> "$LOG"; }

boot_epoch() {
  if [[ "${OSTYPE:-}" == darwin* ]]; then /usr/sbin/sysctl -n kern.boottime | sed -E 's/^\{ sec = ([0-9]+).*/\1/'
  else awk '/^btime/ {print $2}' /proc/stat; fi
}

# Epoch of the last clean shutdown before this boot, or empty after a crash.
# macOS `last reboot` lists "shutdown time  Thu Nov 12 06:52" (minute, no year).
shutdown_epoch() {
  [[ "${OSTYPE:-}" == darwin* ]] || return 0
  local line ep boot
  line=$(last reboot 2>/dev/null | awk '/^shutdown time/ {print $3, $4, $5, $6; exit}')
  [[ -n "$line" ]] || return 0
  ep=$(date -j -f "%a %b %d %H:%M %Y" "$line $(date +%Y)" +%s 2>/dev/null) || return 0
  (( ep > $(date +%s) )) && ep=$(date -j -f "%a %b %d %H:%M %Y" "$line $(( $(date +%Y) - 1 ))" +%s)
  boot=$(boot_epoch)
  # Only a shutdown that belongs to this boot (just before it) counts.
  (( ep <= boot + 60 && boot - ep < 1800 )) && echo "$ep"
}

# TSV: address, name, cwd, state, ctxK, last seen (local), last prompt.
list_tsv() {
  "$NODE" - "$REGISTRY" "$SESSIONS" "$(boot_epoch)" "$WINDOW_MIN" "$MAX_AGE_H" "$(shutdown_epoch)" <<'JS'
const fs = require("node:fs"), path = require("node:path");
const [registry, sessions, bootS, windowMin, maxAgeH, shutdownS] = process.argv.slice(2);
const boot = Number(bootS) * 1000;
let recs = [];
for (const f of fs.readdirSync(registry)) {
  if (!f.endsWith(".json")) continue;
  try { recs.push(JSON.parse(fs.readFileSync(path.join(registry, f), "utf8"))); } catch {}
}
recs = recs.filter((r) => r.sessionId && r.lastSeen < boot && r.lastSeen >= boot - Number(maxAgeH) * 3600e3);
if (shutdownS) {
  // Clean restart: macOS sends SIGTERM, pi-post's shutdown hook strips the
  // pid and stamps lastSeen, so every running session was last seen within
  // a minute or two of the shutdown time (minute resolution).
  const sd = Number(shutdownS) * 1000;
  recs = recs.filter((r) => r.lastSeen >= sd - 3 * 60e3 && r.lastSeen <= sd + 2 * 60e3);
} else {
  // Crash or power loss: no shutdown hook ran, so the pid stayed. Take the
  // heartbeats in the minutes before the newest one.
  recs = recs.filter((r) => r.pid !== undefined);
  if (!recs.length) process.exit(0);
  const crash = Math.max(...recs.map((r) => r.lastSeen));
  recs = recs.filter((r) => r.lastSeen >= crash - Number(windowMin) * 60e3);
}
if (!recs.length) process.exit(0);
recs.sort((a, b) => b.lastSeen - a.lastSeen);
const files = {};
for (const d of fs.readdirSync(sessions)) {
  let fl; try { fl = fs.readdirSync(path.join(sessions, d)); } catch { continue; }
  for (const f of fl) { const id = f.match(/_([0-9a-f-]+)\.jsonl$/)?.[1]; if (id) files[id] = path.join(sessions, d, f); }
}
const tail = (file) => {
  const size = fs.statSync(file).size, len = Math.min(size, 2 * 1024 * 1024), b = Buffer.alloc(len), fd = fs.openSync(file, "r");
  fs.readSync(fd, b, 0, len, size - len); fs.closeSync(fd);
  return b.toString("utf8").split("\n").map((l) => { try { return JSON.parse(l); } catch { return null; } }).filter(Boolean);
};
const text = (m) => typeof m.content === "string" ? m.content : (m.content || []).filter((c) => c.type === "text").map((c) => c.text).join(" ");
const clean = (s) => s.replace(/\s+/g, " ").replace(/\t/g, " ").trim();
for (const r of recs) {
  const file = files[r.sessionId];
  if (!file) continue; // ephemeral or print-mode session: nothing to resume
  const L = tail(file);
  const msgs = L.filter((e) => e.type === "message");
  const last = msgs.at(-1)?.message;
  const working = last && !(last.role === "assistant" && last.stopReason !== "toolUse");
  const ctx = [...msgs].reverse().find((e) => e.message.role === "assistant" && e.message.usage)?.message.usage;
  const ctxK = ctx ? Math.round((ctx.input + ctx.cacheRead + ctx.cacheWrite) / 1000) : 0;
  const prompt = [...msgs].reverse().map((e) => e.message).find((m) => m.role === "user" && !/^Message from/.test(text(m)));
  const seen = new Date(r.lastSeen).toLocaleString("sv-SE").slice(5, 16);
  console.log([r.address, r.name ?? r.address, r.cwd ?? "", working ? "working" : "idle", ctxK, seen, clean(prompt ? text(prompt) : "").slice(0, 90)].join("\t"));
}
JS
}

cmd_list() {
  local rows; rows=$(list_tsv)
  if [[ -z "$rows" ]]; then echo "No sessions were running at the last shutdown (boot $(date -r "$(boot_epoch)" '+%Y-%m-%d %H:%M'))."; return 0; fi
  echo "Running at the last shutdown (boot $(date -r "$(boot_epoch)" '+%Y-%m-%d %H:%M')):"
  while IFS=$'\t' read -r addr name cwd state ctx seen prompt; do
    printf '  %s  %-28s %-7s %4sK  %s  %s\n       last prompt: %s\n' "$addr" "${name:0:28}" "$state" "$ctx" "$seen" "${cwd/#$HOME/~}" "$prompt"
  done <<<"$rows"
  echo "Resume: pi-halted.sh --resume all   (or one or more addresses)"
}

note_for() {
  printf 'This session was stopped by a Mac restart (last heartbeat %s). On resume, before doing anything else, tell the user in two lines where the work stood and what was in flight (commands, waiters, constructs), then wait for direction.' "$1"
}

resume_one() {
  local addr=$1 name=$2 seen=$3 label out
  printf '%s' "$(note_for "$seen")" | "$NODE" "$PIPOST" send --to "$addr" --from "pi-halted" >/dev/null 2>&1 || true
  label=$(printf '%s' "$name" | tr -c 'A-Za-z0-9-' '-' | tr 'A-Z' 'a-z' | sed -E 's/^-+//; s/-+$//' | cut -c1-40)
  [[ "$label" =~ ^[a-z0-9] ]] || label="halted-${addr#s-}"
  if out=$(/bin/bash "$REMIND" --open "$addr" "$label" 2>&1); then log "resume $addr: $out"; echo "[OK] $name: ${out#\[OK\] }"
  else log "resume $addr failed: $out"; echo "[ERROR] $name: $out"; return 1; fi
}

cmd_resume() {
  [[ $# -gt 0 ]] || die "usage: pi-halted.sh --resume <addr|all> [...]"
  local rows want=" $* " rc=0 n=0
  rows=$(list_tsv)
  [[ -n "$rows" ]] || { echo "No halted sessions."; return 0; }
  while IFS=$'\t' read -r addr name cwd state ctx seen prompt; do
    [[ "$want" == *" all "* || "$want" == *" $addr "* ]] || continue
    n=$((n + 1)); resume_one "$addr" "$name" "$seen" || rc=1
  done <<<"$rows"
  (( n > 0 )) || die "no halted session matches: $*"
  return $rc
}

# Multi-select picker; prints the chosen lines, or nothing for Later. A
# function, not inline: bash 3.2 (launchd's /bin/bash) cannot parse a
# heredoc inside $( ).
pick_sessions() {
  /usr/bin/osascript - "$1" "$2" <<'OSA'
on run argv
  set n to item 1 of argv
  set AppleScript's text item delimiters to linefeed
  set itemsList to text items of (item 2 of argv)
  set r to choose from list itemsList with title "pi: " & n & " sessions stopped by the restart" with prompt "Pick the sessions to resume. Each opens in a new Rex session, rereads its whole context (about $1 per 100K), and starts with a two-line status." OK button name "Resume" cancel button name "Later" with multiple selections allowed
  if r is false then return ""
  return r as text
end run
OSA
}

# Runs at login. Waits for the desktop and Rex to settle, alerts once per boot.
cmd_alert() {
  local boot rows n items picked addr name seen
  boot=$(boot_epoch)
  mkdir -p "$STATE_DIR"
  [[ -f "$STATE_DIR/alerted-$boot" ]] && exit 0
  sleep "${PI_HALTED_DELAY:-90}"
  rows=$(list_tsv)
  : > "$STATE_DIR/alerted-$boot"
  find "$STATE_DIR" -name 'alerted-*' ! -name "alerted-$boot" -delete 2>/dev/null
  [[ -n "$rows" ]] || { log "boot $boot: nothing halted"; exit 0; }
  n=$(wc -l <<<"$rows" | tr -d ' ')
  log "boot $boot: $n halted"
  # One line per session for the picker: "name — state, ctxK — prompt".
  items=$(awk -F'\t' '{ printf "%s | %s, %sK | %s\n", $2, $4, $5, substr($7, 1, 50) }' <<<"$rows")
  picked=$(pick_sessions "$n" "$items") || picked=""
  [[ -n "$picked" ]] || { log "boot $boot: user chose Later"; exit 0; }
  while IFS=$'\t' read -r addr name _ _ _ seen _; do
    [[ "$picked" == *"$name | "* ]] || continue
    resume_one "$addr" "$name" "$seen" >/dev/null 2>&1 || true
  done <<<"$rows"
}

cmd_install() {
  [[ "${OSTYPE:-}" == darwin* ]] || die "--install needs macOS launchd"
  local self; self=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)/$(basename "${BASH_SOURCE[0]}")
  mkdir -p "$(dirname "$PLIST")"
  cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key><array><string>/bin/bash</string><string>$self</string><string>--alert</string></array>
  <key>EnvironmentVariables</key><dict><key>NODE</key><string>$NODE</string></dict>
  <key>RunAtLoad</key><true/>
  <key>StandardOutPath</key><string>$HOME/scratch/logs/pi-halted.launchd.log</string>
  <key>StandardErrorPath</key><string>$HOME/scratch/logs/pi-halted.launchd.log</string>
</dict></plist>
EOF
  # Mark this boot done first, so installing does not raise an alert now.
  mkdir -p "$STATE_DIR"; : > "$STATE_DIR/alerted-$(boot_epoch)"
  launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
  launchctl bootstrap "gui/$(id -u)" "$PLIST" || die "launchctl bootstrap failed"
  echo "[OK] installed $PLIST (runs at login)"
}

cmd_uninstall() {
  launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
  rm -f "$PLIST"; echo "[OK] removed $LABEL"
}

case "${1:-}" in
  ""|--list) cmd_list ;;
  --tsv) list_tsv ;;
  --resume) shift; cmd_resume "$@" ;;
  --alert) cmd_alert ;;
  --install) cmd_install ;;
  --uninstall) cmd_uninstall ;;
  -h|--help) sed -n '2,32p' "$0" ;;
  *) die "unknown argument $1 (see --help)" ;;
esac
