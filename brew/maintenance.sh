#!/bin/bash

# Homebrew Maintenance Script — plus the two language-tool caches nothing
# else trims: `npm cache verify` (drops corrupt and expired entries; a missing
# entry only costs a re-download) and `uv cache prune` (drops wheels no
# installed tool references). Both skip when the tool is absent.
#
# Runs non-interactively: upgrade steps pass `--yes` so brew's confirmation
# prompt never blocks an unattended run.
#
# The formula step is scoped with `--formula` — a bare `brew upgrade` takes
# casks too, which would route them past the cask step's flags. Every cask
# therefore upgrades under `--no-quit`: a running app is left alone, and serves
# its old binary until quit by hand.
#
# A cask that installs through a .pkg runs `sudo` on every upgrade. With no
# terminal on stdin and no cached sudo ticket (the daily run), those casks are
# left out of the upgrade, since the password prompt can only fail there. One
# marked auto_updates is left to its own updater; any other is named in a warning with the command to run by
# hand. A terminal run upgrades them all and brings brew's record level with
# what the app updated itself to.
#
# Continues on per-step failure and reports at the end. `brew update` failure
# is special: it doesn't abort, but flags the run STALE because all later
# steps would be operating on out-of-date tap metadata.
#
# After `brew update`, HOMEBREW_NO_AUTO_UPDATE holds the whole run to that one
# snapshot. Without it, any step starting 450s later (the API refresh interval —
# a run the Mac sleeps through is hours of wall time) refetches metadata, so a
# version published mid-run lands after its upgrade step: skipped, then flagged
# by cleanup, and missing from the Upgraded diff.
#
# An upgrade step's verdict is what it leaves outdated, not brew's exit code:
# brew exits non-zero when a download fails once even though its retry
# installs the package. Pinned formulae are held back by intent and don't count.
#
# The drift check reads every Brewfile under ~/.config/homebrew/Brewfile.d/ as
# one set (each layer links its own there; this repo's is 00-base), because a
# formula one layer declares is drift against the other layer's file alone.
# `bundle cleanup` runs without --force and with stdin closed, so it lists what
# no Brewfile declares and removes nothing.
#
# Runs daily as a job of mac/daily.sh, whose end banner
# is the closing outcome line written to $DAILY_SUMMARY.

# A step's verdict is its own exit status, never that of the `tail` trimming
# its output.
set -o pipefail

STALE=0
FAILURES=()
WARNINGS=()

list_outdated() {
    brew outdated --greedy --quiet "$@" 2>/dev/null
}

upgrade() {
    local kind=$1 outdated left
    shift
    brew upgrade "$kind" --yes --quiet "$@" && return
    if ! outdated=$(list_outdated "$kind"); then
        FAILURES+=("brew upgrade $kind")
        return
    fi
    left=$(comm -23 <(sort <<<"$outdated") <({ brew list --pinned; echo "$DEFERRED"; } | sort) | paste -sd' ' -)
    if [ -n "$left" ]; then
        FAILURES+=("brew upgrade $kind: $left")
    else
        echo "  (brew exited non-zero, but nothing is left outdated)"
    fi
}

echo "========================================"
echo "  Homebrew Maintenance Script"
echo "  $(date)"
echo "========================================"
echo

echo "→ Updating Homebrew..."
if ! brew update; then
    STALE=1
    FAILURES+=("brew update")
fi
export HOMEBREW_NO_AUTO_UPDATE=1
OUTDATED_BEFORE=$(list_outdated)
echo

echo "→ Upgrading formulae..."
upgrade --formula
echo

echo "→ Upgrading casks (--greedy)..."
if [ ! -t 0 ] && ! sudo -n true 2>/dev/null; then
    pkg_casks=$(brew info --cask --json=v2 --installed | jq -c '[.casks[] | select(any(.artifacts[]; has("pkg")))]')
    DEFERRED=$(jq -r '.[].token' <<<"$pkg_casks")
    NOT_SELF_UPDATING=$(jq -r '.[] | select(.auto_updates | not) | .token' <<<"$pkg_casks")
