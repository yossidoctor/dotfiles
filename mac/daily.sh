#!/bin/bash
# Daily job runner, started by the LaunchAgent daily-agent.sh installs. Runs
# every job under ~/.config/daily.d/ in name order, one at a time: each layer
# links its own there, and running them serially keeps a brew upgrade from
# landing under another job's install. A job past its deadline has its whole
# process tree killed and ends ❌ timed out, so a hung job neither holds the
# ones after it nor keeps launchd from starting the next day's run; a job cut
# mid-install is the price of that bound.
#
# launchd starts the run inside the scheduled wake daily-agent.sh sets, which
# with the lid closed sleeps again within seconds, on battery whatever
# caffeinate asserts, and freezes a job mid-fetch. So the runner's first act
# is `pmset disablesleep 1` (passwordless through the sudoers.d rule
# daily-agent.sh installs), undone by the EXIT trap, which also runs when the
# runner is TERMed; caffeinate stays as the hold when sudo refuses. A SIGKILL
# skips the trap and leaves sleep disabled until the next run's exit. The
# deadlines bound how long the Mac is held awake.
#
# The runner starts the moment the Mac wakes, before Wi-Fi may be back, so it
# first waits a bounded time for github.com to answer; the jobs run either way
# and report their own network failures. PATH is zshenv's, which carries no
# node, so fnm's default node is put on it for the jobs' npm.
#
# Each job runs with stdin from /dev/null and its output in a per-run log. A
# terminal-notifier banner marks its start and its end — one group per job, so
# the end replaces the start, and a click opens the log. The end banner is the
# one line the job writes to the file named by $DAILY_SUMMARY, or ✅/❌ from
# its exit code when it writes none. Names drop their order prefix. A banner
# macOS refuses (notifications off for terminal-notifier) is reported on
# stderr, which the LaunchAgent keeps.
set -u

sudo -n /usr/bin/pmset disablesleep 1 && trap 'sudo -n /usr/bin/pmset disablesleep 0' EXIT

jobs_dir="$HOME/.config/daily.d"
log_root="$HOME/Library/Logs/daily"
deadline_seconds=1200

notify() {
    terminal-notifier -title "$1" -message "$2" -group "daily-$1" -open "file://$3" >&2
}

kill_tree() {
    local child
    for child in $(pgrep -P "$1"); do kill_tree "$child"; done
    kill -TERM "$1" 2>/dev/null
}

caffeinate -i -w $$ &

command -v npm >/dev/null 2>&1 || { command -v fnm >/dev/null 2>&1 && eval "$(fnm env --shell bash)"; }

for _ in $(seq 20); do
    curl -fs -o /dev/null --max-time 5 https://github.com && break
    sleep 10
done

for job in "$jobs_dir"/*; do
    [ -e "$job" ] || continue
    name=$(basename "$job")
    name=${name#[0-9][0-9]-}
    log_dir="$log_root/$name"
    log="$log_dir/$(date +%Y-%m-%d_%H%M).log"
    summary=$(mktemp)
    mkdir -p "$log_dir"
    find "$log_dir" -name '*.log' -mtime +30 -delete
    notify "$name" "Started — click for the live log" "$log"
    DAILY_SUMMARY="$summary" "$job" </dev/null >"$log" 2>&1 &
    pid=$!
    ( sleep "$deadline_seconds"; touch "$summary.timeout"; kill_tree "$pid" ) &
    watchdog=$!
    wait "$pid" 2>/dev/null
    rc=$?
    kill_tree "$watchdog"
    wait "$watchdog" 2>/dev/null
    outcome=$(head -1 "$summary")
    if [ -e "$summary.timeout" ]; then
        outcome="❌ Timed out after $((deadline_seconds / 60)) min"
        echo "daily: killed after ${deadline_seconds}s" >>"$log"
    elif [ -z "$outcome" ]; then
        if [ "$rc" -eq 0 ]; then outcome="✅ Done"; else outcome="❌ Exited $rc"; fi
    fi
    notify "$name" "$outcome" "$log"
    rm -f "$summary" "$summary.timeout"
done
