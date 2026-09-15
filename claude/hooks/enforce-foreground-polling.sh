#!/usr/bin/env bash
# PreToolUse Bash hook: long-running work goes off-thread.
#
# Two verdicts, split by whether backgrounding preserves the command's value:
#   - REWRITTEN to run_in_background=true: follow streams and watch commands
#     (`tail -f`, `watch`, `kubectl logs -f`, `journalctl -f`, `gh run watch`,
#     `gh pr checks --watch`) — the output is what's wanted, off-thread is where
#     it belongs, so the call is normalized rather than refused.
#   - DENIED: a bare `sleep >=10` and sleep-loops. Backgrounding a wait yields
#     nothing to consume, and a poll loop off-thread still burns a subprocess
#     per tick — `ScheduleWakeup` and `Monitor` are the mechanisms that replace
#     them. Under ten seconds the wait is part of one operation (reaping a
#     killed process, settling a connect), so it passes.
#
# Skips when run_in_background=true (off-thread already), and for a sleep whose
# `description` is exactly `poll wait`. Both replacements the deny names are
# main-thread tools an agent does not have, so inside one the deny has no
# satisfiable form: backgrounding is not it either, since an agent's next turn
# starts the moment the call returns, so a backgrounded sleep delays nothing and
# the agent polls in a hot loop. The payload carries no caller identity to key on
# — session_id, transcript_path and cwd are the parent session's on an agent's
# call too — so the opt-out is the description, which only a prompt that means it
# sets. It names a bare sleep, never a poll loop.

set -u

. "$(dirname "${BASH_SOURCE[0]}")/hook-lib.sh"

hook_read_raw
case "$HOOK_INPUT" in
  *sleep*|*tail*|*watch*|*kubectl*|*journalctl*|*gh*) ;;
  *) exit 0 ;;
esac
hook_parse_input
cmd="$HOOK_CMD"
[ -z "$cmd" ] && exit 0
[ "$HOOK_RUN_IN_BACKGROUND" = "true" ] && exit 0

cmd_unq=$(hook_command_shape)

