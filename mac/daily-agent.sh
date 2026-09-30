#!/bin/bash
# Idempotent LaunchAgent install — re-runnable on every ./install.
# Starts the sibling daily.sh once a day at $hour:00 — the one scheduled run
# and the one scheduled wake of the day. The key is StartCalendarInterval
# because a slot that passes during sleep fires on the next wake, several
# missed slots coalescing into one run, while a slot that passes with the Mac
# off is dropped (launchd.plist(5); Apple's "Scheduling Timed Jobs").
# StartInterval drops both. ProcessType Background has macOS throttle the
# run's CPU and I/O so it stays out of the way. Run it now with
# `launchctl kickstart gui/$(id -u)/<label>`.
#
# The Mac is woken daily at $hour:01 by `pmset repeat`, which holds one
# repeating wake and replaces whatever repeating event was set before. After
# the slot, not before: with the lid closed that wake lasts seconds, and
# launchd fires the already-passed slot inside it, where a wake before the
# slot would be asleep again when the slot came. daily.sh then holds the Mac
# awake with `pmset disablesleep`, which a sudoers.d rule lets it run without a
# password for exactly its two arguments. Both need sudo, so each runs only
# when its state is missing, and a refused sudo leaves the rest of the install
# intact.
#
# The job starts under zsh because launchd hands it the bare system PATH and
# zsh reads zshenv, the PATH SoT. Stdout is discarded since daily.sh logs each
# job itself; stderr is kept, so a launch that dies before a job starts still
# leaves evidence. The install itself is mac/launchagent-lib.sh.
set -euo pipefail

. "$(dirname "${BASH_SOURCE[0]}")/launchagent-lib.sh"

label="dev.yossidoctor.daily"
script="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/daily.sh"
hour=7
sudoers=/etc/sudoers.d/daily-disablesleep

wake_shown="$(( (hour + 11) % 12 + 1 )):01$( [ "$hour" -lt 12 ] && echo AM || echo PM )"
[[ "$(pmset -g sched)" == *"wakepoweron at $wake_shown every day"* ]] \
    || sudo pmset repeat wakeorpoweron MTWRFSU "$(printf '%02d:01:00' "$hour")" \
    || true

if [ ! -e "$sudoers" ]; then
    rule=$(mktemp)
    echo "$(id -un) ALL=(root) NOPASSWD: /usr/bin/pmset disablesleep 0, /usr/bin/pmset disablesleep 1" >"$rule"
    { sudo visudo -cqf "$rule" && sudo install -m 0440 -o root -g wheel "$rule" "$sudoers"; } || true
    rm -f "$rule"
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
		<string>/bin/zsh</string>
		<string>-c</string>
		<string>exec "$script"</string>
	</array>
	<key>StartCalendarInterval</key>
	<dict>
		<key>Hour</key>
		<integer>$hour</integer>
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
