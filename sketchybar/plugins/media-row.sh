#!/usr/bin/env bash
# media-row.sh — hover fill and popup dismissal for the source rows.
#
# The popup cannot be closed from the pill's own mouse.exited: the pointer has
# to leave the pill to reach the rows, so that event fires on the way IN.
#
# It also cannot be closed on a row's mouse.exited alone. That event fires on
# small movements WITHIN a row as well as on leaving it, and an earlier version
# deferred the close and cancelled it when another row was entered. That works
# for every row except the last one: below the bottom row there is no row to
# enter, so nothing cancels the pending close and the menu shuts while the
# pointer is still resting on it.
#
# So the close asks where the pointer actually is. POPUP_BOTTOM is the distance
# from the top of the screen past which the pointer is no longer over the bar or
# its popup; while the pointer is above that line the menu stays open no matter
# how many spurious exits arrive, and the moment it drops below, the menu closes
# on the next event without waiting on a timer.
set -uo pipefail

source "$HOME/.config/sketchybar/theme.sh"

# Bar height 38 + popup y_offset 4 + at most three rows at background.height 26
# comes to ~120; this rounds well past that. Generous on purpose: overshooting
# only keeps the menu open slightly below its own bottom edge, while falling
# short reintroduces exactly the premature close this replaces.
POPUP_BOTTOM=190

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
