#!/bin/bash
# PreToolUse Read hook: a spilled tool output is read in slices, never whole.
#
# Why: a tool result too large for the transcript is saved under
# ~/.claude/projects/<project>/<session>/tool-results/, and a whole Read of it
# puts the full output back into context, where every later turn re-reads it
# (40-53k-character reads of these files measured in 360 Planning sessions).
# A search (rg, jq) or a slice carries the part the question needs.
#
# DENIED: a Read whose file_path sits under ~/.claude/projects/*/tool-results/
# with neither offset nor limit set.
# PASSED: any Read carrying offset or limit, and every other path.

set -u

. "$(dirname "${BASH_SOURCE[0]}")/hook-lib.sh"

hook_read_raw
case "$HOOK_INPUT" in
  */tool-results/*) ;;
  *) exit 0 ;;
esac
file=$(printf '%s' "$HOOK_INPUT" | jq -r '.tool_input | select(.offset == null and .limit == null) | .file_path // empty' 2>/dev/null)
case "$file" in
  "$HOME"/.claude/projects/*/tool-results/*) ;;
  *) exit 0 ;;
esac

deny "${file} is a spilled tool output, so it is searched (rg or jq over it in Bash) or read in a slice (Read with offset/limit), never whole: a whole read puts the full output back into context, and every later turn re-reads it."
