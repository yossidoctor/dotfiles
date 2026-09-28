#!/bin/bash
# swift-lib.sh — ensure_swift_bin <name>: compile <this dir>/<name>.swift into
# ~/.cache/aerospace/bin/<name> when the binary is missing or older than its
# source. Sourced by reap-ghosts.sh, raise-fullscreen.sh, diagnose-gap.sh and
# retile-on-quit-watcher.sh; not run.
#
# The compile writes a temp file and mv's it into place atomically: concurrent
# invocations (the focus and workspace callbacks fire together) racing one
# shared output path can execute a half-written binary, which is the leading
# explanation for the 2026-07-29 incident (docs/aerospace/RETILE-DELAY.md).
# Returns 1 on a failed compile, with the partial file removed; the caller
# decides whether that is fatal. Sets SWIFT_BIN to the binary's path and
# SWIFT_REBUILT=1 when this call compiled it. Absolute paths throughout, so it
# behaves the same from an AeroSpace callback, a LaunchAgent and a terminal.

ensure_swift_bin() {
  local name="$1" dir cache src bin tmp
  dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  cache="${XDG_CACHE_HOME:-$HOME/.cache}/aerospace"
  src="$dir/$name.swift"; bin="$cache/bin/$name"
  SWIFT_BIN="$bin"
  [ ! -x "$bin" ] || [ "$src" -nt "$bin" ] || return 0
  mkdir -p "$cache/bin"
  tmp=$(mktemp "$cache/bin/.$name-XXXXXX")
  if xcrun swiftc -O -o "$tmp" "$src" >/dev/null 2>&1; then
    mv -f "$tmp" "$bin"
    SWIFT_REBUILT=1
  else
    rm -f "$tmp"
    return 1
  fi
}
