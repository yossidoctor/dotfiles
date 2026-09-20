#!/usr/bin/env bash
# Fully disable Spotlight indexing on all volumes (Raycast V2 uses its own indexer).
#
# Wired into ./install (shell block) guarded by `|| true`: it needs sudo, so on a
# non-interactive install the sudo prompt fails and the `|| true` skips it without
# aborting the rest of install. Run manually for a guaranteed apply with a TTY for
# sudo:  bash mac/disable-spotlight.sh
set -uo pipefail

# If indexing is already off everywhere, the erase/remove steps would only rebuild
# and re-destroy the index for nothing — skip the whole thing. Reading status
# needs no sudo, so a steady-state ./install never prompts.
mdutil -s -a 2>/dev/null | grep -q "Indexing enabled" || exit 0
sudo mdutil -i off -a    # disable indexing on ALL volumes
sudo mdutil -d -a        # disable Spotlight searches on all volumes
sudo mdutil -E -a        # erase existing indexes
sudo mdutil -X -a        # remove index directories
mdutil -s -a             # report status
