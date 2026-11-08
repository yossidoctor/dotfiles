# What the harness does to a subagent

Read before writing or dispatching any agent that waits on something — a background process, a reply, another agent's verdict. Five mechanics, each invisible from an agent definition alone and each read off live transcripts and hook payloads; the harness changes under them, so each carries the command that re-verifies it. Every command reads `<agent>` as one subagent's transcript (`ls -t ~/.claude/projects/*/<session>/subagents/*.jsonl | head -1` for the newest) and `<parent>` as its dispatching session's (`~/.claude/projects/<project-dir>/<session>.jsonl`).

## A subagent idles by ending its turn, and only then

While it keeps working, its next turn opens the moment a tool call returns, so a backgrounded sleep it works past delays nothing and becomes a hot poll loop — context grows per poll and every turn re-reads all of it, so the cost is quadratic in poll count. Ended, it sits idle until one of its background processes exits (the harness wakes it with that command's exit code) or a message arrives (answered at once). Every turn it ends sends its dispatcher a notice, delivered between the dispatcher's tool calls even mid-turn (CHANGELOG 2.1.234), so each idle wait costs the dispatcher a turn. That notice carries the turn's closing text; a turn ended with background work live reads `Agent "<name>" is waiting on its own background work`, its result marked interim (CHANGELOG 2.1.299). A foreground-dispatched agent is told to hand back the moment its turn ends, so the idle wait needs a background dispatch. In auto mode the report is delivered by a `SubagentHandback` call, the one mode that provides the tool; in every other mode the final turn's text is the report.

Re-verify: `rg -n 'is waiting on its own background work' <parent>` shows each interim notice and its text; `rg -c '"name":"SubagentHandback"' <agent>` counts the delivering call in an auto-mode run.

## An agent waits on its own background process, never on a child agent

A child that ends its turn waiting on its own background work reaches its parent as a `completed` notice whose result is interim ("is waiting on its own background work"). The parent then holds no live background work, so its next turn end hands back before the child's verdict exists — in auto mode through the `[handback-send-enforce]` prompt, in every other mode by its turn's text becoming the report. An agent whose work needs another agent's verdict first takes that verdict in its dispatch, from the main thread that ran the other agent.

Re-verify: `rg -n 'handback-send-enforce' <agent>` on a parent agent that dispatched a child.

## A condition is watched with `Monitor`; a message lands at once

An agent waiting on its own process backgrounds it and ends its turn (above). A condition no process of its own signals — a reply landing on a thread — is watched with `Monitor`, which a subagent has behind a `ToolSearch` load like the main thread: the call returns at once ("Monitor started … You will be notified on each event") and the agent ends its turn. A bare `sleep N` with `run_in_background: true` does the same at the sleep's granularity, and Claude Code refuses a standalone foreground sleep before any hook runs (`~/dotfiles/claude/hooks/enforce-foreground-polling.sh` header). A message sent to an agent mid-command moves that command to the background and is delivered at once (CHANGELOG 2.1.317), so a sleep's length is not its reply latency.

Re-verify: `rg -o 'Monitor started[^"]{0,60}' <agent>` shows a subagent's accepted watch; `rg -n 'moved to the background' <agent>` after a `SendMessage` to it mid-command shows the delivery.

## The Bash tool's timeout backgrounds the command

A command still running at the call's `timeout` is moved to the background: the result returns the output so far and says so, the agent ends its turn, and the completion notification brings the rest with the exit code. The default and the maximum are stated in the Bash tool's own description, read in the session that sets them.

Re-verify: a `sleep 12` under `timeout: 5000` returns "Command did not complete within its 5s timeout and was moved to the background", then a completion notice with exit 0.

## A subagent's hook payload names the agent

`session_id`, `transcript_path` and `cwd` are the parent session's even on a subagent's call, but a subagent's payload adds `agent_id` and `agent_type`, which a main-thread call's lacks, so a hook tells the two apart on `.agent_id`.

Re-verify: in a PreToolUse hook, append `jq -c '{agent_id, agent_type, session_id}'` of the payload to a scratch log, then compare one main-thread call with one subagent call.
