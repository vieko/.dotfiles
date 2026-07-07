#!/bin/bash
# Apply Ptyxis settings (run once after `stow ptyxis`):
# palette on the default profile + GNOME-wide monospace font.
set -euo pipefail
uuid=$(gsettings get org.gnome.Ptyxis default-profile-uuid | tr -d "'")
dconf write "/org/gnome/Ptyxis/Profiles/${uuid}/palette" "'one-dark'"
gsettings set org.gnome.desktop.interface monospace-font-name 'Berkeley Mono 11'
echo "✓ Ptyxis: palette=one-dark (profile ${uuid}), monospace=Berkeley Mono 11"
