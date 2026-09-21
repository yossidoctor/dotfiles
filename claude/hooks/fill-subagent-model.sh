#!/bin/bash
# PreToolUse Agent hook: a subagent never launches as Fable.
#
# A non-fork dispatch that omits `model` or names `fable` is rewritten to
# `opus` through updatedInput (which REPLACES tool_input wholesale, so the
# original input is carried through with only that field overwritten). Forks
# inherit the parent by design and an explicitly named non-fable model is
# kept. An omission is filled only when no agent definition answers for it: a
# dispatch naming a type with a `<type>.md` on disk is deferring to that
# file's `model:` frontmatter, and filling the omission here would silently
# overwrite it. Backgrounding is the harness's own default for every
# subagent, so this hook leaves run_in_background alone.
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

# Does an agent definition answer for this dispatch's type? Its own `model:`
# owns the choice, so an omitted model is deferral to it, not a gap to fill.
# One `[ -f ]` per dispatch, against the roots agent definitions deploy to.
sub_type=$(printf '%s' "$HOOK_INPUT" | jq -r '.tool_input.subagent_type // ""')
has_def=false
case "$sub_type" in
  ""|*/*|.*) ;;
  *)
    dir=${CLAUDE_PROJECT_DIR:-${HOOK_CWD:-$PWD}}
    while [ -n "$dir" ] && [ "$dir" != / ]; do
      [ -f "$dir/.claude/agents/$sub_type.md" ] && { has_def=true; break; }
      dir=$(dirname "$dir")
    done
    [ -f "$HOME/.claude/agents/$sub_type.md" ] && has_def=true ;;
esac

printf '%s' "$HOOK_INPUT" | jq -c --argjson hasdef "$has_def" '
  (.tool_input // {}) as $ti
  | if ($ti.subagent_type != "fork")
       and ((($ti.model // "") == "fable") or ((($ti.model // "") == "") and ($hasdef | not)))
    then
      {hookSpecificOutput: {
        hookEventName: "PreToolUse",
        updatedInput: ($ti + {model: "opus"}),
        additionalContext: "Agent dispatch normalized by fill-subagent-model.sh: model=opus (a subagent never launches as Fable; name another non-fable model explicitly to override)."}}
    else empty end'

exit 0
