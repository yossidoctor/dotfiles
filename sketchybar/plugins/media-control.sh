#!/usr/bin/env bash
# media-control.sh <prev|play|next> — the popup's transport buttons.
#
# Only these three commands are wired. media-control's seek family
# (seek, skip-fifteen-seconds, go-back-fifteen-seconds) has an open upstream bug
# on macOS 26+ and was only partly repaired, so a scrubber would be a control
# that silently does nothing; play/pause/next/previous are the commands reported
# working.
#
# The command acts on whatever owns the now-playing session — it cannot be aimed
# at a particular app, so there is nothing to disambiguate here.
set -uo pipefail

case "$1" in
  prev) media-control previous-track ;;
  play) media-control toggle-play-pause ;;
  next) media-control next-track ;;
esac
