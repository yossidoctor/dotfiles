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
# Skips when run_in_background=true (off-thread already).

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
