#!/bin/bash
# PreToolUse Bash hook: run every command with stdin from /dev/null, so a
# command that falls back to reading stdin gets end-of-input at once instead of
# blocking forever.
#
# The Bash tool hands its shell a stdin socket Claude Code holds open and never
# writes to, so `grep pattern $(cmd)` whose substitution came back empty reads
# that socket and never returns; at the tool's timeout the call is moved to the
# background rather than killed, and the shell outlives the turn — in a
# subagent, it keeps the agent listed as running after its report. No Bash
# command here reads stdin on purpose: a heredoc or pipe inside the command
# still feeds its own command, since an inner redirection wins over this one.
#
# The command is wrapped as `{ <command>\n} < /dev/null`; the newline before the
# brace keeps a trailing comment or heredoc terminator intact. The output sets
# no permissionDecision, so the normal permission flow and the sibling hooks'
# decisions apply unchanged.
. "$(dirname "$0")/hook-lib.sh"
hook_read_raw
case "$HOOK_INPUT" in *'} < /dev/null'*) exit 0 ;; esac  # already wrapped
hook_parse_input
[ -n "$HOOK_CMD" ] || exit 0

jq -c --arg c "{ $HOOK_CMD
} < /dev/null" \
  '{hookSpecificOutput: {hookEventName: "PreToolUse",
    updatedInput: (.tool_input + {command: $c})}}' <<<"$HOOK_INPUT"
