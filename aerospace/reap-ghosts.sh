#!/bin/bash
# Phantom-tile healer for AeroSpace's tiling tree, run on every focus/workspace
# event (and from retry-poke.sh). NEVER closes, kills, or minimizes a window —
# a hard invariant: a close-based reaper misclassifying one live window kills
# real work (it closed live Ghostty windows carrying Claude sessions on
# 2026-07-29). The one action it takes is layout-class: floating a window out
# of the tiling tree, whose worst misfire leaves a visible window floating in
# place, untiled and unharmed.
#
# A phantom tile is a window macOS has minimized but AeroSpace still tiles —
# its native-minimize detection can stall for minutes on Tahoe (#1615), so the
# minimized window keeps its slot and the on-screen gap IS that invisible tile.
# `macos-native-minimize` cannot resync (its unminimize branch is
# unimplemented upstream), so the heal is `layout floating --window-id`: the
# slot collapses, siblings retile, the window stays minimized in the Dock and
# floats when later restored. Candidates are the TILED windows of visible
# workspaces, gated on two more independent signals: absent from the window
# server's on-screen list AND AX kAXMinimizedAttribute true (window-oracle.swift,
# same dir; errs toward inaction by design). Every float is logged to
# ~/.cache/aerospace/reap.log.
#
# The `list-windows --all` snapshot doubles as the retile poke on every focus
# change (aerospace.toml registers no bare poke beside it), and
# %{workspace-is-visible} filters the candidates out of that same answer
# rather than a second call, since each call cancels the daemon's heavy
# refresh (docs/aerospace/RETILE-DELAY.md § Root cause).
#
# The window-oracle binary compiles on demand through swift-lib.sh. Absolute
# paths throughout, so the script behaves the same from an AeroSpace callback,
# a Karabiner shell_command (via retry-poke.sh), and a terminal, whose PATHs
# differ.
set -euo pipefail

AS=/opt/homebrew/bin/aerospace
LOG="${XDG_CACHE_HOME:-$HOME/.cache}/aerospace/reap.log"

. "$(dirname "${BASH_SOURCE[0]}")/swift-lib.sh"
ensure_swift_bin window-oracle || exit 0

# Past 1MB keep the last 2000 lines.
if [ -f "$LOG" ] && [ "$(/usr/bin/stat -f%z "$LOG")" -gt 1048576 ]; then
  /usr/bin/tail -n 2000 "$LOG" > "$LOG.tmp" && /bin/mv -f "$LOG.tmp" "$LOG"
fi

tiled=$("$AS" list-windows --all --format '%{window-id} %{window-layout} %{workspace-is-visible}' 2>/dev/null \
        | /usr/bin/awk '$3 == "true" && $2 != "floating" { print $1 }' | tr '\n' ' ') || exit 0
[ -n "$tiled" ] || exit 0

phantoms=$("$SWIFT_BIN" $tiled 2>/dev/null) || exit 0
[ -n "$phantoms" ] || exit 0

meta=$("$AS" list-windows --all --format '%{window-id} %{app-name} [%{window-title}] ws=%{workspace}' 2>/dev/null) || true
for id in $phantoms; do
  "$AS" layout floating --window-id "$id" 2>/dev/null || true
  printf '%s PHANTOM floated %s\n' "$(date '+%Y-%m-%dT%H:%M:%S')" \
    "$(printf '%s\n' "$meta" | grep "^$id " || printf '%s (no metadata)' "$id")" >> "$LOG"
done
