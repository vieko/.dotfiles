#!/bin/bash

# List available VPN connections
vpns=$(nmcli connection show --active | grep vpn | awk '{print $1}')
available_vpns=$(nmcli connection show | grep vpn | awk '{print $1}')

# If no VPN is active, list available VPNs to connect
if [ -z "$vpns" ]; then
    selected_vpn=$(echo "$available_vpns" | rofi -dmenu -p "Select VPN")

    # Connect to the selected VPN
    if [ -n "$selected_vpn" ]; then
        nmcli connection up "$selected_vpn"
    fi
else
    # Disconnect the active VPN if clicked
    nmcli connection down "$vpns"
fi
