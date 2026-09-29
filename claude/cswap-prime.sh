#!/bin/bash
# 5h-window primer, started by the LaunchAgent cswap-prime-agent.sh installs
# (that script owns the schedule and the wake). Sends one tiny Haiku prompt to
# every claude-swap account, so each account's 5h window opens at the slot
# rather than at the first message of the day, and a workday spans three
# windows.
#
# Each prompt goes through `cswap run <n>`, which runs claude as that account
# in its own CLAUDE_CONFIG_DIR profile and refreshes its token first; the
# default login and every open session stay on their account. `cswap switch`
# would swap the default login under them.
#
# A prompt sent inside a live window opens nothing, so each account is read
# first from `cswap list --json`: a window resetting within $reset_wait_cap
# seconds is waited out (plus a margin) and then primed, one resetting later
# than that is left alone, and one with no window or no fresh usage reading is
# primed at once. The 5h reset is the account's fiveHour.resetsAt.
#
# With the lid closed the Mac runs this in wakes of 10–60 s and sleeps between
# them whatever caffeinate asserts, so a run can freeze mid-request and resume
# a wake later. The whole run takes seconds, it waits a bounded time for
# api.anthropic.com first (Wi-Fi may still be down), and each prompt is killed
# after $send_timeout seconds (perl's alarm survives the exec chain cswap →
# claude) and retried up to $attempts times, so a request broken by sleep is
# sent again on a later wake.
#
# Every run appends one line per account to the log, with the prompts' own
# output, and ends in one terminal-notifier banner that opens the log on
# click: ✅ primed, ⏭ still live, ❌ failed after every attempt. A primed
# window's reset reads "~" because cswap serves usage from a cache that
# refreshes minutes later; `cswap list` then shows the real one.
set -u

reset_wait_cap=3600
reset_margin=30
send_timeout=120
attempts=5
retry_gap=30
log="$HOME/Library/Logs/cswap-prime.log"

note() { printf '%s %s\n' "$(date '+%F %T')" "$*" >>"$log"; }
notify() { terminal-notifier -title cswap-prime -message "$1" -group cswap-prime -open "file://$log" >&2; }

prime() {
    local try
    for try in $(seq "$attempts"); do
        perl -e 'alarm shift; exec @ARGV' "$send_timeout" \
            cswap run "$1" -- -p ok --model haiku --no-session-persistence </dev/null >>"$log" 2>&1 && return 0
        note "account $1: attempt $try failed, exit $?"
        [ "$try" -lt "$attempts" ] && sleep "$retry_gap"
    done
    return 1
}

caffeinate -i -w $$ &

for _ in $(seq 20); do
    curl -s -o /dev/null --max-time 5 https://api.anthropic.com && break
    sleep 10
done

plan=$(cswap list --json | jq -r '
    .accounts[]
    | [.number,
       ((.usage.fiveHour.resetsAt // "")
        | if . == "" then 0
          else (try (sub("\\.[0-9]+"; "") | sub("\\+00:00$"; "Z") | fromdateiso8601) catch 0)
          end)]
    | @tsv')
if [ -z "$plan" ]; then
    note "no accounts from cswap list --json"
    notify "❌ cswap list returned no accounts"
    exit 1
fi

primed="" live="" failed=""
while IFS=$'\t' read -r account reset_at; do
    reset_in=$((reset_at - $(date +%s)))
    if [ "$reset_in" -gt "$reset_wait_cap" ]; then
        note "account $account: skipped, window live until $(date -r "$reset_at" +%H:%M)"
        live="$live $account (until $(date -r "$reset_at" +%H:%M))"
        continue
    fi
    if [ "$reset_in" -gt 0 ]; then
        note "account $account: waiting for the $(date -r "$reset_at" +%H:%M) reset"
        notify "⏳ Waiting for the $(date -r "$reset_at" +%H:%M) reset"
        sleep $((reset_in + reset_margin))
    fi
    if prime "$account"; then
        note "account $account: primed"
        primed="$primed $account"
    else
        note "account $account: not primed after $attempts attempts"
        failed="$failed $account"
    fi
done <<<"$plan"

message=""
[ -n "$failed" ] && message="$message · failed:$failed"
[ -n "$primed" ] && message="$message · primed:$primed, resets ~$(date -v+5H +%H:%M)"
[ -n "$live" ] && message="$message · live:$live"
message=${message# · }
if [ -n "$failed" ]; then
    notify "❌ $message"
elif [ -n "$primed" ]; then
    notify "✅ $message"
else
    notify "⏭ $message"
fi
[ -z "$failed" ]
