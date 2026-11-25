#!/bin/bash
# PostToolUse + Stop hook: tells the main session when its context window
# crosses the soft and the hard limit, once each per session. Opt-in: it acts
# only for a session that created ~/.claude/state/context-limits/<session id>.on
# (360's implementation.md does, as its first move).
#
#   soft  a note on the next tool result: start a shift change.
#   hard  a note to start a handover, and the first turn end after it is blocked
#         once, so a session that was about to go idle starts it instead.
# What each one means is the session's skill (360: SKILL.md § Between the two sessions, **Handover**); this
# hook only says which limit was crossed.
#
# Claude Code gives hooks no context figure. The transcript's last main-thread
# assistant usage does: input + cache reads + cache writes, the formula the
# statusline's context_window.used_percentage uses.
#
# Limits are tokens, set from a measured wall. Sessions on the 1M window failed
# with "Prompt is too long" at 975k–977k. HARD is 70%, the user's pick: its 300k
# to the wall holds a handover (3k and 15k measured) many times over the largest
# single-step jump seen (43k, a subagent report or a big read). SOFT is 50%, the user's
# pick: a shift change keeps this session alive to receive its running agents'
# reports, so it leaves those reports the whole band up to HARD.
# shortcut: assumes the 1M window every session here runs on; a smaller-window
# main session needs the window read from the statusline payload.
WALL=975000  # measured: where "Prompt is too long" hit
SOFT=${CLAUDE_CONTEXT_SOFT_TOKENS:-500000}
HARD=${CLAUDE_CONTEXT_HARD_TOKENS:-700000}

set -u
in=$(cat)
eval "$(printf '%s' "$in" | jq -r '
  "ev=" + (.hook_event_name // "" | @sh),
  "sid=" + (.session_id // "" | @sh),
  "tp=" + (.transcript_path // "" | @sh),
  "agent=" + (.agent_id // "" | @sh)' 2>/dev/null)"
: "${ev=}" "${sid=}" "${tp=}" "${agent=}"
# A subagent has its own window and no handover.
[ -z "$agent" ] && [ -n "$sid" ] && [ -f "$tp" ] || exit 0

mark="$HOME/.claude/state/context-limits/$sid"
[ -f "$mark.on" ] || exit 0  # not opted in; the common path
[ -f "$mark.hard-stop" ] && exit 0  # both limits spent

used=$(tail -n 40 "$tp" | grep '"usage"' | jq -s '
  [.[] | select(.type == "assistant" and (.isSidechain | not) and .message.model != "<synthetic>") | .message.usage]
  | last // {} | (.input_tokens // 0) + (.cache_read_input_tokens // 0) + (.cache_creation_input_tokens // 0)' 2>/dev/null)
[ "${used:-0}" -ge "$SOFT" ] || exit 0

if [ "$used" -ge "$HARD" ]; then level=hard act=handover; else level=soft act='shift change'; fi
left=$(( (WALL - used) / 1000 ))
msg="Context ${level} limit: $(( used / 1000 ))k tokens used, about ${left}k left before the session can no longer reply. Start a ${act}, as this session's skill defines it; with none, tell the user."

mkdir -p "${mark%/*}"
if [ "$ev" = Stop ]; then
  [ "$level" = hard ] || exit 0
  touch "$mark.hard-stop" "$mark.hard"
  jq -cn --arg r "$msg" '{decision: "block", reason: $r}'
  exit 0
fi
[ -f "$mark.$level" ] && exit 0
touch "$mark.$level"
jq -cn --arg m "$msg" '{hookSpecificOutput: {hookEventName: "PostToolUse", additionalContext: $m}}'
