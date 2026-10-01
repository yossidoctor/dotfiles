#!/bin/bash
# PreToolUse Agent hook: a dispatch naming `model: "fable"` is rewritten to
# `opus` through updatedInput (which REPLACES tool_input wholesale, so the
# original input is carried through with only that field overwritten).
#
# An omitted model is not this hook's case: settings.json `env` sets
# CLAUDE_CODE_SUBAGENT_MODEL=opus, which the harness applies when neither the
# dispatch nor the agent definition names a model. An agent definition's own
# `model:` still wins over both. A fork ignores the field, so rewriting one is
# harmless. Silent when nothing needs changing.

set -u

. "$(dirname "${BASH_SOURCE[0]}")/hook-lib.sh"

hook_read_raw
case "$HOOK_INPUT" in
  *'"fable"'*) ;;
  *) exit 0 ;;
esac

printf '%s' "$HOOK_INPUT" | jq -c '
  if .tool_name == "Agent" and .tool_input.model == "fable" then
    {hookSpecificOutput: {
      hookEventName: "PreToolUse",
      updatedInput: (.tool_input + {model: "opus"}),
      additionalContext: "Agent dispatch rewritten by rewrite-fable-subagent.sh: model=opus (a subagent never launches as Fable)."}}
  else empty end'
exit 0
