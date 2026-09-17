#!/usr/bin/env bash
# aerospace.sh <workspace-id> — repaints one workspace chip: the app-icon strip,
# the app names, and the focused highlight.
#
# Runs once per subscribed chip per event, so with nine workspaces a single
# workspace switch runs this nine times. Each run is one `aerospace list-windows`
# (~9.7ms measured, hyperfine 30 runs) plus in-shell lookups; icon_map.sh is
# SOURCED, never exec'd per window — four sourced lookups measured 5.1ms against
# 6.5ms for one fork.
#
# $FOCUSED_WORKSPACE arrives from the --trigger in aerospace.toml; on the
# aerospace_window_change event it is absent, so the focused workspace is read
# back from AeroSpace instead.
#
# Window dedup is deliberate: a workspace holding five ghostty windows shows one
# ghostty glyph, not five.
set -uo pipefail

sid="$1"

source "$HOME/.config/sketchybar/theme.sh"
source "$HOME/.config/sketchybar/icon_map.sh"

focused="${FOCUSED_WORKSPACE:-}"
[ -z "$focused" ] && focused="$(aerospace list-workspaces --focused 2>/dev/null)"

apps="$(aerospace list-windows --workspace "$sid" --format '%{app-name}' 2>/dev/null)"

strip=""
names=""
seen=","
while IFS= read -r app; do
  [ -z "$app" ] && continue
  case "$seen" in *",$app,"*) continue ;; esac
  seen="$seen$app,"
  __icon_map "$app"
  strip="$strip$icon_result"
  names="$names $app"
done <<< "$apps"

# The chip carries three type treatments across two slots: the icon holds the
# app-font glyph run (letters are tofu in that font), and the label holds the
# workspace number plus the app names in the text font. An empty workspace keeps
# its chip — all nine are always drawn, which sidesteps the intermittent
# `drawing` property bug on this OS class (#787).
if [ -z "$strip" ]; then
  icon=""
  label="$sid"
  icon_pad=0
else
  icon="$strip"
  label="$sid ${names# }"
  icon_pad=6
fi

if [ "$sid" = "$focused" ]; then
  sketchybar --set "space.$sid" \
    icon="$icon" \
    label="$label" \
    icon.padding_left="$icon_pad" \
    icon.padding_right="$icon_pad" \
    icon.highlight=on \
    label.highlight=on \
    background.color="$ACCENT_FILL" \
    background.border_color="$ACCENT"
else
  sketchybar --set "space.$sid" \
    icon="$icon" \
    label="$label" \
    icon.padding_left="$icon_pad" \
    icon.padding_right="$icon_pad" \
    icon.highlight=off \
    label.highlight=off \
    background.color="$ITEM_BG" \
    background.border_color="$ITEM_BORDER"
fi
