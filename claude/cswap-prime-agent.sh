#!/bin/bash
# Idempotent LaunchAgent install — re-runnable on every ./install.
# Starts the sibling cswap-prime.sh at each hour in $slot_hours; the hours are
# the SoT for the priming schedule. 07:00 opens every account's first 5h
# window; 12:00 and 17:00 re-open it at each reset, so the windows stay on
# 07–12, 12–17 and 17–22 whenever the first work message of a window arrives.
# StartCalendarInterval fires a slot that passed during sleep on the next wake
# (launchd.plist(5)); the primer's reset check makes such a late run harmless.
# Skips entirely when claude-swap isn't installed, as cswap-auto.sh does.
#
# The Mac is woken daily one minute after the first slot by `pmset repeat`,
# which holds one repeating wake and replaces whatever repeating event was set
# before. After, not before: with the lid closed that wake lasts about 15 s,
# and launchd fires the already-passed slot inside it, where a wake before the
# slot would be asleep again when the slot came. It needs sudo, so it runs
# only when `pmset -g sched` lacks that exact wake, and a refused sudo leaves
# the rest of the install intact.
#
# The job starts under zsh because launchd hands it the bare system PATH and
# zsh reads zshenv, the PATH SoT. It runs in an empty $workdir so claude starts
# with no project around it to read and no other app's data under ~/Library in
# its tree. Stdout is discarded since the primer writes
# its own log; stderr is kept. The install itself is mac/launchagent-lib.sh.
set -euo pipefail

. "$(dirname "${BASH_SOURCE[0]}")/../mac/launchagent-lib.sh"

label="dev.yossidoctor.cswap-prime"
slot_hours="7 12 17"
script="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/cswap-prime.sh"
workdir="$HOME/.cache/cswap-prime"
[ -x "$HOME/.local/bin/cswap" ] || exit 0
mkdir -p "$workdir"

wake_hour=${slot_hours%% *}
wake_shown="$(( (wake_hour + 11) % 12 + 1 )):01$( [ "$wake_hour" -lt 12 ] && echo AM || echo PM )"
schedule=$(pmset -g sched)
[[ "$schedule" == *"wakepoweron at $wake_shown every day"* ]] \
    || sudo pmset repeat wakeorpoweron MTWRFSU "$(printf '%02d:01:00' "$wake_hour")" \
    || true

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
	<key>WorkingDirectory</key>
	<string>$workdir</string>
	<key>StartCalendarInterval</key>
	<array>$slots
	</array>
	<key>StandardOutPath</key>
	<string>/dev/null</string>
	<key>StandardErrorPath</key>
	<string>$HOME/Library/Logs/cswap-prime-agent.log</string>
</dict>
</plist>
EOF
)

install_launchagent "$label" "$plist_new"
