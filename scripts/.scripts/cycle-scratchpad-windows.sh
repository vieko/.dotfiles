#!/bin/bash

# Function to log debug information
debug_log() {
    echo "[DEBUG] $1" >&2
}

debug_log "Starting scratchpad window cycler"

# Get all windows in the scratchpad
scratchpad_windows=$(hyprctl clients -j | jq -r '.[] | select(.workspace.name == "special:scratchpad") | {address: .address, title: .title}')
debug_log "Scratchpad windows:"
echo "$scratchpad_windows" >&2

# Extract just the addresses
window_addresses=$(echo "$scratchpad_windows" | jq -r '.address')

# If there are no windows in scratchpad, exit
if [ -z "$window_addresses" ]; then
    debug_log "No windows found in scratchpad. Exiting."
    exit 0
fi

# Get the currently focused window
focused_window=$(hyprctl activewindow -j | jq -r '.address')
debug_log "Focused window: $focused_window"

# Find the next window to focus
next_window=""
found_current=false
while read -r window; do
    if [ "$found_current" = true ]; then
        next_window=$window
        break
    fi
    if [ "$window" = "$focused_window" ]; then
        found_current=true
    fi
done <<< "$window_addresses"

# If we didn't find a next window, wrap around to the first one
if [ -z "$next_window" ]; then
    next_window=$(echo "$window_addresses" | head -n 1)
fi

debug_log "Next window to focus: $next_window"

# Focus the next window
if [ -n "$next_window" ]; then
    # Move the window to the current workspace temporarily
    current_workspace=$(hyprctl activeworkspace -j | jq -r '.id')
    hyprctl dispatch movetoworkspace "$current_workspace,address:$next_window"
    
    # Focus the window
    hyprctl dispatch focuswindow "address:$next_window"
    
    # Bring the active window to the top
    hyprctl dispatch bringactivetotop
    
    # Immediately move it back to the scratchpad
    hyprctl dispatch movetoworkspace "special:scratchpad,address:$next_window"
    
    debug_log "Focused window with address: $next_window and brought it to top"
else
    debug_log "No next window found to focus"
fi
