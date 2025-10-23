#!/usr/bin/env bash

# Present Bluetooth actions
action=$(echo -e "Toggle Bluetooth\nList Devices\nConnect Device\nDisconnect Device" | rofi -dmenu -p "Bluetooth Menu")

case "$action" in
    "Toggle Bluetooth")
        # Check Bluetooth status and toggle
        bluetooth_status=$(bluetoothctl show | rg "Powered:" | awk '{print $2}')
        if [ "$bluetooth_status" == "yes" ]; then
            bluetoothctl power off && notify-send "Bluetooth" "Bluetooth powered off"
        else
            bluetoothctl power on && notify-send "Bluetooth" "Bluetooth powered on"
        fi
        ;;
    "List Devices")
        # List paired devices
        devices=$(bluetoothctl paired-devices | rg "Device" | awk '{print $2 " (" $3 ")"}')
        if [ -z "$devices" ]; then
            notify-send "Bluetooth" "No paired devices found"
        else
            echo "$devices" | rofi -dmenu -p "Paired Devices"
        fi
        ;;
    "Connect Device")
        # List available devices to connect
        available_devices=$(bluetoothctl devices | rg "Device" | awk '{print $2 " (" $3 ")"}')
        selected_device=$(echo "$available_devices" | rofi -dmenu -p "Select Device to Connect" | awk '{print $1}')
        
        if [ -n "$selected_device" ]; then
            bluetoothctl connect "$selected_device" && notify-send "Bluetooth" "Connected to $selected_device"
        else
            notify-send "Bluetooth" "No device selected"
        fi
        ;;
    "Disconnect Device")
        # List connected devices to disconnect
        connected_devices=$(bluetoothctl info | rg "Device" | awk '{print $2}')
        selected_device=$(echo "$connected_devices" | rofi -dmenu -p "Select Device to Disconnect" | awk '{print $1}')
        
        if [ -n "$selected_device" ]; then
            bluetoothctl disconnect "$selected_device" && notify-send "Bluetooth" "Disconnected from $selected_device"
        else
            notify-send "Bluetooth" "No device selected"
        fi
        ;;
esac
