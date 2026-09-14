#!/usr/bin/env bash
# Idempotent LaunchAgent install — re-runnable on every ./install.
# Keeps `cswap auto` alive so account rotation survives logout/reboot rather
# than living in whatever terminal happened to start it. Skips entirely when
# claude-swap isn't installed yet, since the uv tool install runs later in the
# same ./install pass on a fresh machine.
# The plist is generated here from $HOME; `--model all` is the SoT for the
# rotation arguments (per-model weekly windows count alongside the account-wide
# 5h/7d ones). Per-tick stdout goes to /dev/null because cswap already writes
# every switch decision to its own 1MB-rotated ~/.claude-swap-backup/claude-swap.log;
# a second unrotated copy of a line-per-minute would grow without bound. Only
# stderr is kept (auto-stderr.log), so a crash-loop still leaves evidence.
set -euo pipefail

label="dev.yossidoctor.cswap-auto"
cswap="$HOME/.local/bin/cswap"
plist_dst="$HOME/Library/LaunchAgents/$label.plist"

[ -x "$cswap" ] || exit 0

plist_new=$(cat <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key>
	<string>$label</string>
	<key>ProgramArguments</key>
	<array>
		<string>$cswap</string>
		<string>auto</string>
		<string>--model</string>
		<string>all</string>
	</array>
	<key>RunAtLoad</key>
	<true/>
	<key>KeepAlive</key>
	<true/>
	<key>ThrottleInterval</key>
	<integer>60</integer>
	<key>StandardOutPath</key>
	<string>/dev/null</string>
	<key>StandardErrorPath</key>
	<string>$HOME/.claude-swap-backup/auto-stderr.log</string>
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
