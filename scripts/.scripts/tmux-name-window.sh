#!/usr/bin/env bash
# tmux-name-window.sh
#
# Assigns a unique esoteric name to a freshly-created tmux window.
# Invoked from the `window-linked` hook in tmux.conf, which fires
# for new-window, break-pane, move-window, and link-window.
#
# Behavior:
#   - Only renames windows that still have automatic-rename enabled
#     (i.e. the user did NOT pass `-n <name>` to new-window). This
#     preserves explicit names like the ones set by tmux-start.sh
#     (void / altar / invoke / coven / scry / arcana) while they
#     are live.
#   - Picks a random name from the pool that is not already in use
#     in the current session. Closed windows free their name up
#     again. If every name is somehow in use, falls back to
#     "<name>-N".
#
# Theme: occult / Phyrexian register matching the summon defaults.
# Verb inspiration drawn from forge (run, audit, define, review,
# proof, verify, watch, status) and coding-agent verbs (read, write,
# edit, search) — restated in esoteric vocabulary. The summon names
# (void / altar / invoke / coven / scry / arcana) are intentionally
# included so they become available again when their windows close.
#
# Compatibility: written for bash 3.2+ so it works under macOS's
# system bash if /opt/homebrew/bin is not on the tmux server's PATH.
# Avoids `mapfile` (bash 4+) and `declare -A` (bash 4+).

set -eu

# TARGET is anything `tmux` accepts as a window target. The hook in
# tmux.conf passes #{window_id} (the globally unique @N form), which
# is the most reliable across hook contexts.
TARGET="${1:?usage: $0 <window-target>}"

# Pool of candidate names.
NAMES=(
    # summon defaults — eligible when not currently in the session
    void altar invoke coven scry arcana
    # write / inscribe family
    sigil rune glyph scribe etch inscribe seal brand
    # read / observe family
    glean peruse behold gaze witness glimpse
    # run / invoke family
    conjure evoke channel summon kindle
    # audit / divine family
    divine augur sift weigh portent omen
    # verify / watch family
    attest oath vigil ward warden
    # places / objects of power
    crypt shrine spire chasm abyss nexus veil shroud
    relic chalice talisman effigy tome grimoire
    # entities
    oracle familiar thrall golem wraith specter phantom
    # elemental / atmospheric
    ember pyre aether umbra gloom hallow eldritch
    # acts
    ritual chant pact hex bane echo
)

# Skip if the window already has an explicit name. When the user (or
# a script like tmux-start.sh) passes `-n <name>` to new-window or
# calls `rename-window`, tmux turns automatic-rename off for that
# window. That is our signal to leave it alone.
auto_rename=$(tmux display-message -p -t "$TARGET" '#{automatic-rename}' 2>/dev/null || echo "")
if [ "$auto_rename" != "1" ] && [ "$auto_rename" != "on" ]; then
    exit 0
fi

# Derive the session name from the window target so list-windows can
# scope correctly even when TARGET is a bare @N window-id.
session=$(tmux display-message -p -t "$TARGET" '#{session_name}' 2>/dev/null || echo "")
if [ -z "$session" ]; then
    exit 0
fi

# Serialize concurrent invocations. Without this, rapid back-to-back
# window creations can each read `used` before either has written its
# rename, picking the same name. `mkdir` is atomic on every POSIX
# filesystem and needs no external tooling (unlike flock, which is
# not in macOS's default install).
LOCKDIR="${TMUX_TMPDIR:-/tmp}/tmux-name-window.lock"
tries=0
while ! mkdir "$LOCKDIR" 2>/dev/null; do
    tries=$((tries + 1))
    if [ "$tries" -gt 100 ]; then
        # Stale lock (>5s old) — force-release and retry once. A
        # crashed previous invocation should not block forever.
        rmdir "$LOCKDIR" 2>/dev/null || true
        mkdir "$LOCKDIR" 2>/dev/null || exit 0
        break
    fi
    sleep 0.05
done
trap 'rmdir "$LOCKDIR" 2>/dev/null || true' EXIT

# Re-check automatic-rename after acquiring the lock: an earlier
# concurrent invocation may have already named this window.
auto_rename=$(tmux display-message -p -t "$TARGET" '#{automatic-rename}' 2>/dev/null || echo "")
if [ "$auto_rename" != "1" ] && [ "$auto_rename" != "on" ]; then
    exit 0
fi

# Snapshot names currently in use in this session.
used=$(tmux list-windows -t "$session" -F '#W' 2>/dev/null || true)

is_taken() {
    # -F: literal match, -x: whole line, -q: quiet
    printf '%s\n' "$used" | grep -qxF -- "$1"
}

# Portable strong-random shuffle: tag each line with awk's rand(),
# sort numerically, strip the tag. BSD `sort -R` uses a deterministic
# hash unless --random-source is given, so it can repeat the same
# order across rapid invocations — avoid it.
shuffle() {
    awk 'BEGIN { srand() } { print rand() "\t" $0 }' | sort -k1,1 | cut -f2-
}

# Walk the pool in shuffled order; pick the first unused name.
shuffled=$(printf '%s\n' "${NAMES[@]}" | shuffle)
picked=""
while IFS= read -r name; do
    if ! is_taken "$name"; then
        picked="$name"
        break
    fi
done <<EOF
$shuffled
EOF

if [ -n "$picked" ]; then
    tmux rename-window -t "$TARGET" "$picked"
    exit 0
fi

# Pool exhausted in this session — append a numeric suffix.
base=$(printf '%s\n' "${NAMES[@]}" | shuffle | head -n 1)
i=2
while is_taken "${base}-${i}"; do
    i=$((i + 1))
done
tmux rename-window -t "$TARGET" "${base}-${i}"