# The agent poll-wait opt-out: `description` exactly `poll wait` on a command
# that is one bare sleep. Anything else in the command (a `&&`, a second
# statement, a loop) falls through to the checks below, so the label buys a wait
# and never a chained workaround. The follow-stream rewrite at the end of the
# file is outside this gate — its output is the point wherever it runs.
#
# The sleep's own duration sets the call timeout, because the Bash default is
# 2 minutes: a longer wait is SIGTERMed mid-sleep (exit 143) and comes back short,
# which reads as a delay that silently did not happen.
if [ "$HOOK_DESCRIPTION" = "poll wait" ] &&
   printf '%s' "$cmd_unq" | grep -qE '^[[:space:]]*sleep[[:space:]]+[0-9]+([.][0-9]+)?[smhd]?[[:space:]]*;?[[:space:]]*$'; then
  printf '%s' "$HOOK_INPUT" | jq -c '
    ((.tool_input.command | capture("sleep[[:space:]]+(?<n>[0-9]+([.][0-9]+)?)(?<u>[smhd]?)"))
      | (.n | tonumber) * (if .u == "m" then 60 elif .u == "h" then 3600 elif .u == "d" then 86400 else 1 end)
    ) as $secs
    | (($secs * 1000 + 10000) | floor) as $ms
    | if (.tool_input.timeout // 0) >= $ms then empty else
      {hookSpecificOutput: {
        hookEventName: "PreToolUse",
        permissionDecision: "allow",
        permissionDecisionReason: "Poll wait — a labelled sleep is an agent'"'"'s only delay mechanism.",
        updatedInput: ((.tool_input // {}) + {timeout: $ms}),
        additionalContext: ("Poll wait allowed by enforce-foreground-polling.sh, timeout set to \($ms)ms — the Bash default of 2 minutes would SIGTERM this sleep mid-wait and return early.")}}
      end'
  exit 0
fi

# Fixed sleeps: N >= 10 (two-digit 10-99 or 3+ digits, optional `s` suffix), or
# any N with an m/h/d suffix. Below ten seconds a wait is part of one operation —
# letting a killed process reap, a device handshake settle — where the check
# belongs in the same command and there is nothing to come back to.
if printf '%s' "$cmd_unq" | grep -qE '\bsleep[[:space:]]+([1-9][0-9]|[1-9][0-9]{2,})([.][0-9]+)?s?\b|\bsleep[[:space:]]+[0-9]+([.][0-9]+)?[mhd]\b'; then
  deny "Foreground \`sleep\` >=10s blocked. Waiting on a condition is \`Monitor\` (off-thread, notifies on exit); a single fixed delay before re-checking is \`ScheduleWakeup\` (no process at all — the session resumes and re-checks); work whose OUTPUT is the point is \`Bash\` with \`run_in_background: true\`. Backgrounding a bare wait is not the fix — it still burns a subprocess and still needs someone to come back for the answer. Sub-10s waits pass, for settling after a kill or a connect."
fi

# Sleep-loops: polling pattern. Monitor runs off-thread + notifies on exit.
# A poll loop has `sleep` between a loop keyword and the loop's closing `done`.
# Strip from the LAST `done` onward (`${x%done*}`) so the head spans the whole
# outermost loop: a nested inner loop closing first stays inside the head, while
# a trailing sleep after the loop fully closes drops out
# (`for x in a b; do echo $x; done; sleep 5` -> head has no sleep).
case "$cmd_unq" in
  *done*)
    loop_head=${cmd_unq%done*}
    if printf '%s' "$loop_head" | grep -qE '\b(while|until|for)\b' &&
       printf '%s' "$loop_head" | grep -qE '\bsleep\b'; then
      deny "Foreground \`while|until|for ... sleep ...\` loop blocked. Use \`Monitor\` with \`until <check>; do sleep 2; done\` — runs off-thread, notifies on exit. Fire-and-forget loops: \`Bash\` with \`run_in_background: true\`."
    fi
    ;;
esac

# Follow streams and watch commands. Each produces output worth having, so the
# call is rewritten to run off-thread instead of refused.
#
# The patterns:
#   - `tail -f`/`--follow`: the flag may sit anywhere in tail's own pipeline
#     segment ([^|;&] keeps the scan from crossing into a piped command).
#   - `watch`: only in command position — start of input or after a separator.
#   - `kubectl logs -f`, `journalctl -f`: same segment-scoped flag match.
#   - `gh run watch`, `gh pr checks --watch`: gh's own blocking waits, in either
#     argument order.
if printf '%s' "$cmd_unq" | grep -qE '\btail\b[^|;&]*([[:space:]]-[a-zA-Z]*[fF][a-zA-Z]*\b|[[:space:]]--follow(=[^[:space:]]*)?\b)|(^|[;&|(])[[:space:]]*watch[[:space:]]|\bkubectl[[:space:]]+logs\b[^|;&]*([[:space:]]-[a-zA-Z]*f\b|--follow\b)|\bjournalctl\b[^|;&]*([[:space:]]-[a-zA-Z]*f\b|--follow\b)|\bgh[[:space:]]+run[[:space:]]+watch\b|\bgh[[:space:]]+pr[[:space:]]+checks\b[^|;&]*[[:space:]]--watch\b'; then
  printf '%s' "$HOOK_INPUT" | jq -c '{hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "allow",
    permissionDecisionReason: "Backgrounded — a stream off-thread needs no confirmation.",
    updatedInput: ((.tool_input // {}) + {run_in_background: true}),
    additionalContext: "Follow stream / watch command moved off-thread by enforce-foreground-polling.sh: run_in_background=true. It streams, so the main thread never blocks on it; output arrives via the completion notification. Drop the follow flag for a one-shot read instead."}}'
  exit 0
fi

exit 0
