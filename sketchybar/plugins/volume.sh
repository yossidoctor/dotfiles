#!/usr/bin/env bash
# volume.sh — volume icon, percentage label, hover reveal, and scroll-to-set.
#
# The reading arrives in $INFO on volume_change, so the steady state costs no
# subprocess at all: no poll, no osascript, nothing until the volume actually
# moves. Only the scroll branch spends anything.
#
# Scroll steps are deliberately coarse: $SCROLL_DELTA is ~1 per notch, which
# would make a full sweep a wrist exercise, so it is scaled by 5 unless ctrl is
# held — ctrl gives the raw delta for fine adjustment.
set -uo pipefail

source "$HOME/.config/sketchybar/theme.sh"

case "$SENDER" in
  mouse.entered)
    sketchybar --animate tanh 20 --set "$NAME" label.width=dynamic
    exit 0
    ;;
  mouse.exited)
    sketchybar --animate tanh 20 --set "$NAME" label.width=0
    exit 0
    ;;
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
    osascript -e "set volume output volume (output volume of (get volume settings) + ($step))"
    exit 0
    ;;
esac

vol="${INFO:-}"
# A forced update carries no $INFO, so the current level is read back instead.
if [ -z "$vol" ]; then
  vol="$(osascript -e 'output volume of (get volume settings)' 2>/dev/null)"
fi
[ -z "$vol" ] && exit 0

if [ "$vol" -eq 0 ]; then
  icon="$ICON_VOL_MUTE"
  color="$OVERLAY"
elif [ "$vol" -lt 34 ]; then
  icon="$ICON_VOL_LOW"
  color="$SKY"
elif [ "$vol" -lt 67 ]; then
  icon="$ICON_VOL_MID"
  color="$SKY"
else
  icon="$ICON_VOL_HIGH"
  color="$SKY"
fi

sketchybar --set "$NAME" \
  icon="$icon" \
  icon.color="$color" \
  label="${vol}%"
