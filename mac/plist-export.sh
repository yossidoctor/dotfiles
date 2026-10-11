#!/bin/bash
# Re-export an app's preferences into its tracked plist after changing them in
# the app. Run this, then commit the updated plist — plist-restore.sh picks up
# the change on the next ./install.
#
# Usage: plist-export.sh <defaults-domain> <plist>
#
# Volatile keys — state the app rewrites on every run without a preference
# changing — are stripped so they never dirty the diff. `volatile` below is the
# set, for BetterDisplay: per-display firstAdded/lastConnected/lastUnseen
# timestamps, the storedIdentifiers hardware fingerprints (monitor serials,
# EDID, display UUIDs — this repo is public, and they never match another
# Mac's displays anyway), the Paddle license hash, Finder save-panel chrome.
# A second app's plist adds its keys to the same regex.
#
# PlistBuddy treats a literal `:` inside a key name (firstAdded@Display:7) as a
# nesting separator, so it is escaped as `\:` or the Delete silently misses.
# Print's output can carry a raw <data> blob, which makes grep binary-sniff the
# stream and print "binary file matches" instead of the key names — `-a`
# forces text mode.
set -uo pipefail

domain="$1" plist="$2"
volatile='(firstAdded|lastConnected|lastUnseen|storedIdentifiers)@[^ =]*|Paddle-BetterDisplay-[^ =]*|NSNavPanelExpandedSizeForSaveMode|NSOSPLastRootDirectory'

defaults export "$domain" "$plist"
plutil -convert xml1 "$plist"

for key in $(/usr/libexec/PlistBuddy -c "Print" "$plist" | grep -aoE "$volatile" | sort -u); do
  /usr/libexec/PlistBuddy -c "Delete :${key//:/\\:}" "$plist" 2>/dev/null || true
done

echo "Exported $domain to $plist — review the diff and commit."
