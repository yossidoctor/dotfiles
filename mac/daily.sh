#!/bin/bash
# Daily job runner, started by the LaunchAgent daily-agent.sh installs. Runs
# every job under ~/.config/daily.d/ in name order, one at a time: each layer
# links its own there, and running them serially keeps a brew upgrade from
# landing under another job's install. Jobs have no timeout, so a hung job
# holds the ones after it, and launchd starts no new run while it is alive.
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
# its exit code when it writes none. Names drop their order prefix.
set -u

jobs_dir="$HOME/.config/daily.d"
log_root="$HOME/Library/Logs/daily"

notify() {
    terminal-notifier -title "$1" -message "$2" -group "daily-$1" -open "file://$3" >/dev/null 2>&1
}

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
    DAILY_SUMMARY="$summary" "$job" </dev/null >"$log" 2>&1
    rc=$?
    outcome=$(head -1 "$summary")
    if [ -z "$outcome" ]; then
        if [ "$rc" -eq 0 ]; then outcome="✅ Done"; else outcome="❌ Exited $rc"; fi
    fi
    notify "$name" "$outcome" "$log"
    rm -f "$summary"
done
