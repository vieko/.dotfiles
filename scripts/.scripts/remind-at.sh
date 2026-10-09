#!/usr/bin/env bash
# remind-at.sh -- one-shot macOS reminder for a pi session: at a local date and
# time it sends a brief to the session over pi-post and shows a short alert
# whose Resume button opens that session.
#
# Usage:
#   remind-at.sh [--to <target>] --title <text> --ask <text> <slug> "<YYYY-MM-DD HH:MM>" <brief|->
#   remind-at.sh --list              pending and open reminders
#   remind-at.sh --resume <slug>     open the reminder's session, then close it
#   remind-at.sh --done <slug>       close an open reminder
#   remind-at.sh --cancel <slug>     remove a pending or open reminder
#
#   <slug>   lowercase id, e.g. gtmeng-3924-flip (label dev.vieko.reminder.<slug>)
#   --title  alert title, max 60 chars: what this is about
#   --ask    alert text, max 140 chars, one line: the one thing to do now
#   <brief>  full context for the session agent, sent over pi-post only; it
#            never appears in the alert. "-" reads it from stdin.
#   --to     pi-post target (address, name, or session id). Default: the
#            calling pi session (pi-post whoami). It is pinned to an address
#            at schedule time.
#
# Alert buttons: Resume opens the session and closes the reminder. Snooze 1h
# shows the alert again in an hour. Later (or no answer for 6h) leaves it open
# in --list. A live session's tmux pane gets focus; an offline session resumes
# with `pi --session <id>` in a new tmux window, where the queued brief is the
# first thing it reads.
#
# Why it looks like this:
#   - GTMENG-3924 (2026-10-08): the first hand-rolled version fired on time and
#     delivered nothing. launchd gives jobs PATH=/usr/bin:/bin:/usr/sbin:/sbin,
#     so everything here uses absolute paths, and scheduling smoke-tests pi-post
#     under an empty environment before it installs anything.
#   - Every channel's result goes to ~/scratch/logs/reminders.log.
#   - `launchctl bootout` of the job's own label kills the running process, so
#     the job removes its plist first and boots itself out as the last step.
#   - `display notification` from a launchd job is attributed to Script Editor
#     and can be dropped silently; the job uses a modal `display alert`.
#   - RunAtLoad fires a reminder missed while the Mac was off at next login;
#     --fire exits quietly when it is not due yet.
#   - 2026-10-09: the alert showed 900 chars of the brief and only an OK button,
#     so it was unclear and led nowhere. Hence the --title/--ask limits, the
#     brief going to the session only, and the Resume button.

set -euo pipefail

[[ "${OSTYPE:-}" == darwin* ]] || { echo "error: remind-at.sh needs macOS launchd" >&2; exit 2; }

SELF=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)/$(basename "${BASH_SOURCE[0]}")
STATE_DIR="$HOME/.local/state/reminders"
AGENTS_DIR="$HOME/Library/LaunchAgents"
LOG="$HOME/scratch/logs/reminders.log"
PIPOST="$HOME/.pi/agent/post/bin/pi-post"
REGISTRY="$HOME/.pi/agent/post/registry"
PI_BIN="$HOME/.pi/agent/bin/pi"
TMUX_BIN=$(command -v tmux 2>/dev/null || echo /opt/homebrew/bin/tmux)
LABEL_PREFIX="dev.vieko.reminder"
UID_DOMAIN="gui/$(id -u)"
TITLE_MAX=60 ASK_MAX=140

die() { echo "error: $*" >&2; exit 2; }
log() { printf '%s [%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S %Z')" "$1" "$2" >> "$LOG"; }
plist_of() { echo "$AGENTS_DIR/$LABEL_PREFIX.$1.plist"; }
valid_slug() { [[ "$1" =~ ^[a-z0-9][a-z0-9-]{0,62}$ ]] || die "slug must be lowercase [a-z0-9-]"; }
close_state() { rm -f "$STATE_DIR/$1".{meta,txt,sent,snooze}; }
reg_field() { /usr/bin/plutil -extract "$2" raw -o - "$REGISTRY/$1.json" 2>/dev/null; }

# Modal alert with argv passing, so no AppleScript quoting of user text.
# Prints the button name, or "gave-up".
alert() {
  /usr/bin/osascript - "$@" <<'OSA'
on run argv
  set btns to {"OK"}
  if (count of argv) > 2 then set btns to {"Later", "Snooze 1h", "Resume"}
  set r to display alert (item 1 of argv) message (item 2 of argv) buttons btns default button (last item of btns) giving up after 21600
  if gave up of r then return "gave-up"
  return button returned of r
end run
OSA
}

