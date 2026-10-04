#!/bin/bash
# Poke AeroSpace twice (now and at 200ms) after a Cmd+W/Cmd+Q keystroke.
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
# Karabiner fires this on the Cmd+W/Cmd+Q keystroke itself, which makes it
# the one trigger that still works when closing the last window leaves no
# other window to receive focus: no focus event fires in that state, so
# Hammerspoon's focus-driven poke (hammerspoon/init.lua) never runs.
AS=/opt/homebrew/bin/aerospace
"$AS" list-windows --all >/dev/null 2>&1
sleep 0.2
"$AS" list-windows --all >/dev/null 2>&1
