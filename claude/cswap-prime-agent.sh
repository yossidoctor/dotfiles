#!/bin/bash
# Idempotent LaunchAgent install — re-runnable on every ./install.
# Starts the sibling cswap-prime.sh at each hour in $slot_hours: 12:00 and
# 17:00 re-open every account's 5h window at each reset. The 07:00 slot that
# opens the first window is the daily run (mac/daily-agent.sh owns its hour
# and the day's one wake), so the windows stay on 07–12, 12–17 and 17–22
# whenever the first work message of a window arrives. StartCalendarInterval
# fires a slot that passed during sleep on the next wake (launchd.plist(5));
# the primer's reset check makes such a late run harmless. Skips entirely when
# claude-swap isn't installed, as cswap-auto.sh does.
#
# The job starts under zsh because launchd hands it the bare system PATH and
# zsh reads zshenv, the PATH SoT. Stdout is discarded since the primer writes
# its own log; stderr is kept. The install itself is mac/launchagent-lib.sh.
set -euo pipefail

. "$(dirname "${BASH_SOURCE[0]}")/../mac/launchagent-lib.sh"

label="dev.yossidoctor.cswap-prime"
slot_hours="12 17"
script="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/cswap-prime.sh"
[ -x "$HOME/.local/bin/cswap" ] || exit 0

slots=""
for hour in $slot_hours; do
    slots="$slots
		<dict>
			<key>Hour</key>
			<integer>$hour</integer>
			<key>Minute</key>
			<integer>0</integer>
		</dict>"
done

keys=$(cat <<EOF
	<key>ProgramArguments</key>
	<array>
		<string>/bin/zsh</string>
		<string>-c</string>
		<string>exec "$script"</string>
	</array>
	<key>StartCalendarInterval</key>
	<array>$slots
	</array>
	<key>StandardOutPath</key>
	<string>/dev/null</string>
	<key>StandardErrorPath</key>
	<string>$HOME/Library/Logs/cswap-prime-agent.log</string>
EOF
)

install_launchagent "$label" "$keys"
