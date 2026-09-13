#!/usr/bin/env bash
# Idempotent LaunchAgent install — re-runnable on every ./install.
# Cmd+Q, Force Quit, Dock "Quit", menu-bar "Quit", and killall/pkill all end
# in the same NSWorkspace.didTerminateApplicationNotification regardless of
# how the app was told to quit, so a watcher on that single notification
# covers all of them at once. Mechanism and the callbacks it backstops:
# docs/aerospace/RETILE-DELAY.md.
#
# The watcher is compiled with swiftc into ~/.cache/aerospace/bin (the same
# cache the other helpers use) whenever the binary is missing or older than
# the source, so launchd runs a native process rather than a resident swift
# interpreter. The plist is generated here from $HOME; a rebuilt binary or a
# changed plist reloads the agent, an unchanged pair exits without touching it.
set -euo pipefail

label="dev.yossidoctor.retile-on-quit-watcher"
src="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/retile-on-quit-watcher.swift"
cache="${XDG_CACHE_HOME:-$HOME/.cache}/aerospace"
bin="$cache/bin/retile-on-quit-watcher"
plist_dst="$HOME/Library/LaunchAgents/$label.plist"

rebuilt=0
if [ ! -x "$bin" ] || [ "$src" -nt "$bin" ]; then
  mkdir -p "$cache/bin"
  tmp=$(mktemp "$cache/bin/.retile-on-quit-watcher-XXXXXX")
  xcrun swiftc -O -o "$tmp" "$src"
  mv -f "$tmp" "$bin"
  rebuilt=1
fi

plist_new=$(cat <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key>
	<string>$label</string>
	<key>ProgramArguments</key>
	<array>
		<string>$bin</string>
	</array>
	<key>RunAtLoad</key>
	<true/>
	<key>KeepAlive</key>
	<true/>
	<key>StandardOutPath</key>
	<string>/dev/null</string>
	<key>StandardErrorPath</key>
	<string>/dev/null</string>
</dict>
</plist>
EOF
)

if [ "$rebuilt" = 0 ] && [ -e "$plist_dst" ] && [ "$(cat "$plist_dst")" = "$plist_new" ]; then
  exit 0
fi

mkdir -p "$HOME/Library/LaunchAgents"
launchctl unload "$plist_dst" >/dev/null 2>&1 || true
printf '%s\n' "$plist_new" > "$plist_dst"
launchctl load "$plist_dst"
