#!/usr/bin/env bash
# battery.sh — battery icon, percentage label, and the hover reveal.
#
# One `pmset -g batt` serves the percentage, the charging state and the popup's
# time-remaining, so the 180s poll and every hover share a single subprocess.
#
# $SENDER tells the three jobs apart: mouse.entered/exited animate the label
# open and shut, everything else (routine, power_source_change, system_woke,
# forced) repaints the reading.
set -uo pipefail

source "$HOME/.config/sketchybar/theme.sh"

case "$SENDER" in
  mouse.entered)
    sketchybar --animate sin 12 --set "$NAME" label.width=dynamic \
      background.color="$HOVER_BG"
    exit 0
    ;;
  mouse.exited)
    sketchybar --animate sin 12 --set "$NAME" label.width=0 \
      background.color=0x00000000
    exit 0
    ;;
esac

batt="$(pmset -g batt)"
pct="${batt#*	}"
pct="${pct%%%*}"
[ -z "$pct" ] && exit 0

charging=off
case "$batt" in *"AC Power"*) charging=on ;; esac

if [ "$charging" = on ]; then
  icon="$ICON_BATT_CHARGING"
  color="$GREEN"
elif [ "$pct" -ge 80 ]; then
  icon="$ICON_BATT_FULL"
  color="$GREEN"
elif [ "$pct" -ge 60 ]; then
  icon="$ICON_BATT_75"
  color="$GREEN"
elif [ "$pct" -ge 40 ]; then
  icon="$ICON_BATT_50"
  color="$YELLOW"
elif [ "$pct" -ge 20 ]; then
  icon="$ICON_BATT_25"
  color="$PEACH"
else
  icon="$ICON_BATT_EMPTY"
  color="$RED"
fi

sketchybar --set "$NAME" \
  icon="$icon" \
  icon.color="$color" \
  label="${pct}%"

# pmset prints a remaining estimate only once it has one; while it is still
# computing, the field reads (no estimate) and the popup says so rather than
# showing a stale duration.
remaining="$(printf '%s' "$batt" | sed -n 's/.*[;] *\([0-9][0-9]*:[0-9][0-9]\) remaining.*/\1/p')"
if [ -n "$remaining" ]; then
  sketchybar --set battery.remaining label="${remaining}h"
else
  sketchybar --set battery.remaining label="no estimate"
fi
