#!/bin/bash
# uv tool updater. Upgrades every tool `uv tool install` put in ~/.local/bin
# (claude-swap among them — it is on PyPI, not Homebrew), then prunes uv's
# cache, which drops the wheels the upgrade just orphaned. Runs as a job of
# mac/daily.sh, after brew so it uses the upgraded uv; its outcome line goes
# to $DAILY_SUMMARY.
#
# A long-running process keeps the code it started with, so when claude-swap
# moves, the dev.yossidoctor.cswap-auto LaunchAgent (claude/cswap-auto.sh) is
# restarted onto the new version. Other open cswap processes (watch, a
# `cswap run` session) keep the old one until restarted by hand.

# A step's verdict is its own exit status, never that of the `tail` trimming its output.
set -o pipefail

command -v uv >/dev/null 2>&1 || { echo "(uv not on PATH — skipped)"; exit 0; }

FAILURES=()

before=$(uv tool list 2>/dev/null)
uv tool upgrade --all 2>&1 | tail -5 || FAILURES+=("uv tool upgrade")
after=$(uv tool list 2>/dev/null)
# `uv tool list` prints "<name> v<version>" per tool, then its executables as "- <exe>".
read -ra UPDATED <<<"$(comm -13 <(grep -v '^-' <<<"$before" | sort) <(grep -v '^-' <<<"$after" | sort) | tr ' ' '@' | paste -sd' ' -)"

label="dev.yossidoctor.cswap-auto"
if [[ " ${UPDATED[*]} " == *" claude-swap@"* ]] && launchctl print "gui/$(id -u)/$label" >/dev/null 2>&1; then
    launchctl kickstart -k "gui/$(id -u)/$label" || FAILURES+=("restart $label")
fi

uv cache prune 2>&1 | tail -2 || FAILURES+=("uv cache prune")

if [ ${#FAILURES[@]} -gt 0 ]; then
    OUTCOME="❌ Failed: $(IFS=,; echo "${FAILURES[*]}")"
else
    OUTCOME="✅ Updated: ${UPDATED[*]:-nothing}"
fi
echo "$OUTCOME"
[ -n "${DAILY_SUMMARY:-}" ] && echo "$OUTCOME" >"$DAILY_SUMMARY"

[ ${#FAILURES[@]} -gt 0 ] && exit 1
exit 0
