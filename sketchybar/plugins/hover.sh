#!/usr/bin/env bash
# hover.sh — the pointer-feedback fill, for every item whose own script does not
# already handle hover.
#
# Items that animate on hover (battery, volume, media) carry this in their own
# plugin instead, because the fill has to ride the same --animate call as the
# width change or the two land a frame apart.
#
# A workspace chip is the one item that must NOT take the fill while focused:
# it already draws the solid white pill, and a hover tint over it would only
# muddy the one shape the bar uses to mark focus. The focused chip is
# identified by its own fill rather than by asking AeroSpace, which would cost
# a subprocess on every pointer movement across the bar.
set -uo pipefail

source "$HOME/.config/sketchybar/theme.sh"

# Per-item, so a pending clear on one item is not cancelled by the pointer
# arriving on another.
STAMP="${TMPDIR:-/tmp}/sketchybar-hover-$NAME"

case "$SENDER" in
  mouse.entered)
    case "$NAME" in
      space.*)
        if [ "$(sketchybar --query "$NAME" 2>/dev/null | jq -r '.icon.highlight')" = "on" ]; then
          exit 0
        fi
        ;;
    esac
    rm -f "$STAMP"
    sketchybar --animate sin 10 --set "$NAME" background.color="$HOVER_BG"
    ;;
  mouse.exited)
    case "$NAME" in
      space.*)
        if [ "$(sketchybar --query "$NAME" 2>/dev/null | jq -r '.icon.highlight')" = "on" ]; then
          exit 0
        fi
        ;;
    esac
    # Debounced for the same reason as the popup rows: mouse.exited fires on
    # small movements inside an item as well as on leaving it, and clearing the
    # fill immediately makes the highlight flicker under a stationary pointer.
    # A re-entry within the grace period stamps the file again, so only a real
    # departure clears it.
    token="$(date +%s%N)"
    printf '%s' "$token" > "$STAMP"
    sleep 0.25
    if [ "$(cat "$STAMP" 2>/dev/null)" = "$token" ]; then
      rm -f "$STAMP"
      sketchybar --animate sin 10 --set "$NAME" background.color=0x00000000
    fi
    ;;
esac
