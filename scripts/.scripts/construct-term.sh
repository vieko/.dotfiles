#!/usr/bin/env bash
# construct-term.sh -- the terminal operations that summon-familiar.sh,
# summon-golem.sh and the /wrap and /recap construct checks need, for tmux
# and for Rex. Callers stay backend-agnostic; this file owns the commands.
#
# Usage:
#   construct-term.sh backend              print tmux or rex, exit 1 if neither
#   construct-term.sh open-window NAME DIR new background window with a login shell; prints ID
#   construct-term.sh open-split DIR       background split beside the caller; prints ID
#   construct-term.sh send ID              type stdin into ID, then press Enter
#   construct-term.sh capture ID           print ID's screen
#   construct-term.sh command ID           foreground command of ID, or "gone"
#   construct-term.sh close-self           close the window this runs in
#   construct-term.sh list                 construct windows (fam-*, golem-*):
#                                          "<backend> <name> <window id>", all sessions
#
# Backend: tmux when $TMUX is set (tmux inside Rex is still tmux), else Rex
# when $REX_SESSION is set. CONSTRUCT_TERM=tmux|rex overrides. `list` checks
# both, so it works from any shell.
#
# IDs: tmux pane ids (%12), or rex/<session id>/<block id>. Rex resolves a
# block target only inside its session, so the ID carries both.
#
# Rex notes: every pane is a login shell (secrets come from the per-server
# cache in .bash_profile), `send` uses stdin so long prompts never reach
# argv (the SentinelOne rule in summon-golem.sh), and windows open with
# focus=false like tmux new-window -d.

set -euo pipefail

REX_DEFAULT="$HOME/Library/Application Support/com.superlogical.rex/RexServer/Versions/Current/Rex Server.app/Contents/MacOS/rex"
SHELL_FLAVOR="com.superlogical.terminal.shell"
CONSTRUCT_RE='^(fam|golem)-'

die() { echo "construct-term: $*" >&2; exit 1; }

rex_bin() {
    if [[ -n "${REX_BIN_DIR:-}" && -x "$REX_BIN_DIR/rex" ]]; then echo "$REX_BIN_DIR/rex"
    elif command -v rex >/dev/null 2>&1; then command -v rex
    elif [[ -x "$REX_DEFAULT" ]]; then echo "$REX_DEFAULT"
    else return 1; fi
}

backend() {
    case "${CONSTRUCT_TERM:-}" in
        tmux|rex) echo "$CONSTRUCT_TERM"; return ;;
        "") ;;
        *) die "CONSTRUCT_TERM must be tmux or rex" ;;
    esac
    if [[ -n "${TMUX:-}" ]]; then echo tmux
    elif [[ -n "${REX_SESSION:-}" ]]; then echo rex
    else return 1; fi
}

# Splits rex/<session>/<block> into REX_S and REX_B.
parse_rex_id() {
    [[ "$1" =~ ^rex/(session:[^/]+)/(block:[^/]+)$ ]] || die "not a rex construct id: $1"
    REX_S=${BASH_REMATCH[1]} REX_B=${BASH_REMATCH[2]}
}

