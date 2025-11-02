#!/bin/sh

# Base16 One Dark colors
BASE07=0xffc8ccd4  # Foreground
BASE0D=0xff61afef  # Blue

# Fetch weather condition and temperature separately
# %C = weather condition text, %t = temperature
CONDITION=$(curl -s 'wttr.in/?format=%C')
TEMP=$(curl -s 'wttr.in/?format=%t')

# If curl fails or returns empty, show fallback
if [ -z "$CONDITION" ] || [ -z "$TEMP" ]; then
  ICON="?"
  LABEL="--"
else
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
