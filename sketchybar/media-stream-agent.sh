#!/usr/bin/env bash
# Idempotent LaunchAgent install for media-stream.sh — re-runnable on every
# ./install, same shape as aerospace/retile-on-quit-watcher.sh.
#
# KeepAlive is what restarts the stream: `media-control`'s adapter treats a
# non-zero exit as fatal and tells consumers not to reinvoke, so the restart
# decision belongs to launchd rather than a retry loop inside the script.
#
# RunAtLoad starts it at login without waiting for the first track change; the
# stream publishes current state on connect, so the pill is populated as soon as
# sketchybar is up.
#
# The plist is generated here from $HOME rather than tracked as a file, because a
# tracked plist would carry this machine's home path into the repo. An unchanged
# plist exits without touching launchd.
set -euo pipefail

label="dev.yossidoctor.sketchybar-media-stream"
script="$HOME/.config/sketchybar/media-stream.sh"
plist_dst="$HOME/Library/LaunchAgents/$label.plist"

plist_new=$(cat <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key>
	<string>$label</string>
	<key>ProgramArguments</key>
	<array>
		<string>/bin/bash</string>
		<string>$script</string>
	</array>
	<key>RunAtLoad</key>
	<true/>
	<key>KeepAlive</key>
	<true/>
	<key>ThrottleInterval</key>
	<integer>10</integer>
	<key>StandardOutPath</key>
	<string>/dev/null</string>
	<key>StandardErrorPath</key>
	<string>$HOME/Library/Logs/sketchybar-media-stream.log</string>
</dict>
</plist>
EOF
)

if [ -e "$plist_dst" ] && [ "$(cat "$plist_dst")" = "$plist_new" ]; then
  exit 0
fi

mkdir -p "$HOME/Library/LaunchAgents" "$HOME/Library/Logs"
launchctl unload "$plist_dst" >/dev/null 2>&1 || true
printf '%s\n' "$plist_new" > "$plist_dst"
launchctl load "$plist_dst"
