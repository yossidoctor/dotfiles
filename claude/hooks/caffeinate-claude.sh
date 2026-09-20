#!/usr/bin/env bash
# Keep macOS awake while Claude is working.
#
# UserPromptSubmit -> `active`: caffeinate while Claude generates (1h bound).
# Stop             -> `linger`: 30-min post-turn window for a late follow-up
#                                (e.g. a remote response from the Claude app).
#
# caffeinate is bound to the Claude PID via -w, so it dies the moment that session
# exits (clean quit, ⌘Q, crash — all the same); -t is the upper bound.
#
# Scope: lid-open only. Closing the lid sleeps regardless — clamshell sleep is a
# separate path no caffeinate assertion covers, and -s is AC-only per caffeinate(8),
# so on battery it is inert. Lid-closed wake needs `sudo pmset disablesleep 1`
# (global, not per-process) or real clamshell mode (external display + power).

set -u

. "$(dirname "${BASH_SOURCE[0]}")/hook-lib.sh"

mode="${1:-}"
case "$mode" in active|linger) ;; *) exit 0 ;; esac

hook_read_input
session="${HOOK_SESSION_ID:-default}"
pidfile="/tmp/claude-caffeinate-${session}.pid"

# Find this hook's Claude parent by walking up the process tree. Empty -> -w is
# omitted and caffeinate relies on -t alone.
claude_pid=""
pid=$$
for _ in 1 2 3 4 5 6; do
  pid=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')
  case "$pid" in ""|0|1) break ;; esac
  cmd=$(ps -o command= -p "$pid" 2>/dev/null)
  binary=${cmd%% *}
  [ "${binary##*/}" = "claude" ] && { claude_pid="$pid"; break; }
done

# Replace any prior caffeinate for this session. The pidfile can outlive its
# process and the OS reuses PIDs, so only kill a PID that still runs caffeinate.
if [ -f "$pidfile" ]; then
  old=$(cat "$pidfile" 2>/dev/null)
  case "$old" in
    *[!0-9]*|'') ;;
    *)
      case "$(ps -o command= -p "$old" 2>/dev/null)" in
        *caffeinate*) kill "$old" 2>/dev/null ;;
      esac
      ;;
  esac
fi

if [ "$mode" = "active" ]; then
  timeout=3600
else
  timeout=1800
fi

# -i prevent idle sleep, -s prevent sleep on AC, -w exit when Claude exits, -t bound.
if [ -n "$claude_pid" ]; then
  nohup caffeinate -is -w "$claude_pid" -t "$timeout" </dev/null >/dev/null 2>&1 &
else
  nohup caffeinate -is -t "$timeout" </dev/null >/dev/null 2>&1 &
fi
echo $! > "$pidfile"
disown 2>/dev/null || true
