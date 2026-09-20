#!/usr/bin/env bash
# Extract a fullscreen window and the window that just opened into a free
# workspace, side by side, leaving the rest of the original workspace intact.
#
# Wired to on-window-detected in aerospace.toml, with
# check-further-callbacks = true so the per-app layout rules below it still
# run. AEROSPACE_WINDOW_ID is the newly detected window (guide § exec-*
# Environment Variables); the script exits silently whenever anything is not
# as expected, so the default behavior is always AeroSpace's own.
#
# THE RACE THIS RIDES. Opening a tiling window while another is fullscreen
# makes AeroSpace exit that fullscreen — upstream design #422, the
# exit-on-focus rule. Measured on this machine (30 samples at 100ms,
# 2026-09-20): the new window appears in the tree at t=300ms still reporting
# the old one `window-is-fullscreen == true`, and #422 lands at t=400ms. So
# the fullscreen id is readable for roughly 100ms after detection and no
# tracking file is needed — but the read MUST be the first thing this script
# does. Anything before it (a workspace scan, a second CLI call) risks
# spending the margin. A daemon stall eats the margin regardless
# (docs/aerospace/RETILE-DELAY.md § Daemon GC hang), in which case the read
# returns nothing and the script exits: the user sees today's behavior.
#
# A floating window never triggers #422 and never tiles beside anything, so
# it is not a trigger here: the new window must be tiling. The float rules in
# aerospace.toml (Finder, Calculator, Mail, VLC, …) therefore exempt
# themselves, and so does any window AeroSpace floats on its own.
#
# Never closes, kills, or minimizes — the invariant reap-ghosts.sh states and
# docs/aerospace/RETILE-DELAY.md records the incident behind.
set -euo pipefail

AS=/opt/homebrew/bin/aerospace
new_id="${AEROSPACE_WINDOW_ID:-}"
[ -n "$new_id" ] || exit 0

read -r fs_id fs_ws < <(
  "$AS" list-windows --monitor all \
        --format '%{window-id} %{workspace} %{window-is-fullscreen} %{window-layout}' 2>/dev/null |
  awk '$3 == "true" && $4 != "floating" { print $1, $2; exit }'
) || exit 0
[ -n "${fs_id:-}" ] || exit 0
[ "$fs_id" != "$new_id" ] || exit 0

read -r new_ws new_layout < <(
  "$AS" list-windows --monitor all \
        --format '%{window-id} %{workspace} %{window-layout}' 2>/dev/null |
  awk -v id="$new_id" '$1 == id { print $2, $3; exit }'
) || exit 0
[ "${new_layout:-}" = "floating" ] && exit 0
[ "${new_ws:-}" = "$fs_ws" ] || exit 0

occupied=$("$AS" list-workspaces --monitor all --format '%{workspace}' 2>/dev/null)
target=$(awk -v used="$occupied" 'BEGIN {
  split(used, a, "\n")
  for (i in a) seen[a[i]] = 1
  for (n = 1; n <= 9; n++) if (!(n in seen)) { print n; exit }
}')
[ -n "$target" ] || exit 0

"$AS" move-node-to-workspace --window-id "$fs_id" "$target" >/dev/null 2>&1 || exit 0
"$AS" move-node-to-workspace --window-id "$new_id" "$target" >/dev/null 2>&1 || true
"$AS" workspace "$target" >/dev/null 2>&1 || true
"$AS" focus --window-id "$new_id" >/dev/null 2>&1 || true
