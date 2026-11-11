#!/usr/bin/env bash
# Prune stale fnm multishell symlinks.
#
# Every `fnm env` creates <state>/fnm_multishells/<pid>_<ms> and fnm never
# removes it (the pid is fnm's own, short-lived, so it says nothing about
# whether the shell still lives). Unpruned, the dir reached 180k+ entries and
# cold `node --version` lookups exceeded starship's command_timeout.
#
# An entry is removed only when it is older than 7 days AND no running
# process of this user has it in FNM_MULTISHELL_PATH. Usage:
#   fnm-prune.sh            # prune now
#   fnm-prune.sh --daily    # no-op if it already ran in the last 24h

set -euo pipefail

dir="${XDG_STATE_HOME:-$HOME/.local/state}/fnm_multishells"
[[ -d "$dir" ]] || exit 0

stamp="$dir/.pruned"
if [[ "${1:-}" == "--daily" ]] && [[ -n $(find "$stamp" -mtime -1 2>/dev/null) ]]; then
    exit 0
fi
touch "$stamp"

inUse() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        ps -Eww -o command= -U "$USER" 2>/dev/null | tr ' ' '\n'
    else
        cat /proc/[0-9]*/environ 2>/dev/null | tr '\0' '\n'
    fi | sed -n 's/^FNM_MULTISHELL_PATH=//p' | sort -u
}

comm -23 \
    <(find "$dir" -maxdepth 1 -type l -name '*_*' -mtime +7 | sort) \
    <(inUse) |
    tr '\n' '\0' | xargs -0 rm -f
