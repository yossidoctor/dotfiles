#!/bin/bash
# What no script can do, printed last by ./install. Each item is a probe that
# reads the live state and prints its instruction only while it is undone; an
# item with no readable state (TCC grants, toggles with no key) prints on every
# run. Reading the Spotlight list needs sudo, so ./install runs this after
# dotbot, with a TTY; by hand:  bash mac/needs-you.sh
set -uo pipefail
mac=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

echo
echo "== Needs you =="
{
  bash "$mac/spotlight.sh"

  # Restrictions profile: every allow* key the payload sets must read the same
  # from the managed-preferences plist Device Management writes on install.
  payload=$(plutil -extract PayloadContent.0 json -o - "$mac/profiles/privacy-restrictions.mobileconfig")
  plutil -convert json -o - "/Library/Managed Preferences/$USER/com.apple.applicationaccess.plist" 2>/dev/null \
    | jq -e --argjson want "$payload" '. as $live | $want | to_entries | map(select(.key | startswith("allow"))) | all(.value == $live[.key])' >/dev/null \
    || echo "Privacy profile: open mac/profiles/privacy-restrictions.mobileconfig, then System Settings › General › Device Management › Install"

  # UnTrap keeps its options as one JSON blob in Safari's extension store, which
  # only the extension's own import writes; the probe reads that blob and compares.
  untrap_db=("$HOME"/Library/Containers/com.apple.Safari/Data/Library/WebKit/WebExtensions/Default/me.swifter.ytdistract.Extension*/LocalStorage.db)
  sqlite3 "${untrap_db[0]}" "select value from extension_storage where key='untrap_options_state'" 2>/dev/null \
    | jq -e --slurpfile want "$mac/manual/untrap-settings.json" '. as $db | $want[0] | to_entries | all(.value == $db[.key])' >/dev/null \
    || echo "UnTrap: install the Safari extension, then import mac/manual/untrap-settings.json through its settings import"

  # Every local signing key must be a Signing key on one of the gh accounts the
  # identity files name (GH_LOGIN, read by git/credential-helper.sh). Offline,
  # nothing is registered and every key is listed.
  registered=$(for f in "$HOME"/.config/git/identities.d/*.sh; do
    [ -f "$f" ] && GH_TOKEN=$(gh auth token -u "$(. "$f"; echo "$GH_LOGIN")" 2>/dev/null) gh ssh-key list 2>/dev/null
  done | cut -f2)
  for pub in "$HOME"/.config/git/signing/*.pub; do
    [ -f "$pub" ] || continue
    case "$registered" in *"$(cut -d' ' -f2 "$pub")"*) ;; *) echo "GitHub: add $pub as a Signing key on its account" ;; esac
  done

  jq -e '.accounts | length > 0' "$HOME/.claude-swap-backup/sequence.json" >/dev/null 2>&1 \
    || echo "Claude accounts: cswap add <name> for each one"

  echo "Accessibility: allow Hammerspoon, AeroSpace and Karabiner when each first asks"
  echo "Toggles with no key: Privacy & Security › Analytics & Improvements › Share iCloud Analytics off;"
  echo "  Location Services › System Services › Details › Suggestions & Search"
  echo "  and Significant Locations off; Photos › Settings › General › Enhanced Visual Search off;"
  echo "  Safari › Settings › Advanced › Allow Highlights to share web addresses with Apple off"
} 2>&1 | sed 's/^/  /'
