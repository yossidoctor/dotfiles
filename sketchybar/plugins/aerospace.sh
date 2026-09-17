#!/usr/bin/env bash
# aerospace.sh — repaints every workspace chip in one pass: the app-icon strip,
# the app names, and the focused highlight.
#
# ONE `aerospace list-windows --all` (~26ms measured) feeds all nine chips, and
# the nine --set arguments ride a single `sketchybar` invocation. The per-chip
# shape this replaced cost nine CLI calls (~304ms serial) for the same paint,
# and each call is a light refresh session that cancels the daemon's in-flight
# heavy pass (docs/aerospace/RETILE-DELAY.md § Root cause), so the fan-out was
# also postponing the GC that window-close staleness waits on.
#
# icon_map.sh is SOURCED, never exec'd per window — four sourced lookups
# measured 5.1ms against 6.5ms for one fork.
#
# $FOCUSED_WORKSPACE arrives from the --trigger in aerospace.toml; on the
# aerospace_window_change event it is absent, so the focused workspace is read
# back from AeroSpace instead.
#
# Window dedup is deliberate: a workspace holding five ghostty windows shows one
# ghostty glyph, not five.
set -uo pipefail

source "$HOME/.config/sketchybar/theme.sh"
source "$HOME/.config/sketchybar/icon_map.sh"

focused="${FOCUSED_WORKSPACE:-}"
[ -z "$focused" ] && focused="$(aerospace list-workspaces --focused 2>/dev/null)"

windows="$(aerospace list-windows --all --format '%{workspace}|%{app-name}' 2>/dev/null)"

# The chip set is whatever sketchybarrc added, read back from the bar so the
# workspace list lives in exactly one place.
workspaces="$(sketchybar --query bar | jq -r '.items[]' | grep '^space\.' | sed 's/^space\.//')"

args=()
for sid in $workspaces; do
  strip=""
  names=""
  seen=","
  while IFS='|' read -r ws app; do
    [ "$ws" = "$sid" ] || continue
    [ -z "$app" ] && continue
    case "$seen" in *",$app,"*) continue ;; esac
    seen="$seen$app,"
    __icon_map "$app"
    strip="$strip$icon_result"
    names="$names $app"
  done <<< "$windows"

  # The chip carries three type treatments across two slots: the icon holds the
  # app-font glyph run (letters are tofu in that font), and the label holds the
  # workspace number plus the app names in the text font. An empty workspace
  # keeps its chip — all nine are always drawn, which sidesteps the intermittent
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
    highlight=on
    bg="$ACCENT_FILL"
    border="$ACCENT"
  else
    highlight=off
    bg="$ITEM_BG"
    border="$ITEM_BORDER"
  fi

  args+=(--set "space.$sid"
    icon="$icon"
    label="$label"
    icon.padding_left="$icon_pad"
    icon.padding_right="$icon_pad"
    icon.highlight="$highlight"
    label.highlight="$highlight"
    background.color="$bg"
    background.border_color="$border")
done

sketchybar "${args[@]}"
