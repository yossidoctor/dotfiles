#!/usr/bin/env bash
# clock.sh — the time.
#
# Time only, no date: the date is a thing you look up, not a thing you monitor,
# and it was the wider half of the item. `open -a Calendar` on click is where
# that lookup goes instead.
#
# The label is set with font.features=tnum in sketchybarrc, so every digit takes
# the same advance and 09:59 -> 10:00 moves nothing to its left.
set -uo pipefail

sketchybar --set "$NAME" label="$(date '+%H:%M')"
