#!/usr/bin/env bash
# Idempotent LaunchAgent install — re-runnable on every ./install.
# Keeps `cswap auto` alive so account rotation survives logout/reboot rather
# than living in whatever terminal happened to start it. Skips entirely when
# claude-swap isn't installed yet, since brew bundle and the uv tool install
# both run later in the same ./install pass on a fresh machine.
# Per-tick stdout goes to /dev/null because cswap already writes every switch
# decision to its own 1MB-rotated ~/.claude-swap-backup/claude-swap.log; a
# second unrotated copy of a line-per-minute would grow without bound. Only
# stderr is kept (auto-stderr.log), so a crash-loop still leaves evidence.
set -euo pipefail

label="dev.yossidoctor.cswap-auto"
plist_src="$HOME/.claude/cswap-auto.plist"
plist_dst="$HOME/Library/LaunchAgents/$label.plist"

[ -x "$HOME/.local/bin/cswap" ] || exit 0

mkdir -p "$HOME/Library/LaunchAgents"
if [ -e "$plist_dst" ] && cmp -s "$plist_src" "$plist_dst"; then
  exit 0
fi

launchctl unload "$plist_dst" >/dev/null 2>&1 || true
cp "$plist_src" "$plist_dst"
launchctl load "$plist_dst"
