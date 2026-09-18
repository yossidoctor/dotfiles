#!/usr/bin/env bash
# menubar.sh — keep the native menu bar suppressed.
#
# menubar-hide sets the menu bar's alpha to 0, which at exactly 0 also stops it
# accepting mouse events, so the hover reveal never fires. macOS RESETS that
# alpha on space changes, display changes and on leaving Mission Control, so a
# one-shot call lasts until the first Ctrl+arrow. This re-applies it on the
# sketchybar events that correspond to those resets.
#
# Subscribed to space_change and display_change in sketchybarrc, and run once at
# startup from there. Mission Control exit has no sketchybar event of its own —
# front_app_switched fires on the way back out of it, which covers the common
# case of ending up in a different app.
set -uo pipefail

"$HOME/.config/sketchybar/menubar-hide" 0.0 2>/dev/null || true
