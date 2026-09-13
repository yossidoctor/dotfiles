#!/usr/bin/env bash
# Poke AeroSpace twice (now and at 200ms) after a Cmd+W/Cmd+Q keystroke,
# then run the ghost/phantom watchdog.
#
# Every aerospace CLI call is a light refresh session in the daemon: it
# forces the pending frame relayout (the stale-layout half of
# docs/aerospace/RETILE-DELAY.md) and CANCELS the in-flight heavy refresh — the
# pass that garbage-collects closed windows and detects native minimize
# (refresh.swift: runLightSession cancels activeRefreshTask, then
# reschedules it). Two pokes cover both orderings — the first can land while
# the closing window is still in the tree, the second lands after macOS has
# torn it down — and each further poke only pushes the heavy pass out. A
# poke landing inside a multi-second daemon stall is wasted regardless.
#
# Ends by running reap-ghosts.sh: Karabiner fires this script on the Cmd+W/
# Cmd+Q keystroke itself, which makes it the one trigger that still works
# when closing the last window leaves no other window to receive focus — no
# focus-change or workspace-change event ever fires in that state, so the
# callback-wired reaper would otherwise never run.
AS=/opt/homebrew/bin/aerospace
"$AS" list-windows --all >/dev/null 2>&1
sleep 0.2
"$AS" list-windows --all >/dev/null 2>&1
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/reap-ghosts.sh" >/dev/null 2>&1 || true
