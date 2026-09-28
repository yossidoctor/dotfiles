#!/bin/bash
# Idempotent LaunchAgent install — re-runnable on every ./install.
# Cmd+Q, Force Quit, Dock "Quit", menu-bar "Quit", and killall/pkill all end
# in the same NSWorkspace.didTerminateApplicationNotification regardless of
# how the app was told to quit, so a watcher on that single notification
# covers all of them at once. Mechanism and the callbacks it backstops:
# docs/aerospace/RETILE-DELAY.md.
#
# The watcher is compiled with swiftc into ~/.cache/aerospace/bin (through
# swift-lib.sh, the same compile the other helpers use) whenever the binary is
# missing or older than the source, so launchd runs a native process rather
# than a resident swift interpreter. The plist is generated here from $HOME and
# installed by mac/launchagent-lib.sh; a rebuilt binary or a changed plist
# reloads the agent, an unchanged pair exits without touching it.
set -euo pipefail

. "$(dirname "${BASH_SOURCE[0]}")/swift-lib.sh"
. "$(dirname "${BASH_SOURCE[0]}")/../mac/launchagent-lib.sh"

label="dev.yossidoctor.retile-on-quit-watcher"
SWIFT_REBUILT=0
ensure_swift_bin retile-on-quit-watcher || { echo "retile-on-quit-watcher.swift failed to compile" >&2; exit 1; }
bin="$SWIFT_BIN"

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

install_launchagent "$label" "$plist_new" "$SWIFT_REBUILT"
