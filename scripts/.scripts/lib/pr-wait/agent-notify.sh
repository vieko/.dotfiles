# One-time extraction from vercel/gtm@933f64adc319b1afe2d5eac7342f808d23c1d0b5.
# shellcheck shell=bash
# agent-notify.sh — shared --detach / --notify plumbing for the *-wait.sh scripts.
#
# Source this file (it defines functions only; nothing runs on load):
#
#   notify_resolve <enabled 0|1> <target>
#       Picks the transport up front so a bad setup fails before the wait.
#       Sets NOTIFY_TRANSPORT (claude|pipost|"") and NOTIFY_TO. With an empty
#       target the transport comes from the environment both hosts export
#       into bash tools: CLAUDE_CODE_MESSAGING_SOCKET -> Claude Code inbox
#       socket, PI_SESSION_ADDRESS (or PI_POST_REPLY_TO) -> pi-post send.
#       An explicit target is a pi-post name / s-address / directory, or a
#       Claude Code socket as uds:/path.sock (or any path ending .sock).
#       Exits 3 on a missing target or CLI.
#
#   notify_send <from-label> <headline> <body>
#       Posts one message via the resolved transport. Returns non-zero on
#       failure; callers decide whether that is fatal.
#
#   detach_reexec <log-prefix> <safe-name> <flag-to-strip> <args...>
#       Re-execs $0 in the background (nohup; setsid too where available)
#       with <flag-to-strip> removed from <args>, prints "pid + log path"
#       and returns 0. The caller exits afterwards. The host's session env is
#       inherited, so a bare --notify still resolves after re-exec.
#
# Wait records: when a detached waiter will notify a pi session, the child
# writes $TMPDIR/agent-waits/<address>/<kind>-<target>-<pid>.json ({kind,
# target, pid, log, started}) from notify_resolve and deletes it once
# notify_send succeeds. A record whose pid is gone means the waiter died or
# failed to report; the pi `waits` extension (dotfiles) shows both cases in
# the footer. Claude Code targets and --detach without --notify write none.

NOTIFY_TRANSPORT=""
NOTIFY_TO=""
_notify_pipost=""
_notify_sock_tool=""
AGENT_WAIT_RECORD=""

# Runs in the detached child (detach_reexec passes AGENT_WAIT_* to it). The
# vars are unset first so a --then command or nested waiter cannot inherit them.
_wait_record_open() {
  local kind="${AGENT_WAIT_KIND:-}" target="${AGENT_WAIT_TARGET:-}" log="${AGENT_WAIT_LOG:-}" dir safe
  unset AGENT_WAIT_KIND AGENT_WAIT_TARGET AGENT_WAIT_LOG
  if [[ -z "$kind" || "$NOTIFY_TRANSPORT" != "pipost" ]]; then return 0; fi
  dir="${TMPDIR:-/tmp}"
  dir="${dir%/}/agent-waits/$(printf '%s' "$NOTIFY_TO" | tr -c 'A-Za-z0-9._-' '_')"
  safe=$(printf '%s' "$target" | tr -c 'A-Za-z0-9._-' '_')
  mkdir -p "$dir" 2>/dev/null || return 0
  AGENT_WAIT_RECORD="$dir/$kind-$safe-$$.json"
  if ! jq -cn --arg kind "$kind" --arg target "$target" --arg log "$log" \
      --argjson pid "$$" --argjson started "$(date +%s)" \
      '{kind: $kind, target: $target, pid: $pid, log: $log, started: $started}' \
      >"$AGENT_WAIT_RECORD.tmp" 2>/dev/null \
    || ! mv "$AGENT_WAIT_RECORD.tmp" "$AGENT_WAIT_RECORD"; then
    rm -f "$AGENT_WAIT_RECORD.tmp"
    AGENT_WAIT_RECORD=""
  fi
}

