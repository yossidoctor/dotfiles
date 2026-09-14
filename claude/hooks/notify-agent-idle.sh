#!/usr/bin/env bash
# Notification hook: macOS banner when Claude needs input or a background
# subagent finishes — both are easy to miss once you've alt-tabbed away,
# unlike the ghostty in-terminal channel (preferredNotifChannel) which only
# reaches you while that terminal is visible.
#
# Matchers: agent_completed (a backgrounded Agent call finished) and
# idle_prompt (Claude is waiting on you). Other Notification matchers pass
# through silently — not every notification warrants an OS banner.

set -u

. "$(dirname "${BASH_SOURCE[0]}")/hook-lib.sh"

hook_read_input
matcher="$HOOK_MATCHER"
message="${HOOK_MESSAGE:-Claude Code}"

case "$matcher" in
  agent_completed) title="Claude — subagent done" ;;
  idle_prompt) title="Claude — needs input" ;;
  *) exit 0 ;;
esac

jsonq() { printf '%s' "$1" | jq -R -s '.'; }
osascript -e "display notification $(jsonq "$message") with title $(jsonq "$title")" >/dev/null 2>&1
exit 0
