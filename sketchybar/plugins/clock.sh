#!/usr/bin/env bash
# clock.sh — date into the icon, time into the label.
#
# The split is what keeps the time from jittering: the label is set in
# sketchybarrc with font.features=tnum, so every digit takes the same advance
# and 09:59 -> 10:00 moves nothing to its left. The date carries no such
# treatment because it only changes at midnight.
#
# This item has no hover reveal — a time you have to hover for is not a clock —
# but it does take the hover fill, so the whole bar responds to the pointer
# consistently.
set -uo pipefail

source "$HOME/.config/sketchybar/theme.sh"

case "$SENDER" in
  mouse.entered)
    sketchybar --animate sin 10 --set "$NAME" background.color="$HOVER_BG"
    exit 0
    ;;
  mouse.exited)
    sketchybar --animate sin 10 --set "$NAME" background.color=0x00000000
    exit 0
    ;;
esac

sketchybar --set "$NAME" \
  icon="$(date '+%a %d %b')" \
  label="$(date '+%H:%M')"
