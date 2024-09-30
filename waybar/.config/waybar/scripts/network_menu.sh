#!/bin/bash

# Present options for Wi-Fi and VPN management
action=$(echo -e "Connect to Wi-Fi\nManage VPN" | rofi -dmenu -p "Network Menu")

case "$action" in
    "Connect to Wi-Fi")
        # List available Wi-Fi networks
        networks=$(nmcli device wifi list | awk 'NR>1 {print $2 " (" $8 ")"}')
        selected_network=$(echo "$networks" | rofi -dmenu -p "Select Wi-Fi Network" | awk '{print $1}')

        # If a network was selected, prompt for a password and connect
        if [ -n "$selected_network" ]; then
            password=$(rofi -dmenu -p "Enter Password")
            nmcli device wifi connect "$selected_network" password "$password"
        fi
        ;;
    "Manage VPN")
        # List VPNs
        vpns=$(nmcli connection show --active | grep vpn | awk '{print $1}')
        available_vpns=$(nmcli connection show | grep vpn | awk '{print $1}')

        if [ -z "$vpns" ]; then
            # If no VPN is active, show list of available VPNs to connect
            selected_vpn=$(echo "$available_vpns" | rofi -dmenu -p "Select VPN")

            # Connect to selected VPN
            if [ -n "$selected_vpn" ]; then
                nmcli connection up "$selected_vpn"
            fi
        else
            # If a VPN is active, give option to disconnect
            nmcli connection down "$vpns"
        fi
        ;;
esac

