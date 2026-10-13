#!/usr/bin/env bash
# summon-golem.sh -- dispatch an Anvil golem in a named tmux window with a
# guaranteed completion ping back to the summoner via pi-post.
#
# Encodes the invariants from the 2026-08-21 golem-2055 dispatch review:
#   1. The completion ping is wired HERE, at dispatch, not trusted to the
#      spec or the summoner's memory. The spec describes the outcome; the
#      wrapper owns logistics. The agent inside an anvil run is gate-bound
#      and never does messaging.
#   2. The summoner's address is captured from this shell's env and baked
#      into the runner as a literal. tmux windows get the server's env, not
#      the dispatching pane's -- interpolation-by-luck is not a mechanism.
#   3. `anvil run --json` writes the result to a file; the ping reports the
#      parsed verdict. No `$?`-through-tee: with --json the stream goes to
#      stderr and stdout is the result, so anvil's exit status is direct.
#   4. The ping fires on EVERY exit path (green, red, crash, killed window)
#      via an EXIT trap, so silence always means "still running".
#   6. The ping body is piped over stdin. This host runs SentinelOne, which
#      SIGKILLs processes whose argv looks like shell (gate commands do);
#      see ping() below. Rule for anything in this script: no code-like
#      text on a command line.
#   5. -v --reasoning are on by default (AGENTS.md dispatch rule).
#   7. With -B, the golem shows on the sigil session map as a task: `doing`
#      at dispatch, updated from the same EXIT trap as the ping (sigil#51).
#      The map is a view, never a gate: a down sigil server only warns.
#
# The ping is a claim, not a review: every golem diff still passes the one
# review pipeline (PHYREXIA.md standing invariant).
#
# Usage:
#   summon-golem.sh [-m alias] [-e K=V]... [-n] [-R] [-k] [-B board] <name> <spec-or-prompt> [anvil args...]
#
#   -m alias   vessel: haiku|sol|sonnet|opus|fable|astra|luna|terra|glm (anvil's aliases;
#              astra needs anvil >= 0.3.1, sol the 2026-09-22 alias refresh).
#              Default: luna (PHYREXIA golem binding -- cross-family worker
#              under an Anthropic reviewer diversifies failure modes)
#   -n         dry run: print the runner script and tmux command, run nothing
#   -R         no report-back: skip the completion ping. Deliberate opt-out
#              only -- the golem then finishes silently (golem-2055 mode:
#              poll the pane or anvil status)
#   -e K=V     export an env var into the golem's process tree only (anvil,
#              its worktree install, the agent's shell, the gate). Repeatable.
#              Canonical use: `-e npm_config_min_release_age=0` when the target
#              repo's lockfile pins a package inside npm's release cooldown
#              (npm/cli#9715: with omit-lockfile-registry-resolved the
#              min-release-age-exclude list is ignored at extract time, so a
#              fresh worktree install fails with ETARGET). Scoped here, not in
#              .npmrc, so the cooldown stays on for everything else. Review the
#              lockfile diff of such a run: transitives inside the cooldown
#              can move too.
#   -B board   put the golem on the session map that sigil board binds to
#              (map-<board up to '--'>), as task golem-<name>: `doing` at
#              dispatch; `done` (detail: review pending) on a green exit,
#              still `doing` with the exit code otherwise. '@' means the
#              summoner's board, as in summon-familiar.sh. sigil#51.
#   -k         keep the window open after a green exit. Default: a green
#              golem closes its window 10s after the ping (the log + result
#              JSON on disk are the forensic artifacts; the pane adds
#              nothing). Red or crashed golems always keep the window.
#
#   <name>     construct name; window becomes golem-<name> (convention:
#              the issue number, e.g. 2055)
#   <spec>     path to a spec file (absolutized) or a literal prompt string
#   [args...]  passed to `anvil run` verbatim (--from, --verify, --scope,
#              --contract, --effort, -C, ...)
#
# Requires an active tmux session. The window opens with a login shell
# (env hydration), then runs a generated runner script; the pane stays open
# after a red exit for inspection and closes itself after a green one (-k
# to keep it).

