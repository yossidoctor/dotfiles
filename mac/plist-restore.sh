#!/usr/bin/env bash
# Restore an app's preferences from a tracked plist — re-runnable on every ./install.
#
# Usage: plist-restore.sh <ProcessName> <defaults-domain> <plist>
#
# For apps whose settings are nested structures rather than flat scalars
# (BetterDisplay's per-display UUID-keyed entries, BetterCmdTab's
# shortcutOverrides/appExceptions arrays), whole-plist export/import via
# `defaults` is the vendor-sanctioned mechanism; hand-editing the plist on
# disk is not, because cfprefsd caches the live values and rewrites the file
# on quit. The app is quit before the import so that rewrite cannot clobber
# it, and relaunched only if it was running.
#
# The stamp (keyed by domain) records the plist's hash after a successful
# import, so an unchanged plist is a no-op — the app is not touched. Per-display
# entries are UUID-keyed, so a plist may not carry over cleanly to a different
# Mac or monitor setup. After changing settings in the app, run
# plist-export.sh with the same domain and plist to refresh the tracked file.
set -uo pipefail

app="$1" domain="$2" plist="$3"
stamp="${XDG_CACHE_HOME:-$HOME/.cache}/dotfiles/$domain.stamp"
self_hash="$(md5 -q "$plist")"

if [ -f "$stamp" ] && [ "$(cat "$stamp")" = "$self_hash" ]; then
  echo "$app settings unchanged since last apply — skipping."
  exit 0
fi

was_running=false
pgrep -xq "$app" && was_running=true
killall "$app" 2>/dev/null || true

defaults import "$domain" "$plist"

$was_running && open -a "$app" 2>/dev/null || true

mkdir -p "$(dirname "$stamp")"
printf '%s' "$self_hash" > "$stamp"
echo "$app settings imported."
