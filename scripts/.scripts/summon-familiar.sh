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
#   summon-familiar.sh [-m alias] [-P] [-n] [-R] [-w name] [-W name] <brief-path> [prompt override]
#
#   -m alias   vessel: haiku|sonnet|opus|fable|luna|sol|glm (default: sonnet)
#   -P         print mode: in-band `pi -p` dispatch (nohup + log) instead of
#              an interactive tmux pane
#   -W name    construct window: open a new tmux window named <name>
#              (convention: fam-<issue>, e.g. fam-2551) instead of a pane in
#              the current window. The window name is the in-flight signal
#              (PHYREXIA.md topology) -- kill it on merge with the worktree.
#              Usually paired with -w for file-touching dispatches.
#   -n         dry run: print what would be executed, run nothing
#   -R         no report-back: summon without injecting the report-back
#              footer. Deliberate opt-out only -- a familiar summoned this
#              way finishes silently (the fam-2649 failure mode).
#   -w name    file-touching familiar: create a git worktree at
#              <repo-parent>/<repo>-worktrees/<name> (new branch <name>) and
#              summon there. Enforces the PHYREXIA.md isolation invariant
#              (2026-08-06: sibling `reset --hard` in a shared checkout wiped
#              another session's uncommitted work). Requires running inside
#              the target repo. Fails loudly on a stale worktree or branch.
#
# Pane and window modes require an active tmux session. Default pane mode
# opens in the current window (quick same-project helpers); -W opens a named
# construct window (dispatched task work -- familiars are summoned, never
# conscripted; see PHYREXIA.md summoning discipline).

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
no_report=0
worktree_name=""
window_name=""

while getopts "m:PnRw:W:" opt; do
    case "$opt" in
        m) vessel="$OPTARG" ;;
        P) print_mode=1 ;;
        n) dry_run=1 ;;
        R) no_report=1 ;;
        w) worktree_name="$OPTARG" ;;
        W) window_name="$OPTARG" ;;
        *) exit 2 ;;
    esac
done
shift $((OPTIND - 1))

[[ $print_mode -eq 1 && -n "$window_name" ]] && { echo "error: -P and -W are mutually exclusive" >&2; exit 2; }

