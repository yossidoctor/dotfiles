#!/bin/bash
# Idempotent LaunchAgent install — re-runnable on every ./install.
# Keeps `cswap auto` alive so account rotation survives logout/reboot rather
# than living in whatever terminal happened to start it. Skips entirely when
# claude-swap isn't installed: the uv tool install is the manifest step right
# before this one, so on a fresh machine it is present by the time this runs
# unless uv itself was missing.
# The plist is generated here from $HOME; `--model all` is the SoT for the
# rotation arguments (per-model weekly windows count alongside the account-wide
# 5h/7d ones). Per-tick stdout goes to /dev/null because cswap already writes
# every switch decision to its own 1MB-rotated ~/.claude-swap-backup/claude-swap.log;
# a second unrotated copy of a line-per-minute would grow without bound. Only
# stderr is kept (auto-stderr.log), so a crash-loop still leaves evidence.
set -euo pipefail

. "$(dirname "${BASH_SOURCE[0]}")/../mac/launchagent-lib.sh"

label="dev.yossidoctor.cswap-auto"
cswap="$HOME/.local/bin/cswap"
[ -x "$cswap" ] || exit 0

keys=$(cat <<EOF
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
EOF
)

install_launchagent "$label" "$keys"