set -euo pipefail

LOG_DIR="$HOME/scratch/logs"
PIPOST_SHIM="$HOME/.pi/agent/post/bin/pi-post"   # stable, extension-owned (pi-post v0.7.0+, issue #6)
PIPOST_CACHE="$HOME/.pi/agent/git/github.com/vieko/pi-post/bin/pi-post.mjs"  # last resort: pi's cache layout is not a contract

alias_ok() {
    case "$1" in
        haiku|sol|sonnet|opus|fable|astra|luna|terra|glm) return 0 ;;
        *) return 1 ;;
    esac
}

vessel="luna"
dry_run=0
no_report=0
keep_window=0
golem_env=()
board=""

while getopts "m:e:nRkB:" opt; do
    case "$opt" in
        m) vessel="$OPTARG" ;;
        e) [[ "$OPTARG" == *=* ]] || { echo "error: -e expects KEY=VALUE, got: $OPTARG" >&2; exit 2; }
           golem_env+=("$OPTARG") ;;
        n) dry_run=1 ;;
        R) no_report=1 ;;
        k) keep_window=1 ;;
        B) board="$OPTARG" ;;
        *) exit 2 ;;
    esac
done
shift $((OPTIND - 1))

[[ $# -ge 2 ]] || { echo "usage: summon-golem.sh [-m alias] [-e K=V]... [-n] [-R] [-k] [-B board] <name> <spec-or-prompt> [anvil args...]" >&2; exit 2; }

alias_ok "$vessel" || { echo "error: unknown vessel alias: $vessel (anvil aliases: haiku|sol|sonnet|opus|fable|astra|luna|terra|glm)" >&2; exit 2; }

# A scoped PATH must still reach the tools the runner needs. golem-gtmeng-3319
# (2026-09-22) died twice with `anvil: command not found` / `pnpm: command not
# found` because the dispatcher wrote `-e PATH=<fnm bin>:/usr/bin:/bin` and
# dropped the `:$PATH` tail. Check here, where the mistake is cheap.
for kv in "${golem_env[@]+"${golem_env[@]}"}"; do
    [[ "${kv%%=*}" == "PATH" ]] || continue
    scoped_path="${kv#*=}"
    for tool in anvil node pnpm npm; do
        PATH="$scoped_path" command -v "$tool" >/dev/null 2>&1 \
            || { echo "error: -e PATH=... does not resolve '$tool'; append :\$PATH to the value (see docs/agent-maintenance.md)" >&2; exit 2; }
    done
done

name="$1"; spec="$2"; shift 2

# Spec: absolutize if it's a readable file, else pass through as a prompt.
if [[ -r "$spec" ]]; then
    spec="$(cd "$(dirname "$spec")" && pwd)/$(basename "$spec")"
    # Kind check: warn, never refuse (the suffix is unreliable; see
    # summon-familiar.sh and PHYREXIA.md summoning discipline).
    if [[ "$spec" == *-brief.md ]]; then
        echo "warn: $spec is named as a brief -- if it needs steering, use summon-familiar.sh -W fam-$name" >&2
        echo "      if it has a gate and needs no steering, rename it to *-spec.md" >&2
    fi
fi

# -B: the session map the golem shows on (sigil#51). Same '@' resolution as
# summon-familiar.sh; the map id follows sigil's mapForRoom rule (a map-*
# board is its own map, else map-<board before -->).
map_id=""
map_task=""
map_title=""
sigil_server="${SIGIL_SERVER:-http://127.0.0.1:5858}"
if [[ -n "$board" ]]; then
    if [[ "$board" == "@" ]]; then
        pins_dir="${SIGIL_PINS_DIR:-$HOME/dev/sigil/.rooms/pins}"
        board="${SIGIL_ROOM:-}"
        if [[ -z "$board" && -n "${PI_SESSION_ADDRESS:-}" && -r "$pins_dir/$PI_SESSION_ADDRESS" ]]; then
            board="$(tr -d '[:space:]' < "$pins_dir/$PI_SESSION_ADDRESS")"
        fi
        [[ -n "$board" ]] || { echo "error: -B @: the summoner has no SIGIL_ROOM and no sigil pin -- draw on a board first or name it" >&2; exit 2; }
    fi
    [[ "$board" =~ ^[A-Za-z0-9_-]{1,64}$ ]] || { echo "error: -B: invalid board id: $board" >&2; exit 2; }
    if [[ "$board" == map-* ]]; then map_id="$(printf '%s' "$board" | tr '[:upper:]' '[:lower:]')"
    else map_id="$(printf 'map-%s' "${board%%--*}" | tr '[:upper:]' '[:lower:]' | cut -c1-64)"; fi
    map_task="$(printf 'golem-%s' "$name" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9-' '-' | cut -c1-64)"
    if [[ -r "$spec" ]]; then map_title="golem $name: $(basename "$spec" .md)"; else map_title="golem $name"; fi
    map_title="${map_title:0:80}"
fi

# Report-back address: captured here, where the summoner's env exists.
# Hard error without one -- a silent golem is the failure mode this script
# exists to prevent (symmetric with summon-familiar.sh).
report_to=""
if [[ $no_report -eq 0 ]]; then
    report_to="${PI_SESSION_ADDRESS:-${PI_SESSION_ID:-}}"
    if [[ -z "$report_to" ]]; then
        echo "error: no PI_SESSION_ADDRESS/PI_SESSION_ID in env -- cannot wire the completion ping" >&2
        echo "       run from inside a pi session's bash tool, or pass -R to deliberately summon without one" >&2
        exit 1
    fi
    # Resolve the pi-post CLI now, not in the window (whose PATH we don't own).
    if command -v pi-post >/dev/null 2>&1; then
        pipost_cmd="pi-post"
    elif [[ -x "$PIPOST_SHIM" ]]; then
        pipost_cmd="$(printf '%q' "$PIPOST_SHIM")"
    elif [[ -f "$PIPOST_CACHE" ]]; then
        pipost_cmd="node $(printf '%q' "$PIPOST_CACHE")"
    else
        echo "error: pi-post CLI not found (PATH or $PIPOST_CACHE) -- cannot wire the completion ping" >&2
        echo "       pass -R to deliberately summon without one" >&2
        exit 1
    fi
fi

[[ $dry_run -eq 1 || -n "${TMUX:-}" ]] || { echo "error: summon-golem.sh requires an active tmux session" >&2; exit 1; }

mkdir -p "$LOG_DIR"
ts="$(date +%Y%m%d-%H%M%S)"
log="$LOG_DIR/golem-$name-$ts.log"
result="$LOG_DIR/golem-$name-$ts.json"
runner="$LOG_DIR/golem-$name-$ts.runner.sh"
window="golem-$name"

# Build the anvil command with args quoted for the generated script.
anvil_cmd="anvil run $(printf '%q' "$spec") --model $(printf '%q' "$vessel") --json -v --reasoning"
for a in "$@"; do
    anvil_cmd+=" $(printf '%q' "$a")"
done

# --- generate the runner -------------------------------------------------
{
    cat <<EOF
#!/usr/bin/env bash
# generated by summon-golem.sh -- golem $name, $ts (window $window)
set -uo pipefail

RESULT=$(printf '%q' "$result")
LOG=$(printf '%q' "$log")
PINGED=0
EOF
    for kv in "${golem_env[@]+"${golem_env[@]}"}"; do
        printf 'export %s=%q   # -e: scoped to this golem\n' "${kv%%=*}" "${kv#*=}"
    done
    if [[ -n "$map_id" ]]; then
        cat <<EOF

# -B: update the golem's map task once, on any exit. A view, never a gate.
MAPPED=0
map_close() {
    [[ \$MAPPED -eq 1 ]] && return 0
    MAPPED=1
    local status="\$1" passed=""
    [[ -s "\$RESULT" ]] && passed="\$(jq -r '.passed // empty' "\$RESULT" 2>/dev/null)"
    local state=doing detail="gate red or no result (exit \$status); see \$RESULT"
    if [[ "\$status" == 0 && "\$passed" == true ]]; then state=done; detail="gate green; review pending"; fi
    jq -n --arg id $(printf '%q' "$map_task") --arg status "\$state" --arg detail "\${detail:0:160}" --arg session $(printf '%q' "golem:$name") \\
        '{ops: [{op: "upsert", id: \$id, status: \$status, detail: \$detail}], session: \$session, role: "golem", source: ["summon-golem"]}' \\
        | curl -sf -m 5 -H 'content-type: application/json' --data-binary @- $(printf '%q' "$sigil_server/maps/$map_id/patch") >/dev/null \\
        || echo "warn: could not update map task $map_task on $map_id" >&2
}
EOF
    else
        printf '\nmap_close() { :; }\n'
    fi
    if [[ $no_report -eq 0 ]]; then
        cat <<EOF

ping() {
    [[ \$PINGED -eq 1 ]] && return 0
    PINGED=1
    local status="\$1"
    local verdict="no JSON result (crashed or killed before anvil finished)"
    if [[ -s "\$RESULT" ]]; then
        verdict="\$(jq -r '"passed=\(.passed) attempts=\(.attempts) branch=\(.branch // "?") gate[\(.gate.source // "?")]=\((.gate.commands // []) | join("; "))" + (if .errors then "\nerrors: \(.errors)" else "" end)' "\$RESULT" 2>/dev/null)" \\
            || verdict="result JSON present but unparseable: \$RESULT"
    fi
    local body="golem $name (anvil) finished: exit \${status}. \${verdict}
result: \$RESULT
log: \$LOG
worktree: see anvil status (prune after merge)
Gate green is a claim, not a review -- run the review pass before integrating."
    # Body goes over stdin, never argv. SentinelOne (this host's EDR) SIGKILLs
    # processes whose command line looks like obfuscated shell; the verdict
    # carries the gate commands (grep -E, sed, xargs, \$(...)) and tripped it
    # on every golem run of 2026-09-02 (golem-3251, -3251c, -3256: "Killed: 9",
    # exit 137, no kernel or syspolicyd log). Reproduced on demand: the same
    # 2 KB body dies as --body and delivers via stdin. Retries cannot help
    # with an argv-content rule, so a single attempt with a short fallback
    # is the right shape.
    if printf '%s' "\$body" | $pipost_cmd send --to $(printf '%q' "$report_to") --from $(printf '%q' "golem:$name"); then
        return 0
    fi
    local rc=\$?
    echo "warn: completion ping failed (exit \$rc); sending a short fallback" >&2
    printf 'golem $name (anvil) finished: exit %s. Full verdict in %s (ping body was rejected; see summon-golem.sh).' "\$status" "\$RESULT" \\
        | $pipost_cmd send --to $(printf '%q' "$report_to") --from $(printf '%q' "golem:$name") \\
        || echo "warn: fallback ping to $report_to also failed -- report manually" >&2
}
EOF
    else
        printf '\nping() { :; }  # -R: report-back deliberately disabled at summon time\n'
    fi
    cat <<'EOF'
trap 'map_close "${ANVIL_STATUS:-interrupted}"; ping "${ANVIL_STATUS:-interrupted}"' EXIT
EOF
    cat <<EOF

$anvil_cmd >"\$RESULT" 2> >(tee "\$LOG" >&2)
ANVIL_STATUS=\$?
map_close "\$ANVIL_STATUS"
ping "\$ANVIL_STATUS"
echo
if [[ \$ANVIL_STATUS -eq 0 && $keep_window -eq 0 && -n "\${TMUX_PANE:-}" ]]; then
    echo "[DONE] $window green. Closing this window in 10s (Ctrl-C to keep). result: \$RESULT"
    sleep 10 && tmux kill-window -t "\$TMUX_PANE"
else
    echo "[DONE] $window finished (exit \$ANVIL_STATUS). Pane stays open; result: \$RESULT"
fi
EOF
} > "$runner"
chmod +x "$runner"
# -------------------------------------------------------------------------

# -B: open the map task now, from the summoner's side, before the window exists.
map_open() {
    jq -n --arg id "$map_task" --arg title "$map_title" --arg session "golem:$name" \
        '{ops: [{op: "upsert", id: $id, kind: "task", title: $title, status: "doing", detail: "dispatched"}], session: $session, role: "golem", source: ["summon-golem"]}' \
        | curl -sf -m 5 -H 'content-type: application/json' --data-binary @- "$sigil_server/maps/$map_id/patch" >/dev/null
}

if [[ $dry_run -eq 1 ]]; then
    [[ -n "$map_id" ]] && echo "dry-run: would open map task $map_task (\"$map_title\") on $map_id at $sigil_server"
    echo "dry-run: would open window $window (login shell, cwd $PWD), then send-keys:"
    echo "  bash $runner"
    echo "--- runner ---"
    cat "$runner"
    rm -f "$runner"
    exit 0
fi

# sigil#51 roles, set here and never guessed: the construct reads SIGIL_ROLE,
# and the summoner gets a role file under its pi-post address, which sigil
# reads on every draw and map patch. A down or missing sigil only skips it.
mark_summoner() {
    [[ "${PI_SESSION_ADDRESS:-}" =~ ^[A-Za-z0-9_-]+$ ]] || return 0
    local roles_dir="${SIGIL_ROLES_DIR:-$HOME/dev/sigil/.rooms/roles}"
    mkdir -p "$roles_dir" 2>/dev/null && printf 'summoner\n' > "$roles_dir/$PI_SESSION_ADDRESS" 2>/dev/null || true
}
mark_summoner

# Login shell first (env hydration), then the runner via send-keys --
# same discipline as summon-familiar.sh pane mode.
pane_id="$(tmux new-window -d -P -F '#{pane_id}' -n "$window" -c "$PWD")"
sleep 1
tmux send-keys -t "$pane_id" "bash $(printf '%q' "$runner")" Enter
# Summon ledger: shared with summon-familiar.sh (one grep audits all
# constructs' vessel bindings -- see the 2026-08-30 fable-drift audit).
echo "$(date +%Y-%m-%dT%H:%M:%S%z) kind=golem vessel=$vessel window=$window pane=$pane_id spec=$spec${golem_env[*]+ env=${golem_env[*]}}" >> "$LOG_DIR/summons.log"
echo "summoned: window $window (pane $pane_id), vessel $vessel"
echo "log: $log"
echo "result: $result"
[[ $no_report -eq 0 ]] && echo "ping: wired to $report_to (fires on every exit path)"
if [[ -n "$map_id" ]]; then
    if map_open; then echo "map: task $map_task doing on $map_id"; else echo "warn: could not open map task $map_task on $map_id (sigil server down?)" >&2; fi
fi

# Startup verification: fail loudly here, not silently in a pane.
sleep 15
if tmux capture-pane -t "$pane_id" -p 2>/dev/null | grep -qE "No API key found|error:|Error:|command not found"; then
    echo "error: golem reported a startup error -- pane $pane_id tail:" >&2
    tmux capture-pane -t "$pane_id" -p | grep -vE '^\s*$' | tail -6 >&2
    exit 1
fi
echo "verified: pane $pane_id clean after 15s (watch: tmux capture-pane -t $pane_id -p; presence: anvil status)"
