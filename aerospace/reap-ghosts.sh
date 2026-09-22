#!/bin/bash
# Ghost/phantom watchdog for AeroSpace's tiling tree. NEVER closes, kills,
# or minimizes a window — that is a hard invariant, not a phase: a
# close-based reaper misclassifying one live window kills real work (it
# closed live Ghostty windows carrying Claude sessions on 2026-07-29). The one
# action it may take is
# layout-class, the category the user explicitly allows: floating a window
# out of the tiling tree (see PHANTOM TILES below), whose worst possible
# misfire leaves a visible window floating in place, untiled and unharmed.
#
# GHOST CANDIDATES (observation only): on every focus/workspace event (and
# from retry-poke.sh), snapshot AeroSpace's tree and the macOS window
# server, and append one line to ~/.cache/aerospace/reap.log with both
# counts, the daemon's answer time, and any tree ids absent from the window
# server (upstream #1615). A daemon answer >=500ms also logs, tagged SLOW —
# the passive fingerprint of the maintainer-described GC hang (2026-07-29
# 13:09 episode: mis-tiled frames with a clean tree and a silent log were
# indistinguishable from a healthy run). Silence therefore means clean AND
# fast. Oracle-failure guard: if window-oracle crashes or returns fewer ids
# than the tree has windows, that is oracle failure, not mass window death —
# the line is tagged ORACLE-SUSPECT and nothing on it is trusted (the exact
# failure behind the incident: an empty oracle made every window look like
# a ghost). Read the log after running diagnose-gap.sh (alt-shift-d).
#
# PHANTOM TILES (auto-healed): a window macOS has minimized but AeroSpace
# still tiles — its native-minimize detection can stall for minutes on
# Tahoe (#1615), so the minimized window keeps its slot and the on-screen
# gap IS that invisible tile (caught live 2026-07-29 15:41, Firefox).
# `macos-native-minimize` cannot resync (its unminimize branch is
# unimplemented upstream), so the heal is `layout floating --window-id`:
# the slot collapses, siblings retile, the window stays minimized in the
# Dock and floats when later restored. Candidates are the TILED windows of
# visible workspaces — a floating window holds no slot, so it is never one,
# and a window this script floated is out of the candidate set from the
# next run on. Gated on three independent signals — tiled in a visible
# workspace, absent from the window server's on-screen list, AND AX
# kAXMinimizedAttribute true (window-oracle.swift, same dir; errs toward
# inaction by design) — and every float is logged, once per phantom.
#
# ONE snapshot, ONE oracle run. The daemon is asked once
# (`list-windows --all`) and %{workspace-is-visible} filters the tiled
# candidates out of that same answer, because a second `--workspace visible`
# call would cost another round trip — each cancels the heavy refresh
# (docs/aerospace/RETILE-DELAY.md § Root cause) — and would read a tree ~20ms
# younger than the ghost pass, letting a window that closed in between be
# judged against mismatched state. window-oracle likewise answers the ghost
# question (ALL) and the phantom question (PHANTOM) from a single
# window-server read, so the two verdicts cannot disagree about which windows
# existed at that instant.
#
# Helpers compile with swiftc to ~/.cache/aerospace/bin/ when missing or
# older than source — to a temp file first, atomically mv'd into place,
# because concurrent invocations (focus + workspace callbacks fire
# together) racing one shared output path can execute a half-written
# binary; that race on the first-ever compile is the leading explanation
# for the incident. Absolute paths throughout, so the script behaves the
# same from an AeroSpace callback, a Karabiner shell_command (via
# retry-poke.sh), and a terminal, whose PATHs differ.
set -euo pipefail

AS=/opt/homebrew/bin/aerospace
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/aerospace"
LOG="$CACHE/reap.log"

ensure_bin() {
  local src="$DIR/$1.swift" bin="$CACHE/bin/$1" tmp
  if [ ! -x "$bin" ] || [ "$src" -nt "$bin" ]; then
    mkdir -p "$CACHE/bin"
    tmp=$(mktemp "$CACHE/bin/.$1-XXXXXX")
    if xcrun swiftc -O -o "$tmp" "$src" >/dev/null 2>&1; then
      mv -f "$tmp" "$bin"
    else
      rm -f "$tmp"
      return 1
    fi
  fi
}

ensure_bin window-oracle || exit 0

# The log grows a line per candidate run for years; past 1MB keep the last
# 2000 lines, which is weeks of fingerprint at the observed rate.
if [ -f "$LOG" ] && [ "$(/usr/bin/stat -f%z "$LOG")" -gt 1048576 ]; then
  /usr/bin/tail -n 2000 "$LOG" > "$LOG.tmp" && /bin/mv -f "$LOG.tmp" "$LOG"
fi

t0=$(/usr/bin/perl -MTime::HiRes=time -e 'printf "%d", time()*1000')
snapshot=$("$AS" list-windows --all \
           --format '%{window-id} %{window-layout} %{workspace-is-visible}' 2>/dev/null)
dur=$(($(/usr/bin/perl -MTime::HiRes=time -e 'printf "%d", time()*1000') - t0))
tree=$(printf '%s\n' "$snapshot" | /usr/bin/awk 'NF { print $1 }' | sort -u)
[ -z "$tree" ] && exit 0

tiled=$(printf '%s\n' "$snapshot" | /usr/bin/awk '$3 == "true" && $2 != "floating" { print $1 }' | tr '\n' ' ')
oracle=$("$CACHE/bin/window-oracle" $tiled 2>/dev/null || true)
cg=$(printf '%s\n' "$oracle" | /usr/bin/awk '$1 == "ALL" { $1 = ""; print }' | tr ' ' '\n' | /usr/bin/awk 'NF' | sort -u)

tree_n=$(printf '%s\n' "$tree" | wc -l | tr -d ' ')
cg_n=0
[ -n "$cg" ] && cg_n=$(printf '%s\n' "$cg" | wc -l | tr -d ' ')

candidates=""
[ -n "$cg" ] && candidates=$(comm -23 <(printf '%s\n' "$tree") <(printf '%s\n' "$cg"))

tag=ok
[ "$cg_n" -lt "$tree_n" ] && tag=ORACLE-SUSPECT
[ "$dur" -ge 500 ] && tag="SLOW-$tag"

if [ -n "$candidates" ] || [ "$tag" != ok ]; then
  printf '%s %s dur=%sms tree=%s cg=%s candidates=[%s]\n' \
    "$(date '+%Y-%m-%dT%H:%M:%S')" "$tag" "$dur" "$tree_n" "$cg_n" \
    "$(printf '%s' "$candidates" | tr '\n' ' ')" >> "$LOG"
fi

phantoms=$(printf '%s\n' "$oracle" | /usr/bin/awk '$1 == "PHANTOM" { $1 = ""; print }' | tr ' ' '\n' | /usr/bin/awk 'NF')
[ -z "$phantoms" ] && exit 0

meta=$("$AS" list-windows --all --format '%{window-id} %{app-name} [%{window-title}] ws=%{workspace}' 2>/dev/null)
while IFS= read -r id; do
  [ -n "$id" ] || continue
  "$AS" layout floating --window-id "$id" 2>/dev/null || true
  printf '%s PHANTOM floated %s\n' "$(date '+%Y-%m-%dT%H:%M:%S')" \
    "$(printf '%s\n' "$meta" | grep "^$id " || printf '%s (no metadata)' "$id")" >> "$LOG"
done <<< "$phantoms"
