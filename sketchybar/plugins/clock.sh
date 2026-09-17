#!/usr/bin/env bash
# clock.sh — date into the icon, time into the label.
#
# The split is what keeps the time from jittering: label.width is fixed at 38 in
# sketchybarrc and right-aligned, so a change from 09:59 to 10:00 moves nothing
# to its left. The date carries no width because it only changes at midnight.
#
# This item is not part of the hover group and has no reveal — a time you have to
# hover for is not a clock.
set -uo pipefail

sketchybar --set "$NAME" \
  icon="$(date '+%a %d %b')" \
  label="$(date '+%H:%M')"
