#!/usr/bin/env bash
# Recreate the dev-repo skill symlinks for THIS machine.
#
# These skills live in machine-local clones under ~/dev, so their symlink target
# can't be a single committed absolute path (macOS /Users/... vs Linux /home/...).
# They are gitignored (see skills/.gitignore) and regenerated here per machine.
#
# Run after stowing `agents/` AND cloning the dev repos into ~/dev.

set -e

# CDPATH= guards against a set CDPATH making `cd` echo the path into the capture.
SKILLS_DIR="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/skills" && pwd)"

# link <symlink-name> <path-relative-to-$HOME>
link() {
    local name="$1" target="$HOME/$2"
    if [[ ! -e "$target" ]]; then
        echo "  ⚠ skip $name — $target not found (clone the dev repo first)"
        return
    fi
    ln -sfn "$target" "$SKILLS_DIR/$name"
    echo "  ✓ $name → $target"
}

echo "Linking dev-repo skills in $SKILLS_DIR:"
link bonfire "dev/bonfire/skills/bonfire"
link anvil   "dev/anvil/packages/cli/skills/anvil"
