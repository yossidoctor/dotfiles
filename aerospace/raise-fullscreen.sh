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
# targets the app already owning keyboard focus, so no focus theft. The
# binary compiles on demand through swift-lib.sh. Absolute paths throughout,
# so the script behaves the same from an AeroSpace callback and a terminal,
# whose PATHs differ.
set -euo pipefail

AS=/opt/homebrew/bin/aerospace
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/aerospace"

. "$(dirname "${BASH_SOURCE[0]}")/swift-lib.sh"
ensure_swift_bin raise-window || exit 0

read -r id fs < <("$AS" list-windows --focused --format '%{window-id} %{window-is-fullscreen}' 2>/dev/null) || exit 0
[ "${fs:-false}" = "true" ] || exit 0
"$SWIFT_BIN" "$id" 2>>"$CACHE/raise.log" || true
