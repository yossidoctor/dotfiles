#!/bin/bash
# Spotlight: indexing on for the system volume, with exactly the folders below
# kept out of the index. Finder search, Mail search, the Open/Save dialog
# search field and `mas` all read this index; Raycast owns ⌘Space separately
# (mac/defaults.sh unbinds the Spotlight hotkeys).
#
# Excluded: the work tree, whose node_modules, .venv and build output are
# hundreds of thousands of files rewritten on every install and searched by
# ripgrep, never Finder; and Homebrew's prefix, rewritten on every upgrade.
# Hidden folders (~/.cache, ~/.npm, ~/.claude, .git, .venv), ~/Library/Caches
# and ~/.Trash are skipped by Spotlight's own rules and need no entry.
#
# This list is the whole list: the volume's VolumeConfiguration.plist, which
# System Settings › Spotlight › Search Privacy also shows, is rewritten to
# match it, so an entry added by hand there or inherited from an old setup is
# removed on the next run. Writing it needs root; the indexer cannot be
# restarted under SIP, so a changed list is followed by `mdutil -E`, which
# rebuilds the index from the new config. An unchanged list touches nothing.
# Wired into ./install guarded by `|| true`, so a non-interactive run without
# sudo skips it; run by hand for a guaranteed apply:  sudo bash mac/spotlight.sh
set -uo pipefail

exclusions=(
  "$HOME/Dono"
  /opt/homebrew
)

plist=/System/Volumes/Data/.Spotlight-V100/VolumeConfiguration.plist
pb=/usr/libexec/PlistBuddy

if ! mdutil -s / | grep -q "Indexing enabled"; then
  sudo mdutil -i on / || exit 1
  for _ in 1 2 3 4 5 6 7 8 9 10; do [ -e "$plist" ] && break; sleep 1; done
fi

current=$(sudo "$pb" -c 'Print :Exclusions' "$plist" 2>/dev/null | sed -e '1d' -e '$d' -e 's/^ *//' | sort)
wanted=$(printf '%s\n' "${exclusions[@]}" | sort)

if [ "$current" != "$wanted" ]; then
  sudo "$pb" -c 'Delete :Exclusions' "$plist" >/dev/null 2>&1
  sudo "$pb" -c 'Add :Exclusions array' "$plist" || exit 1
  for dir in "${exclusions[@]}"; do
    sudo "$pb" -c "Add :Exclusions: string $dir" "$plist" || exit 1
  done
  sudo mdutil -E / >/dev/null
  echo "Exclusions rewritten; index rebuilding."
fi

mdutil -s /
echo "Exclusions:"; sudo "$pb" -c 'Print :Exclusions' "$plist" 2>/dev/null | sed -e '1d' -e '$d'
