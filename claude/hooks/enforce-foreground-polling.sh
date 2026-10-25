#!/bin/bash
# PreToolUse Bash hook: long-running work goes off-thread.
#
# Three verdicts:
#   - REWRITTEN to run_in_background=true, so the call runs rather than being
#     refused and retried:
#       follow streams and watch commands (`tail -f`, `watch`, `kubectl logs -f`,
#       `kubectl get -w`, `docker logs -f`, `journalctl -f`, `gh run watch`,
#       `gh pr checks --watch`), whose output is the point;
#       waits — a `sleep >=10` anywhere, or a `while`/`until` loop with a sleep
#       in its body. A foreground wait holds the session for its whole length.
#       Off-thread, the completion notification wakes the caller with the
#       command's output and exit code, so the wait and the check it guards run
#       as one backgrounded command and the caller ends its turn. That wake is
#       the one the main thread and a subagent both have
#       (~/dotfiles/docs/claude/subagent-harness.md); no session here carries
#       `Monitor`, and `ScheduleWakeup` runs only under `/loop`.
#   - DENIED: a job detached with a lone `&` and no `wait` — `( … &)`,
#     `nohup … &`, `cmd & next`. The shell owns that job, not the harness, so
#     its end wakes no one and the caller waits on a report that never comes.
#   - PASSED: a sleep under ten seconds, a `for` loop's included — a pause
#     inside one operation (reaping a killed process, settling a connect,
#     pacing requests to a rate-limited site).
#
# Skips when run_in_background=true (off-thread already).
#
# Claude Code refuses a standalone foreground sleep (`sleep 30` refused,
# `sleep 12` passed) before any PreToolUse hook runs, so no hook verdict can
# allow one. An agent polling a condition no process of its own signals (a reply
# landing on a thread) sends the bare sleep with run_in_background=true and ends
# its turn; the sleep's exit wakes it to check again.

set -u

. "$(dirname "${BASH_SOURCE[0]}")/hook-lib.sh"

# Literals with the trailing space where a bare word is a common substring: `gh`
# is in "light" and "through", `tail` in "detail", and the payload carries the
# cwd, the description and the session id alongside the command.
hook_read_raw
case "$HOOK_INPUT" in
  *sleep*|*'&'*|*'tail '*|*watch*|*'kubectl logs'*|*'kubectl get'*|*journalctl*|*'gh run'*|*'gh pr'*|*'docker logs'*|*'compose logs'*) ;;
  *) exit 0 ;;
esac
hook_parse_input
cmd="$HOOK_CMD"
[ -z "$cmd" ] && exit 0
[ "$HOOK_RUN_IN_BACKGROUND" = "true" ] && exit 0

cmd_unq=$(hook_command_shape)

background() {  # $1=reason  $2=additionalContext -> allow with run_in_background=true, exit 0
  printf '%s' "$HOOK_INPUT" | jq -c --arg r "$1" --arg c "$2" '{hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "allow",
    permissionDecisionReason: $r,
    updatedInput: ((.tool_input // {}) + {run_in_background: true}),
    additionalContext: $c}}'
  exit 0
}

# A lone `&` — not `&&`, `>&`, `&>`, `|&` — starts a job the shell owns; one
# `wait` in the same command reaps it there, so that form passes.
if printf '%s' "$cmd_unq" | grep -qE '(^|[^&>|<])&([^&>]|$)' && ! printf '%s' "$cmd_unq" | grep -qE '\bwait\b'; then
  deny "A job detached with \`&\` (or \`( … &)\`, \`nohup … &\`) belongs to the shell, not the harness, so its end wakes no one and its report never comes. Run it as its own call with \`run_in_background: true\` and no \`&\`, then end your turn; the completion notification wakes you with its output."
fi

WAIT_CONTEXT="Moved to the background by enforce-foreground-polling.sh: a foreground wait holds the session for its whole length. End your turn now; the completion notification wakes you with this command's output and exit code. A wait carries its own check (\`until <check>; do sleep 10; done; <report>\`), so the wake brings the answer."

# Fixed sleeps: N >= 10 (two-digit 10-99 or 3+ digits, optional `s` suffix), or
# any N with an m/h/d suffix. Below ten seconds a wait is part of one operation —
# letting a killed process reap, a device handshake settle — where the check
# belongs in the same command and there is nothing to come back to.
if printf '%s' "$cmd_unq" | grep -qE '\bsleep[[:space:]]+([1-9][0-9]|[1-9][0-9]{2,})([.][0-9]+)?s?\b|\bsleep[[:space:]]+[0-9]+([.][0-9]+)?[mhd]\b'; then
  background "Backgrounded — a wait off-thread wakes the caller on exit." "$WAIT_CONTEXT"
fi

# Poll loops: a `while`/`until` with `sleep` between its keyword and the loop's
# closing `done`. A `for` loop over a list with short sleeps paces work rather
# than polls, so it passes. The body under test runs from the FIRST loop keyword
# to the LAST `done` (`${x%done*}`), so it spans the whole outermost loop: a
# nested inner loop closing first stays inside, a sleep before the loop opens or
# after it fully closes drops out (`sleep 5; while x; do y; done` -> no sleep in
# the body).
case "$cmd_unq" in
  *done*)
    loop_head=${cmd_unq%done*}
    loop_body=$(printf '%s' "$loop_head" | grep -oE '(^|[;&|(][[:space:]]*|[[:space:]])(while|until)[[:space:]].*' | head -1)
    if [ -n "$loop_body" ] && printf '%s' "$loop_body" | grep -qE '\bsleep\b'; then
      background "Backgrounded — a poll loop off-thread wakes the caller when it exits." "$WAIT_CONTEXT"
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
#   - `kubectl logs -f`, `journalctl -f`, `docker logs -f`, `docker compose logs
#     -f`: same segment-scoped flag match.
#   - `kubectl get -w` / `--watch`: kubectl's own watch, which never returns.
#   - `gh run watch`, `gh pr checks --watch`: gh's own blocking waits, in either
#     argument order.
if printf '%s' "$cmd_unq" | grep -qE '\btail\b[^|;&]*([[:space:]]-[a-zA-Z]*[fF][a-zA-Z]*\b|[[:space:]]--follow(=[^[:space:]]*)?\b)|(^|[;&|(])[[:space:]]*watch[[:space:]]|\bkubectl[[:space:]]+logs\b[^|;&]*([[:space:]]-[a-zA-Z]*f\b|--follow\b)|\bkubectl[[:space:]]+get\b[^|;&]*([[:space:]]-w\b|[[:space:]]--watch(-only)?\b)|\bdocker(-compose|[[:space:]]+compose)?[[:space:]]+logs\b[^|;&]*([[:space:]]-[a-zA-Z]*f\b|--follow\b)|\bjournalctl\b[^|;&]*([[:space:]]-[a-zA-Z]*f\b|--follow\b)|\bgh[[:space:]]+run[[:space:]]+watch\b|\bgh[[:space:]]+pr[[:space:]]+checks\b[^|;&]*[[:space:]]--watch\b'; then
  background "Backgrounded — a stream off-thread needs no confirmation." \
    "Follow stream / watch command moved off-thread by enforce-foreground-polling.sh: run_in_background=true. It streams, so the main thread never blocks on it; output arrives via the completion notification. Drop the follow flag for a one-shot read instead."
fi

exit 0