# Prints the tmux pane id whose process is an ancestor of the given pid.
pane_for_pid() {
  local p=$1 chain=" "
  while [[ -n "$p" && "$p" -gt 1 ]]; do chain+="$p "; p=$(ps -o ppid= -p "$p" | tr -d ' '); done
  "$TMUX_BIN" list-panes -a -F '#{pane_id} #{pane_pid}' 2>/dev/null | while read -r id ppid; do
    [[ "$chain" == *" $ppid "* ]] && { echo "$id"; break; }
  done
}

# Brings the .app that hosts the given tmux client to the front.
activate_terminal() {
  local p=$1 comm
  while [[ -n "$p" && "$p" -gt 1 ]]; do
    comm=$(ps -o comm= -p "$p")
    if [[ "$comm" == *.app/Contents/MacOS/* ]]; then /usr/bin/open -a "${comm%%.app/*}.app"; return; fi
    p=$(ps -o ppid= -p "$p" | tr -d ' ')
  done
}

# Opens the session behind a pi-post address. Exit 0 on success; otherwise
# prints the reason and a manual command.
resume_session() {
  local addr=$1 sid cwd name pid client cpid tsess pane file
  [[ -f "$REGISTRY/$addr.json" ]] || { echo "$addr is not in the pi-post registry"; return 1; }
  sid=$(reg_field "$addr" sessionId) cwd=$(reg_field "$addr" cwd)
  name=$(reg_field "$addr" name || echo "$addr") pid=$(reg_field "$addr" pid || true)
  read -r _ client cpid tsess < <("$TMUX_BIN" list-clients -F '#{client_activity} #{client_name} #{client_pid} #{session_name}' 2>/dev/null | sort -rn | head -1) || true
  if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null && [[ "$(ps -o comm= -p "$pid")" =~ (pi|node)$ ]]; then
    pane=$(pane_for_pid "$pid")
    [[ -n "$pane" && -n "$client" ]] || { echo "$name is live but not in an attached tmux pane; switch to it by hand"; return 1; }
    "$TMUX_BIN" select-window -t "$pane" && "$TMUX_BIN" select-pane -t "$pane" &&
      "$TMUX_BIN" switch-client -c "$client" -t "$pane" || { echo "tmux could not focus $pane"; return 1; }
    echo "focused live session $name in pane $pane"
  else
    [[ -n "$sid" && -d "$cwd" ]] || { echo "$addr has no session id or cwd"; return 1; }
    # Ephemeral sessions register with pi-post but never write a file.
    file=$(find "$HOME/.pi/agent/sessions" -name "*_$sid.jsonl" -print -quit 2>/dev/null)
    [[ -n "$file" ]] || { echo "$name has no session file to resume (ephemeral session?)"; return 1; }
    [[ -n "$client" ]] || { echo "no attached tmux client; run: cd $cwd && pi --session $sid"; return 1; }
    "$TMUX_BIN" new-window -t "$tsess:" -c "$cwd" -n "${name:0:24}" "$(printf '%q --session %q' "$PI_BIN" "$file")" &&
      "$TMUX_BIN" switch-client -c "$client" -t "$tsess" || { echo "tmux new-window failed; run: cd $cwd && pi --session $sid"; return 1; }
    echo "resumed offline session $name in a new tmux window"
  fi
  activate_terminal "$cpid"
}

cmd_list() {
  shopt -s nullglob
  local meta slug status found=0
  for meta in "$STATE_DIR"/*.meta; do
    found=1
    slug=$(basename "$meta" .meta)
    (
      # shellcheck disable=SC1090 # reason: written by this script with printf %q
      source "$meta"
      if [[ -f "$(plist_of "$slug")" ]]; then status=pending
      elif [[ -f "$STATE_DIR/$slug.snooze" ]] && launchctl print "$UID_DOMAIN/$LABEL_PREFIX.$slug" >/dev/null 2>&1; then
        status="snoozed to $(date -r "$(cat "$STATE_DIR/$slug.snooze")" '+%H:%M')"
      else status=open; fi
      printf '%-36s %-18s due %s  -> %s\n    %s: %s\n' "$slug" "$status" \
        "$(date -r "$DUE" '+%Y-%m-%d %H:%M %Z')" "$TARGET" "$TITLE" "$ASK"
    )
  done
  (( found )) || echo "no pending or open reminders"
}

cmd_cancel() {
  local slug=$1 meta="$STATE_DIR/$1.meta"
  [[ -f "$meta" || -f "$(plist_of "$slug")" ]] || die "no reminder named $slug"
  rm -f "$(plist_of "$slug")"
  close_state "$slug"
  launchctl bootout "$UID_DOMAIN/$LABEL_PREFIX.$slug" 2>/dev/null || true
}

cmd_resume() {
  local slug=$1 out
  [[ -f "$STATE_DIR/$slug.meta" ]] || die "no reminder named $slug"
  # shellcheck disable=SC1090 # reason: written by this script with printf %q
  source "$STATE_DIR/$slug.meta"
  if out=$(resume_session "$TARGET"); then
    log "$slug" "resume: $out"; echo "[OK] $out"
    cmd_cancel "$slug"
  else
    log "$slug" "resume failed: $out"; die "$out"
  fi
}

# Runs under launchd. Must not exit on error before the final bootout.
cmd_fire() {
  local slug=$1 label="$LABEL_PREFIX.$1" meta="$STATE_DIR/$1.meta"
  set +e
  if [[ ! -f "$meta" ]]; then log "$slug" "fired with no state; removing job"; rm -f "$(plist_of "$slug")"
    /bin/launchctl bootout "$UID_DOMAIN/$label" 2>/dev/null; exit 0; fi
  # shellcheck disable=SC1090 # reason: written by this script with printf %q
  source "$meta"
  local now late out rc msg name
  now=$(date +%s)
  if (( now < DUE )); then log "$slug" "loaded, not due until $(date -r "$DUE" '+%Y-%m-%d %H:%M %Z')"; exit 0; fi
  late=$(( now - DUE ))
  if (( late > 30 * 86400 )); then
    log "$slug" "more than 30 days late; dropping without delivery"
    rm -f "$(plist_of "$slug")"; close_state "$slug"
    /bin/launchctl bootout "$UID_DOMAIN/$label" 2>/dev/null; exit 0
  fi
  rm -f "$(plist_of "$slug")"

  if [[ ! -f "$STATE_DIR/$slug.sent" ]]; then
    local brief; brief=$(cat "$STATE_DIR/$slug.txt" 2>/dev/null)
    (( late > 120 )) && brief="[late by $(( late / 60 )) min] $brief"
    out=$(printf '%s' "$brief" | "$NODE" "$PIPOST" send --to "$TARGET" --from "reminder:$slug" 2>&1); rc=$?
    log "$slug" "pi-post send --to $TARGET rc=$rc ${out//$'\n'/ }"
    : > "$STATE_DIR/$slug.sent"
  fi

  name=$(reg_field "$TARGET" name || echo "$TARGET")
  msg=$ASK
  (( late > 120 )) && msg="$msg (late by $(( late / 60 )) min)"
  msg="$msg"$'\n\n'"Session: $name"
  while [[ -f "$meta" ]]; do
    out=$(alert "$TITLE" "$msg" buttons 2>&1); rc=$?
    log "$slug" "alert rc=$rc ${out//$'\n'/ }"
    (( rc == 0 )) || break
    case "$out" in
      gave-up|Later) log "$slug" "left open"; break ;;
      "Snooze 1h")
        local snooze_until=$(( $(date +%s) + 3600 ))
        echo "$snooze_until" > "$STATE_DIR/$slug.snooze"
        # Wall-clock poll: sleep's clock pauses while the Mac sleeps.
        while (( $(date +%s) < snooze_until )) && [[ -f "$meta" ]]; do sleep 30; done
        rm -f "$STATE_DIR/$slug.snooze" ;;
      Resume)
        if out=$(resume_session "$TARGET"); then log "$slug" "resume: $out"; close_state "$slug"
        else log "$slug" "resume failed: $out"; alert "Resume failed: $TITLE" "$out" >/dev/null 2>&1; fi
        break ;;
      *) break ;;
    esac
  done
  log "$slug" "done; booting out $label"
  /bin/launchctl bootout "$UID_DOMAIN/$label" 2>/dev/null
}

case "${1:-}" in
  --list) cmd_list; exit 0 ;;
  --cancel) valid_slug "${2:?usage: remind-at.sh --cancel <slug>}"; cmd_cancel "$2"; echo "[OK] canceled $2"; exit 0 ;;
  --done) valid_slug "${2:?usage: remind-at.sh --done <slug>}"
    [[ -f "$STATE_DIR/$2.meta" ]] || die "no reminder named $2"
    cmd_cancel "$2"; log "$2" "closed with --done"; echo "[OK] closed $2"; exit 0 ;;
  --resume) valid_slug "${2:?usage: remind-at.sh --resume <slug>}"; cmd_resume "$2"; exit 0 ;;
  --fire) valid_slug "${2:?}"; cmd_fire "$2"; exit 0 ;;
esac

to="" title="" ask=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --to) to=${2:?--to needs a value}; shift 2 ;;
    --title) title=${2:?--title needs a value}; shift 2 ;;
    --ask) ask=${2:?--ask needs a value}; shift 2 ;;
    -h|--help) sed -n '2,26p' "$0"; exit 0 ;;
    --) shift; break ;;
    -*) die "unknown flag $1" ;;
    *) break ;;
  esac
done
[[ $# -eq 3 ]] || die "usage: remind-at.sh [--to target] --title text --ask text <slug> \"YYYY-MM-DD HH:MM\" <brief|->"
slug=$1 when=$2 body=$3
valid_slug "$slug"
[[ -n "$title" && -n "$ask" ]] || die "--title and --ask are required; the brief never appears in the alert"
(( ${#title} <= TITLE_MAX )) || die "--title is ${#title} chars; max $TITLE_MAX"
(( ${#ask} <= ASK_MAX )) || die "--ask is ${#ask} chars; max $ASK_MAX. Put detail in the brief"
[[ "$title$ask" != *$'\n'* ]] || die "--title and --ask must be one line"
[[ "$body" == "-" ]] && body=$(cat)
[[ -n "$body" ]] || die "empty brief"

due_epoch=$(date -j -f "%Y-%m-%d %H:%M:%S" "$when:00" +%s 2>/dev/null) || die "bad time '$when' (want YYYY-MM-DD HH:MM, local)"
(( due_epoch > $(date +%s) )) || die "time '$when' is in the past"

# fnm's per-shell multishell path dies with the shell; the default alias does not.
node_bin="$HOME/.local/share/fnm/aliases/default/bin/node"
if [[ ! -x "$node_bin" ]]; then
  node_bin=$(command -v node) || die "node not found"
  node_bin=$(cd "$(dirname "$node_bin")" && pwd -P)/$(basename "$node_bin")
fi
[[ -x "$PIPOST" ]] || die "pi-post CLI missing at $PIPOST"

if [[ -z "$to" ]]; then
  to=$("$node_bin" "$PIPOST" whoami 2>/dev/null | grep -oE 's-[0-9a-f]{12}' | head -1) \
    || die "no --to and pi-post whoami found no session; pass --to <address>"
fi
resolved=$(env -i HOME="$HOME" PATH=/usr/bin:/bin:/usr/sbin:/sbin "$node_bin" "$PIPOST" resolve "$to" 2>&1) \
  || die "pi-post cannot resolve '$to' under launchd's environment: $resolved"
addr=$(awk '/^address:/ {print $2}' <<<"$resolved")
[[ "$addr" =~ ^s-[0-9a-f]{12}$ ]] || die "could not read an address from pi-post resolve: $resolved"

label="$LABEL_PREFIX.$slug"
plist=$(plist_of "$slug")
mkdir -p "$STATE_DIR" "$AGENTS_DIR" "$(dirname "$LOG")"
launchctl bootout "$UID_DOMAIN/$label" 2>/dev/null || true
close_state "$slug"

printf '%s' "$body" > "$STATE_DIR/$slug.txt"
{
  printf 'TITLE=%q\n' "$title"
  printf 'ASK=%q\n' "$ask"
  printf 'TARGET=%q\n' "$addr"
  printf 'DUE=%q\n' "$due_epoch"
  printf 'NODE=%q\n' "$node_bin"
} > "$STATE_DIR/$slug.meta"

cal_month=$(date -r "$due_epoch" +%-m) cal_day=$(date -r "$due_epoch" +%-d)
cal_hour=$(date -r "$due_epoch" +%-H) cal_min=$(date -r "$due_epoch" +%-M)
cat > "$plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>$label</string>
  <key>ProgramArguments</key><array><string>/bin/bash</string><string>$SELF</string><string>--fire</string><string>$slug</string></array>
  <key>StartCalendarInterval</key><dict>
    <key>Month</key><integer>$cal_month</integer><key>Day</key><integer>$cal_day</integer>
    <key>Hour</key><integer>$cal_hour</integer><key>Minute</key><integer>$cal_min</integer>
  </dict>
  <key>RunAtLoad</key><true/>
  <key>StandardOutPath</key><string>$LOG</string>
  <key>StandardErrorPath</key><string>$LOG</string>
</dict></plist>
EOF
plutil -lint "$plist" >/dev/null || die "generated plist is invalid: $plist"
launchctl bootstrap "$UID_DOMAIN" "$plist" || die "launchctl bootstrap failed for $plist"
launchctl print "$UID_DOMAIN/$label" >/dev/null 2>&1 || die "$label is not loaded after bootstrap"

echo "[OK] $slug due $(date -r "$due_epoch" '+%Y-%m-%d %H:%M %Z') -> $addr"
echo "     log $LOG; see remind-at.sh --list"
