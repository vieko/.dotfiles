#!/usr/bin/env bash
# summon-familiar.sh -- spawn a Pi Familiar with correct gateway binding.
#
# Encodes the invariants from the 2026-08-17 summoning post-mortem:
#   1. Gateway model IDs contain a slash (anthropic/claude-sonnet-5), so pi
#      --model alone parses the prefix as a direct provider with no key on
#      this host. Always pass --provider vercel-ai-gateway explicitly.
#   2. Pane familiars get a default login shell first, then the command via
#      send-keys -- a split-window with a direct command skips env hydration.
#   3. Panes are targeted by immutable pane_id (%N), never by index --
#      kill-pane reindexes and you end up steering the wrong session.
#   4. Startup is verified: "No API key found" and friends fail loudly here,
#      not silently in a background pane.
#
# Usage:
#   summon-familiar.sh [-m alias] [-P] [-n] <brief-path> [prompt override]
#
#   -m alias   vessel: haiku|sonnet|opus|fable|luna|sol|glm (default: sonnet)
#   -P         print mode: in-band `pi -p` dispatch (nohup + log) instead of
#              an interactive tmux pane
#   -n         dry run: print what would be executed, run nothing
#
# Pane mode requires an active tmux session; the pane opens in the current
# window (windows are projects, panes are agents).

set -euo pipefail

PROVIDER="vercel-ai-gateway"
LOG_DIR="$HOME/scratch/logs"

alias_to_model() {
    case "$1" in
        haiku)  echo "anthropic/claude-haiku-4.5:low" ;;
        sonnet) echo "anthropic/claude-sonnet-5:medium" ;;
        opus)   echo "anthropic/claude-opus-5:medium" ;;
        fable)  echo "anthropic/claude-fable-5:high" ;;
        luna)   echo "openai/gpt-5.6-luna:max" ;;
        sol)    echo "openai/gpt-5.6-sol:max" ;;
        glm)    echo "zai/glm-5.2:medium" ;;
        *)      return 1 ;;
    esac
}

vessel="sonnet"
print_mode=0
dry_run=0

while getopts "m:Pn" opt; do
    case "$opt" in
        m) vessel="$OPTARG" ;;
        P) print_mode=1 ;;
        n) dry_run=1 ;;
        *) exit 2 ;;
    esac
done
shift $((OPTIND - 1))

[[ $# -ge 1 ]] || { echo "usage: summon-familiar.sh [-m alias] [-P] [-n] <brief-path> [prompt]" >&2; exit 2; }

brief="$1"; shift
brief_abs="$(cd "$(dirname "$brief")" 2>/dev/null && pwd)/$(basename "$brief")" || true
[[ -r "$brief_abs" ]] || { echo "error: brief not readable: $brief" >&2; exit 1; }

model="$(alias_to_model "$vessel")" || { echo "error: unknown vessel alias: $vessel" >&2; exit 2; }

# Warn if the resolved model is not in this host's enabled set.
host_frag="$HOME/.pi/agent/hosts/enabledModels.$(hostname | tr '[:upper:]' '[:lower:]').json"
if [[ -r "$host_frag" ]] && ! grep -q "\"$model\"" "$host_frag"; then
    echo "warn: $model not in $(basename "$host_frag") -- summoning anyway" >&2
fi

prompt="${*:-Read $brief_abs and execute it exactly.}"

if [[ $print_mode -eq 1 ]]; then
    # In-band dispatch: inherits this shell's env (must be hydrated).
    if [[ -z "${AI_GATEWAY_API_KEY:-}" ]]; then
        echo "error: AI_GATEWAY_API_KEY not in env -- run from a hydrated shell" >&2
        exit 1
    fi
    mkdir -p "$LOG_DIR"
    log="$LOG_DIR/familiar-$(date +%Y%m%d-%H%M%S)-$vessel.log"
    cmd=(pi -p --provider "$PROVIDER" --model "$model" "$prompt")
    if [[ $dry_run -eq 1 ]]; then
        echo "dry-run (print mode):"
        printf '  '; printf '%q ' "${cmd[@]}"; printf '\n  log: %s\n' "$log"
        exit 0
    fi
    nohup "${cmd[@]}" > "$log" 2>&1 &
    pid=$!
    echo "dispatched: pid $pid, vessel $vessel ($model)"
    echo "log: $log"
    sleep 15
    if ! ps -p "$pid" > /dev/null; then
        echo "error: familiar exited within 15s -- log tail:" >&2
        tail -5 "$log" >&2
        exit 1
    fi
    if grep -qE "No API key found|Error:" "$log"; then
        echo "error: familiar reported a startup error -- log tail:" >&2
        tail -5 "$log" >&2
        kill "$pid" 2>/dev/null || true
        exit 1
    fi
    echo "verified: running clean after 15s"
else
    # Pane familiar: default shell first (env hydration), command typed in.
    [[ -n "${TMUX:-}" ]] || { echo "error: pane mode requires tmux (use -P for in-band)" >&2; exit 1; }
    pi_cmd="pi --provider \"$PROVIDER\" --model \"$model\" \"$prompt\""
    if [[ $dry_run -eq 1 ]]; then
        echo "dry-run (pane mode): split-window in current window, then send-keys:"
        echo "  $pi_cmd"
        exit 0
    fi
    pane_id="$(tmux split-window -d -P -F '#{pane_id}' -c "$PWD")"
    sleep 1
    tmux send-keys -t "$pane_id" "$pi_cmd" Enter
    echo "summoned: pane $pane_id, vessel $vessel ($model)"
    sleep 15
    if tmux capture-pane -t "$pane_id" -p 2>/dev/null | grep -qE "No API key found|Error:"; then
        echo "error: familiar reported a startup error -- pane $pane_id tail:" >&2
        tmux capture-pane -t "$pane_id" -p | grep -vE '^\s*$' | tail -5 >&2
        exit 1
    fi
    echo "verified: pane $pane_id clean after 15s (steer with: tmux send-keys -t $pane_id, or pi-post once registered)"
fi
