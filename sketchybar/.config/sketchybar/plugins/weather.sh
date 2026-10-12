#!/bin/sh

. "$CONFIG_DIR/colors.sh"

# Get system location using geolocation API
# Falls back to IP-based location if geolocation fails
LOCATION=""
LOCATION_SCRIPT="$CONFIG_DIR/scripts/get-location.sh"

if [ -x "$LOCATION_SCRIPT" ]; then
  # Get GPS coordinates (format: lat,lon)
  COORDS=$("$LOCATION_SCRIPT" 2>/dev/null)
  if [ -n "$COORDS" ]; then
    LOCATION="$COORDS"
  fi
fi

# Fetch weather condition and temperature in one request (more efficient)
# %C = weather condition text, %t = temperature
# Format: "Condition,Temperature"
# -f: HTTP errors (rate limit, outage) yield no body instead of an HTML page.
WEATHER=$(curl -sf --max-time 10 "wttr.in/$LOCATION?format=%C,%t")

# Keep the last good reading when wttr is down or answers with an error
# string ("Unknown location; ...") instead of "Condition,+NN°X".
case "$WEATHER" in
  *,[+-][0-9]*°[CF]) ;;
  *) [ -n "$(sketchybar --query "$NAME" 2>/dev/null | grep -o '"value": "[+-][0-9]')" ] && exit 0
     WEATHER="" ;;
esac

if [ -z "$WEATHER" ]; then
  ICON="?"
  LABEL="--"
else
  # Split the response into condition and temperature
  CONDITION=$(echo "$WEATHER" | cut -d',' -f1)
  TEMP=$(echo "$WEATHER" | cut -d',' -f2)
  # Map condition to Nerd Font weather icons
  case "$CONDITION" in
    *[Cc]lear*|*[Ss]unny*) ICON="󰖙" ;;  # nf-md-weather_sunny
    *[Cc]loud*) ICON="󰖐" ;;  # nf-md-weather_cloudy
    *[Rr]ain*|*[Dd]rizzle*) ICON="󰖗" ;;  # nf-md-weather_rainy
    *[Ss]now*) ICON="󰖘" ;;  # nf-md-weather_snowy
    *[Tt]hunder*|*[Ss]torm*) ICON="󰖓" ;;  # nf-md-weather_lightning
    *[Ff]og*|*[Mm]ist*) ICON="󰖑" ;;  # nf-md-weather_fog
    *) ICON="󰖕" ;;  # nf-md-weather_partly_cloudy (default)
  esac
  LABEL="$TEMP"
fi

sketchybar --set "$NAME" icon="$ICON" icon.color="$BASE0D" label="$LABEL" label.color="$BASE07"