rex_open_window() {
    local name=$1 dir=$2 rex out block
    rex=$(rex_bin) || die "rex not found"
    out=$("$rex" "do" -s "$REX_SESSION" --args "$(jq -nc --arg name "$name" --arg cwd "$dir" '{name: $name, cwd: $cwd}')" -e '
        local w, err = rex.session.new_window{
            window_label = rex.args.name,
            focus = false,
            layout = rex.layout.block{ flavor = "'"$SHELL_FLAVOR"'", label = rex.args.name,
                                       options = { cwd = rex.args.cwd } },
        }
        if err then error(err, 0) end
        return w.block_ids[1]')
    block=$(jq -r . <<<"$out")
    [[ "$block" == block:* ]] || die "rex did not return a block: $out"
    echo "rex/$REX_SESSION/$block"
}

rex_open_split() {
    local dir=$1 rex block
    rex=$(rex_bin) || die "rex not found"
    block=$("$rex" split -s "$REX_SESSION" ${REX_BLOCK:+-b "$REX_BLOCK"} --focus=false --cwd "$dir" --json | jq -r '.block_ids[0]')
    [[ "$block" == block:* ]] || die "rex split returned no block"
    echo "rex/$REX_SESSION/$block"
}

cmd=${1:-}; shift || true
case "$cmd" in
    backend)
        backend || die "neither tmux (\$TMUX) nor Rex (\$REX_SESSION)"
        ;;
    open-window)
        [[ $# -eq 2 ]] || die "usage: open-window NAME DIR"
        case "$(backend)" in
            tmux) tmux new-window -d -P -F '#{pane_id}' -n "$1" -c "$2" ;;
            rex) rex_open_window "$1" "$2" ;;
        esac
        ;;
    open-split)
        [[ $# -eq 1 ]] || die "usage: open-split DIR"
        case "$(backend)" in
            tmux) tmux split-window -d -P -F '#{pane_id}' -c "$1" ;;
            rex) rex_open_split "$1" ;;
        esac
        ;;
    send)
        [[ $# -eq 1 ]] || die "usage: send ID (text on stdin)"
        text=$(cat)
        if [[ "$1" == rex/* ]]; then
            parse_rex_id "$1"; rex=$(rex_bin) || die "rex not found"
            printf '%s' "$text" | "$rex" send -s "$REX_S" -b "$REX_B"
            "$rex" send-key -s "$REX_S" -b "$REX_B" enter
        else
            tmux send-keys -t "$1" "$text" Enter
        fi
        ;;
    capture)
        [[ $# -eq 1 ]] || die "usage: capture ID"
        if [[ "$1" == rex/* ]]; then
            parse_rex_id "$1"; rex=$(rex_bin) || die "rex not found"
            "$rex" capture -s "$REX_S" -b "$REX_B" --trim
        else
            tmux capture-pane -t "$1" -p
        fi
        ;;
    command)
        [[ $# -eq 1 ]] || die "usage: command ID"
        if [[ "$1" == rex/* ]]; then
            parse_rex_id "$1"; rex=$(rex_bin) || { echo gone; exit 0; }
            "$rex" block call process -s "$REX_S" -b "$REX_B" 2>/dev/null \
                | jq -r '.foreground.argv0 // .foreground.name // "gone"' 2>/dev/null || echo gone
        else
            tmux display -p -t "$1" '#{pane_current_command}' 2>/dev/null || echo gone
        fi
        ;;
    close-self)
        if [[ -n "${TMUX_PANE:-}" ]]; then tmux kill-window -t "$TMUX_PANE"
        elif [[ -n "${REX_BLOCK:-}" ]]; then rex=$(rex_bin) || die "rex not found"; "$rex" block close "$REX_BLOCK"
        else die "not in a tmux pane or a Rex terminal"; fi
        ;;
    list)
        if command -v tmux >/dev/null 2>&1; then
            tmux list-windows -a -F 'tmux #W #{window_id}' 2>/dev/null | awk -v re="$CONSTRUCT_RE" '$2 ~ re' || true
        fi
        if rex=$(rex_bin) && "$rex" --autostart=false ls --json >/dev/null 2>&1; then
            "$rex" --autostart=false ls --json | jq -r '.sessions[].session_id' | while read -r s; do
                "$rex" --autostart=false window ls -s "$s" --json \
                    | jq -r --arg re "$CONSTRUCT_RE" '.windows[] | select((.label // "") | test($re)) | "rex \(.label) \(.window_id)"'
            done
        fi
        ;;
    *)
        sed -n '2,24p' "$0" | sed 's/^# \{0,1\}//' >&2
        exit 2
        ;;
esac
