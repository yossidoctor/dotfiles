# What the harness does to a subagent

Read before writing or dispatching any agent that waits on something — a background process, a reply, another agent's verdict. Five mechanics, each invisible from an agent definition alone and each read off live transcripts and hook payloads; the harness changes under them, so each carries the command that re-verifies it. Every command reads `<agent>` as one subagent's transcript (`ls -t ~/.claude/projects/*/<session>/subagents/*.jsonl | head -1` for the newest) and `<parent>` as its dispatching session's (`~/.claude/projects/<project-dir>/<session>.jsonl`).

## A subagent idles by ending its turn, and only then

While it keeps working, its next turn opens the moment a tool call returns, so a backgrounded sleep it works past delays nothing and becomes a hot poll loop — context grows per poll and every turn re-reads all of it, so the cost is quadratic in poll count. Ended, it sits idle until one of its background processes exits (the harness wakes it with that command's exit code, once its dispatcher is idle — a dispatcher mid-turn holds the notice) or a message arrives (answered at once). A foreground-dispatched agent is told to hand back the moment its turn ends, so the idle wait needs a background dispatch. Only a `SubagentHandback` call delivers its report; text at the end of a turn reaches no one, and the caller's notice for a turn ended with background work live says the agent has not reported yet.

Re-verify: `rg -c '"name":"SubagentHandback"' <agent>` counts the delivering call, and `rg -n 'has not reported yet' <parent>` shows the interim notice.

## An agent waits on its own background process, never on a child agent

A child that ends its turn waiting on its own background work reaches its parent as a `completed` notice whose result is interim ("has not reported yet"). The parent then holds no live background work, so its next turn end draws a `[handback-send-enforce]` prompt and it hands back before the child's verdict exists. An agent whose work needs another agent's verdict first takes that verdict in its dispatch, from the main thread that ran the other agent.

Re-verify: `rg -n 'handback-send-enforce' <agent>` on a parent agent that dispatched a child.

## `ScheduleWakeup` and `Monitor` are main-thread only

An agent waiting on its own process backgrounds it and ends its turn (above). A condition no process of its own signals — a reply landing on a thread — gets one from a bare `sleep N` sent with `run_in_background: true`, after which the agent ends its turn and the sleep's exit wakes it to check again. Claude Code refuses a standalone foreground sleep before any hook runs (`~/dotfiles/claude/hooks/enforce-foreground-polling.sh` header). A message reaches the agent only when that sleep ends, so the sleep's length is also its reply latency.

Re-verify: `rg -l '"name":"(ScheduleWakeup|Monitor)"' ~/.claude/projects/*/*/subagents/*.jsonl` prints nothing.

## The Bash tool's timeout is the tool's own

A sleep longer than the call's `timeout` is SIGTERMed (exit 143) and returns early, reading as a delay that silently did not happen. The default and the maximum are stated in the Bash tool's own description, read in the session that sets them.

## A subagent's hook payload names the agent

`session_id`, `transcript_path` and `cwd` are the parent session's even on a subagent's call, but a subagent's payload adds `agent_id` and `agent_type`, which a main-thread call's lacks, so a hook tells the two apart on `.agent_id`.

Re-verify: in a PreToolUse hook, append `jq -c '{agent_id, agent_type, session_id}'` of the payload to a scratch log, then compare one main-thread call with one subagent call.
