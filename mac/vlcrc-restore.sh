#!/bin/bash
# Restore VLC's preferences from the tracked vlcrc — re-runnable on every ./install.
#
# Usage: vlcrc-restore.sh <vlcrc>
#
# vlcrc is INI text, not a plist, so plist-restore.sh cannot apply it: there is
# no `defaults` domain backing it and `defaults import` rejects the format. VLC
# keeps the live settings in memory and writes the whole file out on quit, so a
# symlink is replaced by a regular file the first time VLC exits, and a copy
# made while VLC runs is overwritten moments later. The app is quit before the
# copy for that reason, and relaunched only if it was running.
#
# Machine-specific lines are stripped rather than restored — they are written by
# VLC on every run and carry no intent worth syncing across machines:
#   auhal-volume            last output volume, rewritten per session
#   auhal-audio-device      CoreAudio device id, differs per Mac
#   macosx-vdev             display index, differs per monitor setup
#
# The stamp records the tracked file's hash after a successful copy, so an
# unchanged vlcrc is a no-op and VLC is never quit needlessly.
set -uo pipefail

src="$1"
dest="$HOME/Library/Preferences/org.videolan.vlc/vlcrc"
stamp="${XDG_CACHE_HOME:-$HOME/.cache}/dotfiles/org.videolan.vlc.stamp"
self_hash="$(md5 -q "$src")"

if [ -f "$stamp" ] && [ "$(cat "$stamp")" = "$self_hash" ]; then
  echo "VLC settings unchanged since last apply — skipping."
  exit 0
fi

was_running=false
pgrep -xq VLC && was_running=true
killall VLC 2>/dev/null || true

mkdir -p "$(dirname "$dest")"
grep -vE '^(auhal-volume|auhal-audio-device|macosx-vdev)=' "$src" > "$dest"

$was_running && open -a VLC 2>/dev/null || true

mkdir -p "$(dirname "$stamp")"
printf '%s' "$self_hash" > "$stamp"
echo "VLC settings restored."