fi
read -ra CASKS <<<"$(comm -23 <(list_outdated --cask | sort) <(sort <<<"$DEFERRED") | paste -sd' ' -)"
if [ ${#CASKS[@]} -gt 0 ]; then
    upgrade --cask --greedy --no-quit "${CASKS[@]}"
else
    echo "  (nothing to upgrade unattended)"
fi
NEEDS_TERMINAL=$(comm -12 <(list_outdated --cask | sort) <(sort <<<"$NOT_SELF_UPDATING") | paste -sd' ' -)
[ -n "$NEEDS_TERMINAL" ] && WARNINGS+=("pkg casks need sudo, run in a terminal: brew upgrade --cask $NEEDS_TERMINAL")
UPGRADED=$(comm -23 <(sort <<<"$OUTDATED_BEFORE") <(list_outdated | sort) | paste -sd' ' -)
echo

echo "→ Removing unused dependencies..."
brew autoremove || FAILURES+=("brew autoremove")
echo

echo "→ Cleaning up old versions and cache..."
brew cleanup --prune=all || FAILURES+=("brew cleanup")
echo

echo "→ Running brew doctor..."
brew doctor
DOCTOR_EXIT=$?
[ "$DOCTOR_EXIT" -ne 0 ] && WARNINGS+=("brew doctor reported issues (exit $DOCTOR_EXIT)")
echo

echo "→ Language-tool caches (npm verify, uv prune)..."
if command -v npm >/dev/null 2>&1; then
    npm cache verify 2>&1 | tail -3 || WARNINGS+=("npm cache verify failed")
else
    echo "  (npm not on PATH — skipped)"
fi
if command -v uv >/dev/null 2>&1; then
    uv cache prune 2>&1 | tail -2 || WARNINGS+=("uv cache prune failed")
else
    echo "  (uv not on PATH — skipped)"
fi
echo

echo "→ Brewfile drift, every layer's Brewfile as one set (informational)..."
brewfiles=("$HOME"/.config/homebrew/Brewfile.d/*)
if [ -e "${brewfiles[0]}" ]; then
    union=$(mktemp)
    cat "${brewfiles[@]}" > "$union"
    if ! brew bundle check --verbose --file "$union"; then
        WARNINGS+=("declared in a Brewfile but not installed")
    fi
    cleanup_report=$(brew bundle cleanup --file "$union" </dev/null 2>&1)
    case "$cleanup_report" in
        *"Would "*) printf '%s\n' "$cleanup_report"; WARNINGS+=("installed but declared in no Brewfile") ;;
        *) echo "  (nothing installed outside the Brewfiles)" ;;
    esac
    rm -f "$union"
else
    echo "  (no Brewfiles under ~/.config/homebrew/Brewfile.d — run ./install)"
fi
echo

echo "========================================"
echo "  Upgraded: ${UPGRADED:-nothing}"
if [ "$STALE" -eq 1 ]; then
    echo "  ⚠️  STALE METADATA: brew update failed"
    echo "      Results are incomplete."
fi
if [ ${#WARNINGS[@]} -gt 0 ]; then
    echo "  Warnings:"
    printf '    - %s\n' "${WARNINGS[@]}"
fi
if [ ${#FAILURES[@]} -gt 0 ]; then
    echo "  Step failures:"
    printf '    - %s\n' "${FAILURES[@]}"
else
    echo "  Maintenance complete — no step failures"
fi
echo "========================================"

if [ ${#FAILURES[@]} -gt 0 ]; then
    OUTCOME="❌ Failed: $(IFS=,; echo "${FAILURES[*]}")"
elif [ ${#WARNINGS[@]} -gt 0 ]; then
    OUTCOME="⚠️ ${#WARNINGS[@]} warning(s)"
else
    OUTCOME="✅ Clean"
fi
[ -n "${DAILY_SUMMARY:-}" ] && echo "$OUTCOME · upgraded: ${UPGRADED:-nothing}" >"$DAILY_SUMMARY"

[ ${#FAILURES[@]} -gt 0 ] && exit 1
exit 0
