#!/usr/bin/env bash
# hover.sh — the pointer-feedback fill, for every item whose own script does not
# already handle hover.
#
# media carries this in its own plugin instead, because the fill has to ride the
# same --animate call as its width change or the two land a frame apart. volume
# and battery take no hover at all — they are icon-only status glyphs.
#
# Both branches act immediately. An earlier version deferred the clear by a
# quarter second to absorb the mouse.exited that fires on small movements
# INSIDE an item; that was visible as lag, since sweeping the chips left a trail
# of fills each waiting to catch up. The flicker it guarded against is invisible
# beside that, so the debounce is gone.
#
# A workspace chip is the one item that must NOT take the fill while focused:
# it already draws the solid white pill, and a hover tint over it would only
# muddy the one shape the bar uses to mark focus. The focused chip is
# identified by its own highlight rather than by asking AeroSpace, which would
# cost a subprocess on every pointer movement across the bar.
set -uo pipefail

source "$HOME/.config/sketchybar/theme.sh"

case "$NAME" in
  space.*)
    if [ "$(sketchybar --query "$NAME" 2>/dev/null | jq -r '.icon.highlight')" = "on" ]; then
      exit 0
    fi
    ;;
esac

case "$SENDER" in
  mouse.entered)
    sketchybar --animate sin 8 --set "$NAME" background.color="$HOVER_BG"
    ;;
  mouse.exited)
    sketchybar --animate sin 8 --set "$NAME" background.color=0x00000000
    ;;
esac
