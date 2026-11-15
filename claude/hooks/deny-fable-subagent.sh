#!/bin/bash
# PreToolUse Agent hook: no subagent runs on Fable.
#
# Inherited models are steered off Fable by CLAUDE_CODE_SUBAGENT_MODEL in
# settings.json, which leaves two paths this hook closes:
#   - DENIED: an explicit `model: "fable"` on the call.
#   - DENIED: a fork while the main session is on Fable — a fork always runs on
#     the parent's model and ignores `model`. The parent's model is the last
#     main-chain assistant message in the transcript.
# An agent file whose frontmatter names fable is not visible here.
. "$(dirname "$0")/hook-lib.sh"
hook_read_raw
case "$HOOK_INPUT" in *fable*|*'"fork"'*) ;; *) exit 0 ;; esac

model=$(jq -r '.tool_input.model // ""' <<<"$HOOK_INPUT")
case "$model" in *fable*) deny "Fable subagents are disabled. Omit model (defaults to opus) or pick opus, sonnet or haiku." ;; esac

[ "$(jq -r '.tool_input.subagent_type // ""' <<<"$HOOK_INPUT")" = fork ] || exit 0
transcript=$(jq -r '.transcript_path // ""' <<<"$HOOK_INPUT")
[ -f "$transcript" ] || exit 0
main_model=$(tail -r "$transcript" | jq -r 'select(.type == "assistant" and (.isSidechain | not)) | .message.model // empty' 2>/dev/null | head -1)
case "$main_model" in *fable*) deny "This session runs on Fable and a fork inherits it. Use a fresh agent (e.g. subagent_type general-purpose) instead of a fork." ;; esac
exit 0
