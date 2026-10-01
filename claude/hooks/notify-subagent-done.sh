#!/bin/bash
# Notification hook: macOS banner when a background subagent finishes — easy
# to miss once you've alt-tabbed away, and the one event Claude Code's own
# notifier does not cover. "Waiting for input" and turn-complete banners are
# Claude Code's own, through preferredNotifChannel in settings.json, and carry
# the session title; a second banner from here would only double them.
#
# The payload names the kind in `notification_type`; the settings.json matcher
# is a filter on the harness side and is never echoed into the input. Handled:
# agent_completed (a backgrounded Agent call finished). Every other type passes
# through silently.
#
# The banner goes through terminal-notifier (brew/Brewfile): it ships as its
# own app bundle, so it appears in System Settings › Notifications and can be
# granted. `osascript display notification` attributes the banner to the
# calling terminal, which never registers there, and on macOS 26+ exits 0
# while showing nothing. ./install runs brew bundle before it links this hook.

set -u

. "$(dirname "${BASH_SOURCE[0]}")/hook-lib.sh"

hook_read_raw
case "$HOOK_INPUT" in
  *agent_completed*) ;;
  *) exit 0 ;;
esac
hook_parse_input
[ "$HOOK_NOTIFICATION_TYPE" = agent_completed ] || exit 0
message="${HOOK_MESSAGE:-Claude Code}"
title="Claude — subagent done"

terminal-notifier -title "$title" -message "$message" -group "claude-${HOOK_SESSION_ID:-default}" >/dev/null 2>&1
exit 0
