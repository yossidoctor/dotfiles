#!/bin/bash
# Keep AeroSpace's fake-fullscreen window on top while it's focused.
#
# AeroSpace `fullscreen` only resizes (layout pass = frames only, zero
# z-order management anywhere in its source; the sole raise lives in its
# focus-change path), so a fullscreen window buried by any sibling raise —
# Tahoe's WindowServer does unrequested reorders — stays buried and the
# tiled windows render in front of it. This script re-asserts the natural
# invariant: if the FOCUSED window is fullscreen, it belongs on top. Wired
# to (1) the Hyper+f binding in aerospace.toml, right after the `fullscreen`
# toggle, and (2) on-focus-changed, so any focus event while a fullscreen
# window is focused restores it. No-op whenever the focused window isn't
# fullscreen — focusing a floating window over a still-fullscreen one stays
# possible, and AeroSpace itself exits fullscreen when another tiling
# window in the workspace takes focus (documented upstream design, #422).
#
# Raise/activate only, via raise-window (same dir) — never closes, kills,
# or minimizes (2026-07-29 incident invariant, docs/aerospace/RETILE-DELAY.md). Activation
# targets the app already owning keyboard focus, so no focus theft.
# Compile-on-demand mirrors reap-ghosts.sh: temp file + atomic mv (see its
# header for the half-written-binary race this prevents). Absolute paths
# throughout, so the script behaves the same from an AeroSpace callback
# and a terminal, whose PATHs differ.
set -euo pipefail

AS=/opt/homebrew/bin/aerospace
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$DIR/raise-window.swift"
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/aerospace"
BIN="$CACHE/bin/raise-window"

if [ ! -x "$BIN" ] || [ "$SRC" -nt "$BIN" ]; then
  mkdir -p "$CACHE/bin"
  tmp=$(mktemp "$CACHE/bin/.rw-XXXXXX")
  if xcrun swiftc -O -o "$tmp" "$SRC" >/dev/null 2>&1; then
    mv -f "$tmp" "$BIN"
  else
    rm -f "$tmp"
    exit 0
  fi
fi

read -r id fs < <("$AS" list-windows --focused --format '%{window-id} %{window-is-fullscreen}' 2>/dev/null) || exit 0
[ "${fs:-false}" = "true" ] || exit 0
"$BIN" "$id" 2>>"$CACHE/raise.log" || true
