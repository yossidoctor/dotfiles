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

vol="${INFO:-}"
# A forced update carries no $INFO, so the current level is read back instead.
if [ -z "$vol" ]; then
  vol="$(osascript -e 'output volume of (get volume settings)' 2>/dev/null)"
fi

# macOS answers `missing value` — not a number, not an error — whenever the
# output device cannot report a level, which some Bluetooth and AirPlay devices
# never can. Anything non-numeric means "no reading available", and the item
# shows the muted glyph rather than printing the words at the user.
case "$vol" in
  ''|*[!0-9]*)
    sketchybar --set "$NAME" icon="$ICON_VOL_MUTE" icon.color="$OVERLAY"
    exit 0
    ;;
esac

if [ "$vol" -eq 0 ]; then
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

sketchybar --set "$NAME" icon="$icon" icon.color="$color"
