#!/bin/sh
# Get current location coordinates using ipinfo.io API
# Returns coordinates in format: latitude,longitude
# Falls back silently on failure (weather.sh will use IP-based wttr.in)

LOCATION=$(curl -s --max-time 2 "https://ipinfo.io/loc" 2>/dev/null)

if [ -n "$LOCATION" ]; then
  echo "$LOCATION"
  exit 0
else
  exit 1
fi
