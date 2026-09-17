#!/usr/bin/env bash
# volume.sh — the volume icon, and scroll-to-set.
#
# The item is icon-only: the glyph's wave count IS the reading, so there is no
# percentage label and no hover to reveal one. Five levels rather than four —
# speaker with no waves covers "on, but barely", which speaker.wave.1 would
# otherwise share with a third of the range.
#
# The reading arrives in $INFO on volume_change, so the steady state costs no
# subprocess at all: no poll, no osascript, nothing until the volume moves.
# Only the scroll branch and the fallback read spend anything.
#
# Scroll steps are deliberately coarse: $SCROLL_DELTA is ~1 per notch, which
# would make a full sweep a wrist exercise, so it is scaled by 5 unless ctrl is
# held — ctrl gives the raw delta for fine adjustment.
set -uo pipefail

source "$HOME/.config/sketchybar/theme.sh"

case "$SENDER" in
  mouse.clicked)
    # Left-click must not open the Sound pane: giving another app focus changes
    # the focused workspace, so every chip repaints as unfocused and the bar
    # looks like it lost its highlight. Right-click is the deliberate escape.
    case "${BUTTON:-left}" in
      right) open /System/Library/PreferencePanes/Sound.prefpane ;;
    esac
    exit 0
    ;;
  mouse.scrolled)
    step="${SCROLL_DELTA:-0}"
    case "${MODIFIER:-}" in
      ctrl) ;;
      *) step=$((step * 5)) ;;
    esac
    osascript -e "set volume output volume (output volume of (get volume settings) + ($step))" 2>/dev/null
    exit 0
    ;;
esac

# volume-level answers both questions AppleScript cannot: whether the output
# device has a software volume at all, and what it is. A DisplayPort monitor has
# none — macOS greys out its own slider — and AppleScript reports that case as
# the literal string `missing value`, which is indistinguishable from an error
# and once reached the bar as a label reading "missing value%".
#
# No controllable level means the item DRAWS NOTHING. A speaker glyph there
# would claim a level the system cannot read, and a muted one would claim
# silence while the monitor plays audio at its own hardware volume.
reading="$("$HOME/.config/sketchybar/volume-level" 2>/dev/null || echo none)"
if [ "$reading" = none ]; then
  sketchybar --set "$NAME" drawing=off
  exit 0
fi

vol="${reading%% *}"
muted="${reading##* }"

if [ "$muted" = 1 ] || [ "$vol" -eq 0 ]; then
  icon="$ICON_VOL_MUTE"
  color="$OVERLAY"
elif [ "$vol" -lt 15 ]; then
  icon="$ICON_VOL_MIN"
  color="$SKY"
elif [ "$vol" -lt 40 ]; then
  icon="$ICON_VOL_LOW"
  color="$SKY"
elif [ "$vol" -lt 70 ]; then
  icon="$ICON_VOL_MID"
  color="$SKY"
else
  icon="$ICON_VOL_HIGH"
  color="$SKY"
fi

sketchybar --set "$NAME" drawing=on icon="$icon" icon.color="$color"
