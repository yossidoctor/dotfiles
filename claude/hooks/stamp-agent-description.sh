#!/bin/bash
# PreToolUse Agent hook: prefix the call's description with the model and
# effort the agent runs on — `operator-service · sonnet high` — so the agent
# rows under the prompt, which show only the agent type and the description,
# name both.
#
# Model:  the call's `model` → the agent definition's `model:` →
#         $CLAUDE_CODE_SUBAGENT_MODEL for general-purpose and claude, which
#         have no definition file. Effort: the call's `effort` → the
#         definition's `effort:`. A value none of these names is left out.
# Definitions are read from <cwd>/.claude/agents, ~/Dono/.claude/agents and
# ~/.claude/agents, first match wins; plugin agents are not read.
# Skipped: a fork (it runs on the parent's model and ignores `model`), a call
# whose description already opens with `[` (a re-dispatch), and a call where
# nothing is known.
. "$(dirname "$0")/hook-lib.sh"
hook_read_raw

eval "$(jq -r '
def s(v): (v // "") | if type == "string" then . else tostring end;
"type=" + (s(.tool_input.subagent_type) | @sh),
"model=" + (s(.tool_input.model) | @sh),
"effort=" + (s(.tool_input.effort) | @sh),
"desc=" + (s(.tool_input.description) | @sh),
"cwd=" + (s(.cwd) | @sh)
' <<<"$HOOK_INPUT" 2>/dev/null)"
: "${type=}" "${model=}" "${effort=}" "${desc=}" "${cwd=}"

[ "$type" = fork ] && exit 0
case "$desc" in *' · '*) exit 0 ;; esac

frontmatter() {  # $1=file $2=key -> the key's value in the leading --- block
  awk -v k="$2" 'NR==1 && $0!="---" {exit} NR>1 && $0=="---" {exit}
    NR>1 && index($0, k":")==1 {sub("^" k ":[ \t]*", ""); print; exit}' "$1"
}

def=
if [ -n "$type" ]; then
  for dir in "$cwd/.claude/agents" "$HOME/Dono/.claude/agents" "$HOME/.claude/agents"; do
    [ -f "$dir/$type.md" ] && { def=$dir/$type.md; break; }
  done
fi
if [ -n "$def" ]; then
  [ -z "$model" ] && model=$(frontmatter "$def" model)
  [ -z "$effort" ] && effort=$(frontmatter "$def" effort)
fi
case "${type:-general-purpose}" in
  general-purpose|claude) [ -z "$model" ] && model=${CLAUDE_CODE_SUBAGENT_MODEL:-} ;;
esac

case "$model" in
  *opus*) model=opus ;; *sonnet*) model=sonnet ;; *haiku*) model=haiku ;;
  *fable*) model=fable ;; inherit) model= ;;
esac
stamp=$model
[ -n "$effort" ] && stamp+="${stamp:+ }$effort"
[ -z "$stamp" ] && exit 0

jq -c --arg d "$desc · $stamp" \
  '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "allow",
    updatedInput: (.tool_input + {description: $d})}}' <<<"$HOOK_INPUT"
