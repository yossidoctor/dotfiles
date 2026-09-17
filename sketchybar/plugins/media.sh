#!/usr/bin/env bash
# media.sh — the now-playing item, fed by the media-stream LaunchAgent.
#
# macOS exposes exactly one now-playing session to third parties, so this shows
# whichever app currently owns it — Spotify, a Safari tab, Apple TV — and cannot
# be pinned to one app or show several at once. Control Center's multi-row panel
# uses access no third party gets.
#
# The item never polls: media-stream.sh holds the only subscription and triggers
# media_update with TITLE/ARTIST/PLAYING/BUNDLE already extracted, so this runs
# only when the track or state actually changes.
#
# drawing is toggled rather than the label blanked — with nothing playing the
# pill disappears entirely instead of sitting empty on the bar.
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
esac

title="${TITLE:-}"
artist="${ARTIST:-}"
playing="${PLAYING:-}"

if [ -z "$title" ]; then
  sketchybar --set "$NAME" drawing=off popup.drawing=off
  exit 0
fi

if [ -n "$artist" ]; then
  label="$title — $artist"
else
  label="$title"
fi

if [ "$playing" = "true" ]; then
  icon="$ICON_MUSIC"
  color="$GREEN"
  sketchybar --set media.play icon="$ICON_PAUSE"
else
  icon="$ICON_MUSIC"
  color="$OVERLAY"
  sketchybar --set media.play icon="$ICON_PLAY"
fi

sketchybar --set "$NAME" \
  drawing=on \
  icon="$icon" \
  icon.color="$color" \
  label="$label"
