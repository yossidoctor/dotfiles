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

ROWS="media.row.system media.row.spotify media.row.vlc"

case "$SENDER" in
  mouse.entered)
    # Every OTHER row is cleared here rather than each row clearing itself on
    # exit. Moving between rows fires enter on the new row and exit on the old
    # one with no guaranteed order, and when the exit lands second it repaints
    # a fill the pointer has already left — two rows lit at once. Clearing from
    # the row that owns the pointer cannot lose that race.
    args=()
    for r in $ROWS; do
      [ "$r" = "$NAME" ] && continue
      args+=(--set "$r" background.color=0x00000000)
    done
    sketchybar --animate sin 8 --set "$NAME" background.color="$HOVER_BG" \
      "${args[@]}"
    ;;
  mouse.exited)
    # The fill is NOT cleared here: if the pointer moved to a sibling row, that
    # row's mouse.entered already cleared this one, and clearing again after the
    # sleep below would fight it. A pointer that left the popup entirely gets
    # every row cleared by the close path instead.
    #
    # A short settle first: the pointer is mid-movement when this fires, and
    # sampling immediately can catch it a few points outside a row it is about
    # to land back inside.
    sleep 0.25

    y="$("$HOME/.config/sketchybar/pointer-y" 2>/dev/null || echo 0)"
    if [ "$y" -gt "$POPUP_BOTTOM" ]; then
      args=()
      for r in $ROWS; do
        args+=(--set "$r" background.color=0x00000000)
      done
      sketchybar --set media popup.drawing=off "${args[@]}"
    fi
    ;;
esac
