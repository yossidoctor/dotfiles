#!/bin/bash
# Claude Code plugin updater. Refreshes every marketplace catalog, then updates
# each installed plugin, so the plugins stay current without a manual
# /plugin run. Runs as a job of mac/daily.sh, after the brew upgrade so it
# uses the upgraded claude binary; its outcome line goes to $DAILY_SUMMARY.
#
# An update only lands on disk: sessions already open keep the old version
# until restarted. A plugin whose marketplace declares an install command is
# refused here (no terminal to confirm it), and that counts as a failure.
#
# Each claude call is killed after $call_timeout seconds (perl's alarm survives
# the exec), so one hung call fails by name in the log instead of holding the
# job until the runner's deadline.

command -v claude >/dev/null 2>&1 || { echo "(claude not on PATH — skipped)"; exit 0; }

call_timeout=180
FAILURES=()
UPDATED=()

claude_call() {
    echo "$(date +%T) claude $*" >&2
    perl -e 'alarm shift; exec @ARGV' "$call_timeout" claude "$@" </dev/null
}

settings="$HOME/.claude/settings.json"

# One pass per Claude config dir: the default ~/.claude, then each claude-swap
# session profile (`cswap run`), which keeps its own plugins/ while sharing
# settings.json. A pass first adds any marketplace settings.json declares that
# the dir lacks, and installs any enabled plugin it lacks, so a profile carries
# what the default login does. `marketplace add` rewrites settings.json in
# Claude's own key order; the tracked file is kept in that order, so the
# rewrite changes nothing.
update_dir() {
    local tag=$1 list id repo result
    echo "== $tag"
    list=$(claude_call plugin marketplace list --json) || { FAILURES+=("$tag: marketplace list"); return; }
    for repo in $(jq -er --argjson have "$list" '
            .extraKnownMarketplaces // {} | to_entries[]
            | select(.key as $k | [$have[].name] | index($k) | not)
            | .value.source | select(.source == "github") | .repo' "$settings"); do
        claude_call plugin marketplace add "$repo" || FAILURES+=("$tag: add $repo")
    done
    claude_call plugin marketplace update || FAILURES+=("$tag: marketplace update")

    list=$(claude_call plugin list --json) || { FAILURES+=("$tag: plugin list"); return; }
    for id in $(jq -er --argjson have "$list" '
            .enabledPlugins // {} | to_entries[]
            | select(.value == true and (.key | endswith("@builtin") | not))
            | select(.key as $k | [$have[].id] | index($k) | not) | .key' "$settings"); do
        echo "→ $id (missing)"
        claude_call plugin install "$id" --json >/dev/null && UPDATED+=("$tag:$id") || FAILURES+=("$tag: install $id")
    done

    for id in $(jq -er '.[].id' <<<"$list"); do
        echo "→ $id"
        if result=$(claude_call plugin update "$id" --json); then
            echo "  $(jq -r '.message' <<<"$result")"
            [ "$(jq -r '.updateOutcome' <<<"$result")" = up_to_date ] || UPDATED+=("$tag:$id")
        else
            echo "  failed: $result"
            FAILURES+=("$tag: $id")
        fi
    done
}

update_dir default
for profile in "$HOME"/.claude-swap-backup/sessions/*/; do
    [ -d "$profile" ] || continue
    CLAUDE_CONFIG_DIR=${profile%/} update_dir "$(basename "$profile")"
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
