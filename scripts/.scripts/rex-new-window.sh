#!/usr/bin/env bash
# rex-new-window.sh -- open a new Rex window from anywhere (Aerospace
# cmd-shift-enter), the Rex counterpart of Ghostty's
# `global:super+shift+enter=new_window`.
#
# Brings Rex to the front; when its server runs, asks the app for a new
# window, which needs Remote Control on (Settings, Rex Server). A Rex that
# was not running opens its own window on launch, so nothing more is sent.
# Aerospace runs this with a bare PATH, so every tool is an absolute path.

set -uo pipefail

REX="$HOME/Library/Application Support/com.superlogical.rex/RexServer/Versions/Current/Rex Server.app/Contents/MacOS/rex"
APP_ID=com.superlogical.rex

running=0
/usr/bin/pgrep -qf 'Rex Beta.app/Contents/MacOS' && running=1

/usr/bin/open -b "$APP_ID"
[[ $running -eq 1 && -x "$REX" ]] || exit 0

# The Mac app's client label is this host's name (rex client ls).
client=$(/bin/hostname -s | /usr/bin/tr '[:upper:]' '[:lower:]')
"$REX" --autostart=false -C "$client" "do" client.window.new >/dev/null 2>&1