notify_resolve() {
  local enabled="$1" target="${2:-}"
  NOTIFY_TRANSPORT=""; NOTIFY_TO=""
  if [[ "$enabled" != "1" ]]; then _wait_record_open; return 0; fi

  if [[ -z "$target" ]]; then
    if [[ -n "${CLAUDE_CODE_MESSAGING_SOCKET:-}" ]]; then
      NOTIFY_TRANSPORT="claude"; NOTIFY_TO="$CLAUDE_CODE_MESSAGING_SOCKET"
    elif [[ -n "${PI_SESSION_ADDRESS:-${PI_POST_REPLY_TO:-}}" ]]; then
      NOTIFY_TRANSPORT="pipost"; NOTIFY_TO="${PI_SESSION_ADDRESS:-$PI_POST_REPLY_TO}"
    else
      echo "error: --notify with no target and no CLAUDE_CODE_MESSAGING_SOCKET / PI_SESSION_ADDRESS in the environment; use --notify-to" >&2
      exit 3
    fi
  elif [[ "$target" == uds:* || "$target" == *.sock ]]; then
    NOTIFY_TRANSPORT="claude"; NOTIFY_TO="${target#uds:}"
  else
    NOTIFY_TRANSPORT="pipost"; NOTIFY_TO="$target"
  fi

  case "$NOTIFY_TRANSPORT" in
    pipost)
      if command -v pi-post >/dev/null 2>&1; then _notify_pipost="pi-post"
      elif [[ -x "$HOME/.pi/agent/post/bin/pi-post" ]]; then _notify_pipost="$HOME/.pi/agent/post/bin/pi-post"
      else echo "error: pi-post target but no pi-post CLI (PATH or ~/.pi/agent/post/bin/pi-post)" >&2; exit 3
      fi
      # Names, session IDs, and paths must use the same lock and record directory
      # as an explicit address. Resolve aliases before either is created.
      if [[ "$NOTIFY_TO" != s-* ]]; then
        local resolved address
        resolved=$("$_notify_pipost" resolve "$NOTIFY_TO") || exit 3
        address=$(awk '$1 == "address:" { print $2; exit }' <<<"$resolved")
        [[ "$address" == s-* ]] || { echo 'error: pi-post did not resolve a session address' >&2; exit 3; }
        NOTIFY_TO="$address"
      fi ;;
    claude)
      if command -v python3 >/dev/null 2>&1; then _notify_sock_tool="python3"
      elif command -v socat >/dev/null 2>&1; then _notify_sock_tool="socat"
      elif command -v nc >/dev/null 2>&1 && nc -h 2>&1 | grep -q -- '-U'; then _notify_sock_tool="nc"
      else echo "error: Claude Code socket target but none of python3 / socat / nc -U available" >&2; exit 3
      fi ;;
  esac
  _wait_record_open
}

# Post one message to a Claude Code inbox socket. Wire format is two JSON
# lines: an auth line carrying the session's exported token, then a user
# message. The auth line is what lets Claude Code verify the sender as the
# session's own child once the detached watcher has been reparented (macOS
# has no process evidence after that), so it is always sent when we have it.
_notify_claude_socket_send() {
  local sock="$1" body="$2" payload
  payload=$(jq -cn --arg t "${CLAUDE_CODE_MESSAGING_TOKEN:-}" --arg c "$body" '
    (if $t != "" then {type:"auth",token:$t} else empty end),
    {type:"user",message:{role:"user",content:$c}}')
  case "$_notify_sock_tool" in
    python3)
      printf '%s\n' "$payload" | python3 -c '
import socket, sys
s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
s.settimeout(5)
s.connect(sys.argv[1])
s.sendall(sys.stdin.buffer.read())
try:
    s.shutdown(socket.SHUT_WR)
    s.recv(4096)
except OSError:
    pass
s.close()
' "$sock" ;;
    socat) printf '%s\n' "$payload" | socat -t 2 - UNIX-CONNECT:"$sock" ;;
    nc)    printf '%s\n' "$payload" | nc -U -w 2 "$sock" ;;
  esac
}

notify_send() {
  local from="$1" headline="$2" body="$3" rc=0
  case "$NOTIFY_TRANSPORT" in
    pipost)
      printf '%s\n\n%s\n' "$headline" "$body" \
        | "$_notify_pipost" send --to "$NOTIFY_TO" --from "$from" --reply-to none || rc=$? ;;
    claude)
      _notify_claude_socket_send "$NOTIFY_TO" \
        "$(printf '[%s, background watcher, not the user] %s\n\n%s' "$from" "$headline" "$body")" || rc=$? ;;
    *) return 1 ;;
  esac
  # Only a delivered result closes the record; a failed send leaves it for the footer.
  if [[ $rc -eq 0 && -n "$AGENT_WAIT_RECORD" ]]; then rm -f "$AGENT_WAIT_RECORD"; fi
  return "$rc"
}

detach_reexec() {
  local prefix="$1" safe="$2" strip="$3" target="$2"; shift 3
  local args=() a log pid
  for a in "$@"; do [[ "$a" == "$strip" ]] || args+=("$a"); done
  safe=$(printf '%s' "$safe" | tr -c 'A-Za-z0-9._-' '_')
  log="${TMPDIR:-/tmp}/${prefix}-${safe}-$(date +%H%M%S).log"
  # setsid (Linux) detaches from the tool's process group; nohup alone
  # suffices on macOS where setsid is absent.
  # AGENT_WAIT_LOG only carries the log path into the record; nothing reads the file.
  # shellcheck disable=SC2094
  if command -v setsid >/dev/null 2>&1; then
    AGENT_WAIT_KIND="$prefix" AGENT_WAIT_TARGET="$target" AGENT_WAIT_LOG="$log" \
      setsid nohup "$0" "${args[@]}" >"$log" 2>&1 < /dev/null &
  else
    AGENT_WAIT_KIND="$prefix" AGENT_WAIT_TARGET="$target" AGENT_WAIT_LOG="$log" \
      nohup "$0" "${args[@]}" >"$log" 2>&1 < /dev/null &
  fi
  pid=$!
  echo "$prefix detached: pid $pid, log $log"
}
