#!/usr/bin/env bash
# battery.sh — the battery icon.
#
# The item is icon-only: SF Symbols' battery glyphs are drawn at fill levels, so
# the glyph itself carries the ballpark and there is no percentage label, no
# hover to reveal one, and no popup.
#
# One `pmset -g batt` serves both the level and the charging state, so the 180s
# poll is a single subprocess.
set -uo pipefail

source "$HOME/.config/sketchybar/theme.sh"

batt="$(pmset -g batt)"
pct="${batt#*	}"
pct="${pct%%%*}"
case "$pct" in
  ''|*[!0-9]*) exit 0 ;;
esac

charging=off
case "$batt" in *"AC Power"*) charging=on ;; esac

# Charging is its own glyph rather than a tint on the level glyph: a charging
# battery at 20% should not read as the same warning state as one draining at
# 20%, and the bolt says so at a glance.
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

sketchybar --set "$NAME" icon="$icon" icon.color="$color"
