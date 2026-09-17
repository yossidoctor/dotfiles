#!/usr/bin/env bash
# clock.sh — the date in the icon slot, the time in the label.
#
# The split keeps the time from jittering: the label is set with
# font.features=tnum in sketchybarrc, so every digit takes the same advance and
# 09:59 -> 10:00 moves nothing to its left. The date carries no such treatment
# because it only changes at midnight.
set -uo pipefail

sketchybar --set "$NAME" \
  icon="$(date '+%a %d %b')" \
  label="$(date '+%H:%M')"
