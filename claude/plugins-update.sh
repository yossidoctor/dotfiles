#!/bin/bash
# Claude Code plugin updater. Refreshes every marketplace catalog, then updates
# each installed plugin, so the plugins stay current without a manual
# /plugin run. Runs as a job of mac/daily.sh, after the brew upgrade so it
# uses the upgraded claude binary; its outcome line goes to $DAILY_SUMMARY.
#
# An update only lands on disk: sessions already open keep the old version
# until restarted. A plugin whose marketplace declares an install command is
# refused here (no terminal to confirm it), and that counts as a failure.

command -v claude >/dev/null 2>&1 || { echo "(claude not on PATH — skipped)"; exit 0; }

FAILURES=()
UPDATED=()

claude plugin marketplace update || FAILURES+=("marketplace update")

for id in $(claude plugin list --json | jq -er '.[].id'); do
    echo "→ $id"
    if result=$(claude plugin update "$id" --json </dev/null); then
        echo "  $(jq -r '.message' <<<"$result")"
        [ "$(jq -r '.updateOutcome' <<<"$result")" = up_to_date ] || UPDATED+=("$id")
    else
        echo "  failed: $result"
        FAILURES+=("$id")
    fi
done

if [ ${#FAILURES[@]} -gt 0 ]; then
    OUTCOME="❌ Failed: $(IFS=,; echo "${FAILURES[*]}")"
else
    OUTCOME="✅ Updated: ${UPDATED[*]:-nothing}"
fi
echo "$OUTCOME"
[ -n "${DAILY_SUMMARY:-}" ] && echo "$OUTCOME" >"$DAILY_SUMMARY"

[ ${#FAILURES[@]} -gt 0 ] && exit 1
exit 0
