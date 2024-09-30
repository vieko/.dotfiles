#!/bin/bash

# Get available Wi-Fi networks
networks=$(nmcli device wifi list | awk 'NR>1 {print $2 " (" $8 ")"}')

# Display available networks using a dmenu-like tool (rofi in this case)
selected_network=$(echo "$networks" | rofi -dmenu -p "Select Wi-Fi Network" | awk '{print $1}')

# If a network was selected, prompt for a password and connect
if [ -n "$selected_network" ]; then
    password=$(rofi -dmenu -p "Enter Password")
    nmcli device wifi connect "$selected_network" password "$password"
fi

