#!/bin/bash
# PermissionDenied hook: append one JSON line per call a permission rule
# refused to ~/.cache/claude/permission-denied.jsonl — the tool, the command
# or path, the session and the time. Under bypass mode that is a `deny`
# pattern in settings.json; under auto mode the classifier's refusals too.
# Observation only: it emits no decision, so a refused call stays refused, and
# it is registered `async` so it never sits in the tool call's latency budget.
#
# The deny hooks under PreToolUse already leave their verdicts in the
# transcripts; a settings-rule refusal leaves nothing readable, and those are
# the rules that bite without a script behind them. This file is what a
# review of "which refusals recur" reads — it is how an over-broad deny
# pattern shows up. Rotation: past 1MB keep the last 2000 lines, the reap.log
# convention.

set -u

. "$(dirname "${BASH_SOURCE[0]}")/hook-lib.sh"

hook_read_raw
[ -n "$HOOK_INPUT" ] || exit 0

log="${XDG_CACHE_HOME:-$HOME/.cache}/claude/permission-denied.jsonl"
mkdir -p "${log%/*}"

if [ -f "$log" ] && [ "$(/usr/bin/stat -f%z "$log")" -gt 1048576 ]; then
  /usr/bin/tail -n 2000 "$log" > "$log.tmp" && /bin/mv -f "$log.tmp" "$log"
fi

printf '%s' "$HOOK_INPUT" | jq -c '{
  at: (now | todate),
  session: (.session_id // ""),
  tool: (.tool_name // ""),
  target: (.tool_input.command // .tool_input.file_path // .tool_input.pattern // ""),
  cwd: (.cwd // "")
}' >> "$log" 2>/dev/null
exit 0