[[ $# -ge 1 ]] || { echo "usage: summon-familiar.sh [-m alias] [-P] [-n] [-R] [-w name] [-W name] <brief-path> [prompt]" >&2; exit 2; }

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

# Report-back injection (2026-08-20 post-mortem). Two observed failure modes:
# fam-2649's brief omitted the report-back mechanism entirely (finished
# silently; report lived only in its own transcript), and fam-2651's brief
# addressed it to a directory path (~/dev/gtm -- ambiguous, 7 registered
# sessions; first send bounced). The footer is injected HERE, not trusted to
# the brief author: concrete summoner session id, never a directory path.
# Appended to the prompt (not the brief file) so it applies to pane and
# print mode alike and never mutates the scratch artifact.
# Target preference: PI_SESSION_ADDRESS (s-... form, exported by pi-post
# v0.6.3+ at session_start -- matches what list_sessions displays and is
# prefix-ambiguity-proof), falling back to the raw PI_SESSION_ID for
# sessions started before the pin bump. Both resolve as send_message targets.
report_to="${PI_SESSION_ADDRESS:-${PI_SESSION_ID:-}}"
if [[ $no_report -eq 1 ]]; then
    : # deliberate opt-out (-R): no footer injected
elif [[ -n "$report_to" ]]; then
    prompt+=" MANDATORY REPORT-BACK: when you finish -- success, blocked, or giving up -- send your full report (summary, verification results, numbered deviations) with the send_message tool to ${report_to} (your summoner). Never target a directory path. The transcript is not the delivery; the message is. If the send fails, retry once via list_sessions, then say so loudly in your final output."
else
    # Hard error, not a warning: a warning on stderr in a tool result is
    # exactly the kind of signal that gets scrolled past, and the resulting
    # familiar finishes silently (the fam-2649 failure mode this footer
    # exists to prevent).
    echo "error: no PI_SESSION_ADDRESS/PI_SESSION_ID in env -- cannot inject a report-back address" >&2
    echo "       run from inside a pi session's bash tool, or pass -R to deliberately summon without report-back" >&2
    exit 1
fi

# -w: isolate a file-touching familiar in its own worktree.
work_dir="$PWD"
if [[ -n "$worktree_name" ]]; then
    repo_root="$(git rev-parse --show-toplevel 2>/dev/null)" \
        || { echo "error: -w requires running inside the target git repo" >&2; exit 1; }
    wt_dir="$(dirname "$repo_root")/$(basename "$repo_root")-worktrees/$worktree_name"
    # Branch from origin's default branch, never the checkout's HEAD: the main
    # checkout is often parked on another session's branch, and a worktree
    # branched from it inherits stray commits (the fam-2902-pr2 / fam-2967
    # contamination incidents, 2026-08-24/25). Falls back to HEAD only when
    # there is no origin (local-only repos).
    wt_base="HEAD"
    if git -C "$repo_root" remote get-url origin >/dev/null 2>&1; then
        git -C "$repo_root" fetch origin >/dev/null 2>&1 || true
        default_branch="$(git -C "$repo_root" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null || echo origin/main)"
        git -C "$repo_root" rev-parse --verify -q "$default_branch" >/dev/null && wt_base="$default_branch"
    fi
    if [[ $dry_run -eq 1 ]]; then
        echo "dry-run (worktree): git -C $repo_root worktree add $wt_dir -b $worktree_name $wt_base"
    else
        if [[ -e "$wt_dir" ]]; then
            echo "error: worktree dir exists: $wt_dir" >&2
            echo "       stale summon? review it, then: git -C $repo_root worktree remove $wt_dir" >&2
            exit 1
        fi
        git -C "$repo_root" worktree add "$wt_dir" -b "$worktree_name" "$wt_base" >/dev/null 2>&1 \
            || { echo "error: git worktree add failed (branch '$worktree_name' already exists?)" >&2; exit 1; }
        echo "worktree: $wt_dir (branch $worktree_name, base $wt_base)"
    fi
    work_dir="$wt_dir"
fi

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
    cd "$work_dir"
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
    # Pane/window familiar: default shell first (env hydration), command typed in.
    [[ -n "${TMUX:-}" ]] || { echo "error: pane/window mode requires tmux (use -P for in-band)" >&2; exit 1; }
    pi_cmd="pi --provider \"$PROVIDER\" --model \"$model\" \"$prompt\""
    if [[ $dry_run -eq 1 ]]; then
        if [[ -n "$window_name" ]]; then
            echo "dry-run (window mode): new-window -n $window_name, then send-keys:"
        else
            echo "dry-run (pane mode): split-window in current window, then send-keys:"
        fi
        echo "  $pi_cmd"
        exit 0
    fi
    if [[ -n "$window_name" ]]; then
        pane_id="$(tmux new-window -d -P -F '#{pane_id}' -n "$window_name" -c "$work_dir")"
    else
        pane_id="$(tmux split-window -d -P -F '#{pane_id}' -c "$work_dir")"
    fi
    sleep 1
    tmux send-keys -t "$pane_id" "$pi_cmd" Enter
    if [[ -n "$window_name" ]]; then
        echo "summoned: window $window_name (pane $pane_id), vessel $vessel ($model)"
    else
        echo "summoned: pane $pane_id, vessel $vessel ($model)"
    fi
    sleep 15
    if tmux capture-pane -t "$pane_id" -p 2>/dev/null | grep -qE "No API key found|Error:"; then
        echo "error: familiar reported a startup error -- pane $pane_id tail:" >&2
        tmux capture-pane -t "$pane_id" -p | grep -vE '^\s*$' | tail -5 >&2
        exit 1
    fi
    echo "verified: pane $pane_id clean after 15s (steer with: tmux send-keys -t $pane_id, or pi-post once registered)"
fi
