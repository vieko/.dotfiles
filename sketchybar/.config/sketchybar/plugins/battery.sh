#!/bin/sh

. "$CONFIG_DIR/colors.sh"

PERCENTAGE="$(pmset -g batt | grep -Eo "\d+%" | cut -d% -f1)"
CHARGING="$(pmset -g batt | grep 'AC Power')"

if [ "$PERCENTAGE" = "" ]; then
  exit 0
fi

# Set icon based on battery level (Nerd Font icons)
case "${PERCENTAGE}" in
  9[0-9]|100) ICON="󰁹"  # nf-md-battery_charging_100
  ;;
  [6-8][0-9]) ICON="󰂀"  # nf-md-battery_80
  ;;
  [3-5][0-9]) ICON="󰁾"  # nf-md-battery_50
  ;;
  [1-2][0-9]) ICON="󰁻"  # nf-md-battery_20
  ;;
  *) ICON="󰂎"  # nf-md-battery_alert
esac

# Override icon if charging
if [[ "$CHARGING" != "" ]]; then
  ICON="󰂄"  # nf-md-battery_charging
fi

# Set colors based on state
if [[ "$CHARGING" != "" ]]; then
  # Charging (any level)
  ICON_COLOR="$BASE0E"
elif [ "$PERCENTAGE" -le 15 ]; then
  # Critical
  ICON_COLOR="$BASE08"
elif [ "$PERCENTAGE" -le 30 ]; then
  # Warning
  ICON_COLOR="$BASE09"
else
  # Normal
  ICON_COLOR="$BASE0E"
fi

# Always show percentage
LABEL="${PERCENTAGE}%"

sketchybar --set "$NAME" icon="$ICON" icon.color="$ICON_COLOR" label="$LABEL" label.color="$BASE07"
