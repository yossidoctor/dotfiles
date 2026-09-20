#!/usr/bin/env bash
# Idempotent LaunchAgent install for the menu bar suppression — same shape as
# media-stream-agent.sh.
#
# WHY THIS EXISTS SEPARATELY FROM SKETCHYBAR
#
# menubar-hide sets an alpha in the window server and nothing on disk holds it,
# so macOS drops it on reboot, logout, sleep/wake, Mission Control exit and any
# display change. sketchybar's own menubar.keeper item re-applies it, but only
# while sketchybar is running and only on the four events it subscribes to — a
# sketchybar process that has been up for days has not re-run its startup apply,
# and any reset it did not receive an event for leaves the native menu bar
# visible behind the bar. That is the "bar looks blurred and unclear" symptom:
# the real menu bar showing through.
#
# StartInterval makes the suppression unconditional instead: it re-applies on a
# timer whether or not sketchybar is alive, so no missed event can strand it.
# The helper is a single SkyLight call that exits immediately, and re-applying
# an alpha that is already 0 is a no-op, so the cost of the poll is negligible.
#
# RunAtLoad covers login. The plist is generated here from $HOME rather than
# tracked, because a tracked plist would carry this machine's home path into the
# repo. An unchanged plist exits without touching launchd.
set -euo pipefail

label="dev.yossidoctor.sketchybar-menubar-keeper"
config_dir="$HOME/.config/sketchybar"
helper="$config_dir/menubar-hide"
plist_dst="$HOME/Library/LaunchAgents/$label.plist"

# The agent runs the binary directly, so it must exist before launchd loads the
# plist — sketchybarrc also builds it, but this install step can run first on a
# fresh machine, and an agent whose program is missing just fails every tick.
if [ ! -x "$helper" ] || [ "$helper.c" -nt "$helper" ]; then
  (cd "$config_dir" && make >/dev/null 2>&1) || true
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
		<string>$helper</string>
		<string>0.0</string>
	</array>
	<key>RunAtLoad</key>
	<true/>
	<key>StartInterval</key>
	<integer>5</integer>
	<key>StandardOutPath</key>
	<string>/dev/null</string>
	<key>StandardErrorPath</key>
	<string>/dev/null</string>
</dict>
</plist>
EOF
)

if [ -e "$plist_dst" ] && [ "$(cat "$plist_dst")" = "$plist_new" ]; then
  exit 0
fi

mkdir -p "$HOME/Library/LaunchAgents"
launchctl unload "$plist_dst" >/dev/null 2>&1 || true
printf '%s\n' "$plist_new" > "$plist_dst"
launchctl load "$plist_dst"
