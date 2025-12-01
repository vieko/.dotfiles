#!/bin/sh

# Base16 One Dark colors
BASE07=0xffc8ccd4  # Foreground
BASE0E=0xffc678dd  # Purple

# Get Wi-Fi interface
WIFI_INTERFACE=$(networksetup -listallhardwareports | awk '/Wi-Fi/{getline; print $2}')

# Check for wired connection (USB Ethernet, Thunderbolt, etc.)
WIRED=""
for iface in $(ifconfig -l); do
  case "$iface" in
    lo*|awdl*|llw*|utun*|bridge*|gif*|stf*|ap*|anpi*|"$WIFI_INTERFACE") continue ;;
  esac
  if ifconfig "$iface" 2>/dev/null | grep -q "status: active"; then
    if ifconfig "$iface" 2>/dev/null | grep -q "inet "; then
      WIRED="$iface"
      break
    fi
  fi
done

# Check Wi-Fi status
WIFI_ACTIVE=""
WIFI_POWER=$(networksetup -getairportpower "$WIFI_INTERFACE" 2>/dev/null | grep -c "On")
if [ "$WIFI_POWER" = "1" ]; then
  if ifconfig "$WIFI_INTERFACE" 2>/dev/null | grep -q "status: active"; then
    if ifconfig "$WIFI_INTERFACE" 2>/dev/null | grep -q "inet "; then
      WIFI_ACTIVE="1"
    fi
  fi
fi

if [ -n "$WIRED" ]; then
  ICON="󰈀"  # nf-md-ethernet
  LABEL="LAN"
elif [ -n "$WIFI_ACTIVE" ]; then
  ICON="󰖩"  # nf-md-wifi
  LABEL="WIFI"
else
  ICON="󰖪"  # nf-md-wifi_off
  LABEL="OFF"
fi

sketchybar --set "$NAME" icon="$ICON" icon.color="$BASE0E" label="$LABEL" label.color="$BASE07"
