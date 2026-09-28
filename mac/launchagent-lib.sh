#!/bin/bash
# launchagent-lib.sh — install_launchagent <label> <plist-xml> [force]: the
# idempotent LaunchAgent install every ./install agent step shares. Sourced by
# claude/cswap-auto.sh, mac/daily-agent.sh and aerospace/retile-on-quit-watcher.sh;
# not run.
#
# Writes ~/Library/LaunchAgents/<label>.plist and bootstraps it. An unchanged
# plist exits without touching launchd unless <force> is 1 (a caller whose
# binary was rebuilt passes it, since the plist names the binary and launchd
# holds the old one). bootout returns before launchd has torn the job down, and
# a bootstrap that lands inside that window fails with "Input/output error"; a
# second try a moment later succeeds, hence the retries.

install_launchagent() {
  local label="$1" plist_new="$2" force="${3:-0}"
  local plist_dst="$HOME/Library/LaunchAgents/$label.plist"
  if [ "$force" = 0 ] && [ -e "$plist_dst" ] && [ "$(cat "$plist_dst")" = "$plist_new" ]; then
    return 0
  fi
  mkdir -p "$HOME/Library/LaunchAgents"
  launchctl bootout "gui/$(id -u)/$label" >/dev/null 2>&1 || true
  printf '%s\n' "$plist_new" > "$plist_dst"
  for _ in 1 2 3 4 5; do
    launchctl bootstrap "gui/$(id -u)" "$plist_dst" 2>/dev/null && return 0
    sleep 1
  done
  launchctl bootstrap "gui/$(id -u)" "$plist_dst"
}
