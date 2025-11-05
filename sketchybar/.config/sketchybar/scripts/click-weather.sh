#!/bin/sh

# Open Weather app and refresh weather data
open -a Weather

# Force immediate weather update in sketchybar
sketchybar --trigger weather_update 2>/dev/null || sketchybar --update weather
