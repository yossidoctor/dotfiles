#!/bin/bash
# Idempotent LaunchAgent install — re-runnable on every ./install.
# Starts the sibling daily.sh once a day, at an hour the Mac is usually asleep,
# so the run fires on its next wake. The key is
# StartCalendarInterval because a slot that passes during sleep fires on the
# next wake, several missed slots coalescing into one run, while a slot that
# passes with the Mac off is dropped (launchd.plist(5); Apple's "Scheduling
# Timed Jobs"). StartInterval drops both. ProcessType Background has macOS
# throttle the run's CPU and I/O so it stays out of the way. Run it now with
# `launchctl kickstart gui/$(id -u)/<label>`.
#
# The job starts under zsh because launchd hands it the bare system PATH and
# zsh reads zshenv, the PATH SoT. Stdout is discarded since daily.sh logs each
# job itself; stderr is kept, so a launch that dies before a job starts still
# leaves evidence. The install itself is mac/launchagent-lib.sh.
set -euo pipefail

. "$(dirname "${BASH_SOURCE[0]}")/launchagent-lib.sh"

label="dev.yossidoctor.daily"
script="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/daily.sh"

plist_new=$(cat <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key>
	<string>$label</string>
	<key>ProgramArguments</key>
	<array>
		<string>/bin/zsh</string>
		<string>-c</string>
		<string>exec "$script"</string>
	</array>
	<key>StartCalendarInterval</key>
	<dict>
		<key>Hour</key>
		<integer>5</integer>
		<key>Minute</key>
		<integer>0</integer>
	</dict>
	<key>ProcessType</key>
	<string>Background</string>
	<key>StandardOutPath</key>
	<string>/dev/null</string>
	<key>StandardErrorPath</key>
	<string>$HOME/Library/Logs/daily-agent.log</string>
</dict>
</plist>
EOF
)

install_launchagent "$label" "$plist_new"
