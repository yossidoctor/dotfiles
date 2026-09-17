#!/usr/bin/env bash
# front-app.sh — the focused window tile: app name as the icon slot, window
# title as the label.
#
# The app name comes from $INFO on front_app_switched, which carries it without
# a subprocess. The window TITLE has no such event — front_app_switched fires on
# app changes only, not when the focused app opens a different document — so it
# is read from AeroSpace, which tracks the focused window across both.
#
# Also subscribed to aerospace_window_change so switching windows WITHIN an app
# (Cmd+`) repaints the title; without it the tile would keep showing the title
# of whichever window happened to be focused when the app was last activated.
set -uo pipefail

source "$HOME/.config/sketchybar/theme.sh"
source "$HOME/.config/sketchybar/icon_map.sh"

case "$SENDER" in
  mouse.entered)
    sketchybar --set "$NAME" background.color="$HOVER_BG"
    exit 0
    ;;
  mouse.exited)
    sketchybar --set "$NAME" background.color=0x00000000
    exit 0
    ;;
esac

focused="$(aerospace list-windows --focused --format '%{app-name}|%{window-title}' 2>/dev/null | head -1)"
app="${focused%%|*}"
title="${focused#*|}"

# Nothing focused — an empty desktop, or AeroSpace still settling after a space
# switch. The tile hides rather than showing a stale app.
if [ -z "$app" ]; then
  sketchybar --set "$NAME" drawing=off
  exit 0
fi

# A window with no title (a palette, a sheet) leaves the label empty rather than
# repeating the app name in both slots.
if [ "$title" = "$app" ]; then
  title=""
fi

# Kept short deliberately: this item sits on the left and grows rightward toward
# the notch, and a long title would run underneath the camera housing where its
# first characters are simply invisible.
if [ "${#title}" -gt 28 ]; then
  title="${title:0:27}…"
fi

__icon_map "$app"

# App name and window title share one label, separated by a thin space and a
# middle dot. The app name is what you scan for, so it leads; the title is the
# detail after it. Two items would let them take different colors, at the cost
# of a second item to keep in sync for no gain the separator does not give.
if [ -n "$title" ]; then
  label="$app · $title"
else
  label="$app"
fi

sketchybar --set "$NAME" \
  drawing=on \
  icon="$icon_result" \
  label="$label"
