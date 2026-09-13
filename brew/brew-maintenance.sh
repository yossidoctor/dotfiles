#!/usr/bin/env bash

# Homebrew Maintenance Script
#
# Runs non-interactively: upgrade steps pass `--yes` so brew's confirmation
# prompt never blocks an unattended run.
#
# The formula step is scoped with `--formula` — a bare `brew upgrade` takes
# casks too, which would route them past the cask step's flags. Every cask
# therefore upgrades under `--no-quit`: a running app is left alone, and serves
# its old binary until quit by hand.
#
# Continues on per-step failure and reports at the end. `brew update` failure
# is special: it doesn't abort, but flags the run STALE because all later
# steps would be operating on out-of-date tap metadata.

. "$HOME/dotfiles/brew/env.sh"

STALE=0
FAILURES=()
WARNINGS=()

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
echo

echo "→ Upgrading formulae..."
brew upgrade --formula --yes --quiet || FAILURES+=("brew upgrade")
echo

echo "→ Upgrading casks (--greedy)..."
brew upgrade --cask --greedy --yes --quiet --no-quit || FAILURES+=("brew upgrade --cask --greedy")
echo

echo "→ Checking for missing dependencies (informational)..."
# Non-zero exit = found missing deps, not a script failure.
MISSING_OUTPUT=$(brew missing)
if [ -n "$MISSING_OUTPUT" ]; then
    echo "$MISSING_OUTPUT"
    WARNINGS+=("brew missing: found missing dependencies")
else
    echo "  (none)"
fi
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

echo "→ Brewfile drift check (informational)..."
if [ -f "$HOMEBREW_BUNDLE_FILE" ]; then
    if ! brew bundle check --verbose; then
        WARNINGS+=("Brewfile drift vs $HOMEBREW_BUNDLE_FILE")
    fi
else
    echo "  (Brewfile not found at $HOMEBREW_BUNDLE_FILE)"
fi
echo

echo "========================================"
echo "  Post-run inventory"
echo "========================================"
echo

echo "→ Pinned formulae (intentionally held back):"
PINNED=$(brew list --pinned)
[ -n "$PINNED" ] && echo "$PINNED" || echo "  (none)"
echo

echo "→ Casks tracked as :latest (brew has no version info):"
LATEST_CASKS=$(brew list --cask --versions | awk '$2=="latest"{print $1}')
[ -n "$LATEST_CASKS" ] && echo "$LATEST_CASKS" || echo "  (none)"
echo

echo "→ Started services (restart any whose formula was upgraded):"
brew services list | awk 'NR==1 || $2=="started"'
echo

echo "========================================"
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

[ ${#FAILURES[@]} -gt 0 ] && exit 1
exit 0
