#!/usr/bin/env bash
# media-row.sh — hover fill and popup dismissal for the source rows.
#
# The popup cannot be closed from the pill's own mouse.exited: the pointer has
# to leave the pill to reach the rows, so that event fires on the way IN.
#
# It also cannot be closed on a row's mouse.exited alone, in either direction:
# that event fires on small movements WITHIN a row as well as on leaving one, so
# closing on it shuts the menu mid-read, and it does not fire at all when the
# pointer leaves the popup sideways or quickly, so relying on it strands the
# menu open.
#
# So neither the event nor a timer decides — the pointer's actual position does,
# against POPUP_BOTTOM in theme.sh. This handler covers leaving a row, and
# media.sh's mouse.exited.global covers every other way out of the popup.
set -uo pipefail

source "$HOME/.config/sketchybar/theme.sh"

case "$SENDER" in
  mouse.entered)
    sketchybar --animate sin 8 --set "$NAME" background.color="$HOVER_BG"
    ;;
  mouse.exited)
    sketchybar --animate sin 8 --set "$NAME" background.color=0x00000000

    # A short settle first: the pointer is mid-movement when this fires, and
    # sampling immediately can catch it a few points outside a row it is about
    # to land back inside.
    sleep 0.25

    y="$("$HOME/.config/sketchybar/pointer-y" 2>/dev/null || echo 0)"
    if [ "$y" -gt "$POPUP_BOTTOM" ]; then
      sketchybar --set media popup.drawing=off
    fi
    ;;
esac
