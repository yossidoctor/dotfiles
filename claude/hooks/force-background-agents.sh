#!/usr/bin/env bash
# PreToolUse Agent hook: normalize every subagent dispatch.
#
# Two rewrites ride one updatedInput (it REPLACES tool_input wholesale, not a
# merge, so the original input is carried through with only these fields
# overwritten):
#   - run_in_background=true — a subagent never blocks the main conversation.
#   - model=opus when a non-fork dispatch omits `model` or names `fable` — a
#     subagent never launches as Fable. Forks inherit the parent by design and
#     an explicitly named non-fable model is kept.
# Idempotent: silent when nothing needs changing.

set -u

. "$(dirname "${BASH_SOURCE[0]}")/hook-lib.sh"

hook_read_raw
case "$HOOK_INPUT" in
  *'"Agent"'*) ;;
  *) exit 0 ;;
esac
hook_parse_input
[ "$HOOK_TOOL_NAME" = "Agent" ] || exit 0

printf '%s' "$HOOK_INPUT" | jq -c '
  (.tool_input // {}) as $ti
  | ($ti.run_in_background != true) as $bg
  | (($ti.subagent_type != "fork") and (($ti.model // "") | IN("", "fable"))) as $md
  | if ($bg or $md) then
      {hookSpecificOutput: {
        hookEventName: "PreToolUse",
        updatedInput: ($ti
          + (if $bg then {run_in_background: true} else {} end)
          + (if $md then {model: "opus"} else {} end)),
        additionalContext: ("Agent dispatch normalized by force-background-agents.sh: "
          + ([ (if $bg then "run_in_background=true (the main thread never blocks on a subagent)" else empty end),
               (if $md then "model=opus (a subagent never launches as Fable; name another non-fable model explicitly to override)" else empty end)
             ] | join("; "))
          + ". Continue with other work; a completion notification arrives when it finishes.")}}
    else empty end'

exit 0
