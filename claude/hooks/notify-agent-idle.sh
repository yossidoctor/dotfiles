#!/bin/bash
# Notification hook: macOS banner when Claude needs input or a background
# subagent finishes — both are easy to miss once you've alt-tabbed away.
#
# The payload names the kind in `notification_type`; the settings.json matcher
# is a filter on the harness side and is never echoed into the input. Handled:
# agent_completed (a backgrounded Agent call finished) and idle_prompt (Claude
# is waiting on you). Every other type passes through silently — not every
# notification warrants an OS banner.
#
# The banner goes through terminal-notifier (brew/Brewfile): it ships as its
# own app bundle, so it appears in System Settings › Notifications and can be
# granted. `osascript display notification` attributes the banner to the
# calling terminal, which never registers there, and on macOS 26+ exits 0
# while showing nothing. It stays as the fallback until brew bundle has run.

set -u

. "$(dirname "${BASH_SOURCE[0]}")/hook-lib.sh"

hook_read_raw
case "$HOOK_INPUT" in
  *agent_completed*|*idle_prompt*) ;;
  *) exit 0 ;;
esac
hook_parse_input
message="${HOOK_MESSAGE:-Claude Code}"

case "$HOOK_NOTIFICATION_TYPE" in
  agent_completed) title="Claude — subagent done" ;;
  idle_prompt) title="Claude — needs input" ;;
  *) exit 0 ;;
esac

if command -v terminal-notifier >/dev/null; then
  terminal-notifier -title "$title" -message "$message" -group "claude-${HOOK_SESSION_ID:-default}" >/dev/null 2>&1
else
  jsonq() { printf '%s' "$1" | jq -R -s '.'; }
  osascript -e "display notification $(jsonq "$message") with title $(jsonq "$title")" >/dev/null 2>&1
fi
exit 0
