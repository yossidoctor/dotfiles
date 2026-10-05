#!/bin/bash
# Spotlight: indexing on for the data volume, where the home lives (the
# sealed system volume at / has its own store and nothing of yours), with
# exactly the folders below kept out of the index. Finder search, Mail search, the Open/Save dialog
# search field and `mas` all read this index; Raycast owns ⌘Space separately
# (mac/defaults.sh unbinds the Spotlight hotkeys).
#
# Excluded: the work tree, whose node_modules, .venv and build output are
# hundreds of thousands of files rewritten on every install and searched by
# ripgrep, never Finder; and Homebrew's prefix, rewritten on every upgrade.
# Hidden folders (~/.cache, ~/.npm, ~/.claude, .git, .venv), ~/Library/Caches
# and ~/.Trash are skipped by Spotlight's own rules and need no entry.
#
# The list cannot be written from a script: the indexer keeps its master copy
# under /private/var/db/Spotlight-V100, unreadable even to root, and
# overwrites the volume's VolumeConfiguration.plist from it whenever the
# volume comes up, so a PlistBuddy edit there is undone (seen 2026-10-05); a
# .metadata_never_index marker is ignored on this macOS too. The one writer
# is System Settings › Spotlight › Search Privacy. This script therefore
# turns indexing on, reads the live list, and when it differs from the one
# above says exactly what to add and remove there, exiting 1 so ./install
# (which guards it with `|| true`) shows the message without aborting.
# Entries whose folder no longer exists are ignored: the sheet hides them,
# so they cannot be removed, and they exclude nothing.
# Reading the list needs sudo; run by hand:  sudo bash mac/spotlight.sh
set -uo pipefail

exclusions=(
  "$HOME/Dono"
  /opt/homebrew
)

volume=/System/Volumes/Data
plist=$volume/.Spotlight-V100/VolumeConfiguration.plist
pb=/usr/libexec/PlistBuddy

if ! mdutil -s "$volume" | grep -q "Indexing enabled"; then
  sudo mdutil -i on "$volume" || exit 1
  for _ in 1 2 3 4 5 6 7 8 9 10; do [ -e "$plist" ] && break; sleep 1; done
fi

current=$(sudo "$pb" -c 'Print :Exclusions' "$plist" 2>/dev/null | sed -e '1d' -e '$d' -e 's/^ *//' | while IFS= read -r d; do [ -e "$d" ] && printf '%s\n' "$d"; done | sort)
wanted=$(printf '%s\n' "${exclusions[@]}" | sort)

mdutil -s "$volume"
if [ "$current" = "$wanted" ]; then
  echo "Search Privacy list matches."; exit 0
fi
echo "Search Privacy list differs from mac/spotlight.sh. In System Settings › Spotlight › Search Privacy:"
comm -13 <(printf '%s\n' "$current") <(printf '%s\n' "$wanted") | sed 's/^/  add:    /'
comm -23 <(printf '%s\n' "$current") <(printf '%s\n' "$wanted") | sed 's/^/  remove: /'
exit 1
