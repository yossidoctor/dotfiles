#!/usr/bin/env bash
# Idempotent `defaults write` — re-runnable on every ./install.
# Grouped by domain. Every line carries a trailing comment explaining the *why*,
# since `defaults` keys are opaque and the value alone rarely says what it does.
# Spotlight disable lives in mac/disable-spotlight.sh (needs sudo; skips itself
# when indexing is already off).
#
# The stamp records this script's own hash after a fully-successful run, so an
# unchanged re-run skips everything — including the Transmission quit and the
# Dock/Finder/SystemUIServer restarts at the end. A manually-flipped setting is
# re-applied only after this script changes (stamp tracks intent, not live state).
set -uo pipefail

stamp="${XDG_CACHE_HOME:-$HOME/.cache}/dotfiles/defaults.stamp"
self_hash="$(md5 -q "${BASH_SOURCE[0]}")"
if [ -f "$stamp" ] && [ "$(cat "$stamp")" = "$self_hash" ]; then
  echo "macOS defaults unchanged since last apply — skipping."
  exit 0
fi

# Count individual write failures (e.g. TCC-protected domains without Full Disk
# Access) instead of swallowing them behind an unconditional success message.
failures=0
trap 'failures=$((failures + 1))' ERR

# ─────────────────────────────────────────────────────────────────────────────
# Dock
# ─────────────────────────────────────────────────────────────────────────────
defaults write com.apple.dock tilesize -int 36                      # icon size (px)
defaults write com.apple.dock autohide -bool true                   # hide Dock until pointer hits the edge
defaults write com.apple.dock autohide-delay -float 0               # no delay before the Dock hides
defaults write com.apple.dock autohide-time-modifier -float 0.4     # show/hide animation duration (s)
defaults write com.apple.dock show-recents -bool false              # no recent-apps section
defaults write com.apple.dock expose-animation-duration -float 0.1  # Mission Control animation (s)
defaults write com.apple.dock mru-spaces -bool false                # don't auto-reorder Spaces by recent use
defaults write com.apple.dock launchanim -bool false                # no bounce while an app launches
defaults write com.apple.dock show-process-indicators -bool true    # dots under running apps
defaults write com.apple.dock mineffect -string "scale"             # fast scale minimize, not slow genie

# ─────────────────────────────────────────────────────────────────────────────
# Windows & animations
# ─────────────────────────────────────────────────────────────────────────────
defaults write NSGlobalDomain NSWindowResizeTime -float 0.001            # near-instant window resize
defaults write NSGlobalDomain NSToolbarTitleViewRolloverDelay -float 0   # no hover delay on toolbar title
defaults write -g NSWindowShouldDragOnGesture -bool true                 # hold ctrl+cmd and drag any part of a window to move it
defaults write -g NSAutomaticWindowAnimationsEnabled -bool false         # no window open/close animation (e.g. Chrome)
defaults write -g AppleActionOnDoubleClick 'Maximize'                    # double-click title bar maximizes (not zoom/minimize)
defaults write com.apple.spaces spans-displays -bool false               # each display gets its own Spaces ("Displays have separate Spaces" checkbox ON — key name is inverted, false = separate). AeroSpace recommends this; its APIs mis-handle windows crossing the unified Space when true. Cost: native fullscreen blanks the other monitor, so use AeroSpace fullscreen instead.

# ─────────────────────────────────────────────────────────────────────────────
# Keyboard
# ─────────────────────────────────────────────────────────────────────────────
defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false  # hold key = repeat, not accent popup
defaults write NSGlobalDomain InitialKeyRepeat -int 15              # delay before repeat starts (lower = faster)
defaults write NSGlobalDomain KeyRepeat -int 1                      # repeat rate once started (lower = faster)
defaults write NSGlobalDomain AppleKeyboardUIMode -int 3            # full keyboard nav: Tab reaches every control, not just text fields

# Spotlight ⌘Space (symbolichotkey 64): uncheck the box (enabled=0) AND clear the
# key to "None" (params 65535,65535,0 — 65535 is the "no key" sentinel). Raycast
# owns ⌘Space. A bare `defaults write` can't author this nested dict, so PlistBuddy
# does it; Delete-then-Add is idempotent and Delete fails harmlessly on a fresh
# domain. activateSettings -u reloads the binding without a logout.
shk_domain="$HOME/Library/Preferences/com.apple.symbolichotkeys.plist"
/usr/libexec/PlistBuddy "$shk_domain" >/dev/null 2>&1 \
  -c "Delete :AppleSymbolicHotKeys:64" \
  -c "Add :AppleSymbolicHotKeys:64:enabled bool false" \
  -c "Add :AppleSymbolicHotKeys:64:value:type string standard" \
  -c "Add :AppleSymbolicHotKeys:64:value:parameters array" \
  -c "Add :AppleSymbolicHotKeys:64:value:parameters:0 integer 65535" \
  -c "Add :AppleSymbolicHotKeys:64:value:parameters:1 integer 65535" \
  -c "Add :AppleSymbolicHotKeys:64:value:parameters:2 integer 0" \
  || true
/System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u 2>/dev/null || true

# ─────────────────────────────────────────────────────────────────────────────
# Accessibility — motion & transparency
# ─────────────────────────────────────────────────────────────────────────────
defaults write com.apple.universalaccess reduceMotion -bool true        # no zoom/slide window+Space animations
defaults write com.apple.universalaccess reduceTransparency -bool true  # opaque menus/sidebars/Dock, no blur

# ─────────────────────────────────────────────────────────────────────────────
# Trackpad
# ─────────────────────────────────────────────────────────────────────────────
defaults write com.apple.AppleMultitouchTrackpad Clicking -bool true  # tap to click

# ─────────────────────────────────────────────────────────────────────────────
# Sound
# ─────────────────────────────────────────────────────────────────────────────
defaults write NSGlobalDomain com.apple.sound.beep.feedback -bool false  # no beep when volume keys change level

# ─────────────────────────────────────────────────────────────────────────────
# Text input — kill substitution that corrupts pasted code/config
# ─────────────────────────────────────────────────────────────────────────────
defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false   # no curly quotes
defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false    # no em-dashes
defaults write NSGlobalDomain NSAutomaticPeriodSubstitutionEnabled -bool false  # no double-space → period

# ─────────────────────────────────────────────────────────────────────────────
# Save / print dialogs
# ─────────────────────────────────────────────────────────────────────────────
defaults write NSGlobalDomain NSDocumentSaveNewDocumentsToCloud -bool false    # save to disk by default, not iCloud
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true    # expanded save panel (full file browser)
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode2 -bool true   # newer apps use the Mode2 key
defaults write NSGlobalDomain PMPrintingExpandedStateForPrint -bool true       # expanded print panel (full detail)
defaults write NSGlobalDomain PMPrintingExpandedStateForPrint2 -bool true      # newer apps use the Print2 key

# ─────────────────────────────────────────────────────────────────────────────
# Screenshots
# ─────────────────────────────────────────────────────────────────────────────
defaults write com.apple.screencapture type jpg                  # file format (default png)
mkdir -p "$HOME/Screenshots"                                     # location target must exist or it falls back to Desktop
defaults write com.apple.screencapture location "$HOME/Screenshots"  # save here, not the Desktop

# ─────────────────────────────────────────────────────────────────────────────
# Finder
# ─────────────────────────────────────────────────────────────────────────────
defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"         # default to list view (Nlsv)
defaults write com.apple.finder _FXSortFoldersFirst -bool true              # folders above files when sorting
defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false  # no nag dialog on extension rename
defaults write com.apple.finder FXDefaultSearchScope -string "SCcf"         # search the current folder, not the whole Mac
defaults write com.apple.finder _FXShowPosixPathInTitle -bool true          # full POSIX path in the window title bar
defaults write com.apple.finder NewWindowTarget -string "PfHm"              # new windows open Home (PfHm = home path)
defaults write NSGlobalDomain AppleShowAllExtensions -bool true             # always show file extensions
defaults write com.apple.finder ShowPathbar -bool true                      # show the path bar at the bottom
defaults write com.apple.finder ShowStatusBar -bool true                    # show item count / free space
defaults write com.apple.finder QuitMenuItem -bool true                     # ⌘Q quits Finder (also hides desktop icons)
defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true  # no .DS_Store on network shares
defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true      # no .DS_Store on USB volumes

# ─────────────────────────────────────────────────────────────────────────────
# Desktop — show external drives and removable media; hide internal disks and network servers
# ─────────────────────────────────────────────────────────────────────────────
defaults write com.apple.finder ShowExternalHardDrivesOnDesktop -bool true   # external drives on desktop
defaults write com.apple.finder ShowHardDrivesOnDesktop -bool false          # no internal disks on desktop
defaults write com.apple.finder ShowMountedServersOnDesktop -bool false      # no network servers on desktop
defaults write com.apple.finder ShowRemovableMediaOnDesktop -bool true       # USB / SD media on desktop

# ─────────────────────────────────────────────────────────────────────────────
# Networking
# ─────────────────────────────────────────────────────────────────────────────
defaults write com.apple.NetworkBrowser BrowseAllInterfaces -bool true  # AirDrop over every interface (incl. wired Ethernet)

# ─────────────────────────────────────────────────────────────────────────────
# Safari — privacy
# ─────────────────────────────────────────────────────────────────────────────
defaults write com.apple.Safari UniversalSearchEnabled -bool false      # don't send search queries to Apple
defaults write com.apple.Safari SuppressSearchSuggestions -bool true     # no search-suggestion lookups
defaults write com.apple.Safari EnableEnhancedPrivacyInPrivateBrowsing -bool true  # advanced tracking/fingerprinting protection, private windows
defaults write com.apple.Safari EnableEnhancedPrivacyInRegularBrowsing -bool true  # advanced tracking/fingerprinting protection, regular windows
defaults write com.apple.Safari HomePage -string 'about:blank'           # blank home page

# ─────────────────────────────────────────────────────────────────────────────
# Mail
# ─────────────────────────────────────────────────────────────────────────────
defaults write com.apple.mail AddressesIncludeNameOnPasteboard -bool false  # copy bare address, not "Name <addr>"
defaults write com.apple.mail AutoFetch -bool true                          # auto-check for new mail
defaults write com.apple.mail PollTime -string "-1"                         # on push/as-mail-arrives, not a fixed interval

# ─────────────────────────────────────────────────────────────────────────────
# App Store
# ─────────────────────────────────────────────────────────────────────────────
defaults write com.apple.appstore InAppReviewEnabled -int 0  # no in-app rating requests from App Store apps

# ─────────────────────────────────────────────────────────────────────────────
# Time Machine
# ─────────────────────────────────────────────────────────────────────────────
defaults write com.apple.TimeMachine DoNotOfferNewDisksForBackup -bool true  # no prompt to use new disks as backup volume

# ─────────────────────────────────────────────────────────────────────────────
# Advertising
# ─────────────────────────────────────────────────────────────────────────────
defaults write com.apple.AdLib allowApplePersonalizedAdvertising -int 0  # disable personalized ads

# ─────────────────────────────────────────────────────────────────────────────
# Image Capture
# ─────────────────────────────────────────────────────────────────────────────
defaults -currentHost write com.apple.ImageCapture disableHotPlug -bool true  # don't auto-open Photos when a device is plugged in

# ─────────────────────────────────────────────────────────────────────────────
# System
# ─────────────────────────────────────────────────────────────────────────────
defaults write com.apple.CrashReporter DialogType -string "none"  # silence app-crash report dialogs

# ─────────────────────────────────────────────────────────────────────────────
# noTunes — open Spotify when Apple Music tries to launch
# ─────────────────────────────────────────────────────────────────────────────
defaults write digital.twisted.noTunes replacement /Applications/Spotify.app
defaults write digital.twisted.noTunes hideIcon -bool true  # no menubar icon (runs silently)

# ─────────────────────────────────────────────────────────────────────────────
# Cask app defaults — verified on macOS 27.
# Transmission: every key verified against upstream macosx/Defaults.plist
#   https://raw.githubusercontent.com/transmission/transmission/main/macosx/Defaults.plist
# Sparkle: SUSendProfileInfo verified at sparkle-project.org/documentation/customization.
#
# Transmission rewrites its plist on exit, so a write made while it runs is
# clobbered when it next quits. Quit it BEFORE writing; relaunch after only if it
# was already running. WhatsApp is never force-killed (interrupting a session);
# its key is read on next launch.
# ─────────────────────────────────────────────────────────────────────────────
transmission_was_running=false; pgrep -xq Transmission && transmission_was_running=true
killall Transmission 2>/dev/null || true   # quit so the writes below aren't clobbered on exit

# Transmission (cask: transmission) — defaults IS the config mechanism. The
# listening port is NOT here — it lives in ~/Library/Application Support/
# Transmission/settings.json as `peer-port`; `BindPort` here is legacy/unused.
TRANSMISSION=org.m0k.transmission
defaults write "$TRANSMISSION" DownloadFolder -string "$HOME/Downloads"  # default destination
defaults write "$TRANSMISSION" DownloadLocationConstant -bool true       # always use DownloadFolder, don't ask
defaults write "$TRANSMISSION" DownloadAsk -bool false                   # no location prompt on .torrent add
defaults write "$TRANSMISSION" MagnetOpenAsk -bool false                 # no location prompt on magnet
defaults write "$TRANSMISSION" RenamePartialFiles -bool true             # append .part to incomplete files
defaults write "$TRANSMISSION" DeleteOriginalTorrent -bool true          # trash the .torrent after adding
defaults write "$TRANSMISSION" AutoStartDownload -bool true              # start torrents on add
defaults write "$TRANSMISSION" RatioCheck -bool true                     # enable global seed-ratio limit
defaults write "$TRANSMISSION" RatioLimit -float 0.01                    # stop seeding ~immediately after completion; 0.0 means "no limit / seed forever" in libtransmission (torrent.cc: effective_seed_ratio()==0 → check off), so use a tiny non-zero ratio, NOT 0
defaults write "$TRANSMISSION" SmallView -bool true                      # compact transfer rows
defaults write "$TRANSMISSION" DisplayNotifications -bool true           # macOS notification on torrent complete
defaults write "$TRANSMISSION" CheckQuit -bool false                     # no "quit with active transfers?" dialog
defaults write "$TRANSMISSION" WarningLegal -bool false                  # suppress legal/first-run warning
defaults write "$TRANSMISSION" WarningDonate -bool false                 # suppress donate nag

# Ghostty (cask: ghostty) — real config is ~/.config/ghostty/config, not defaults.
# Only the Sparkle telemetry key (set in the loop below) is meaningful here.

# Karabiner-Elements (cask: karabiner-elements) — nothing to set; real config is
# ~/.config/karabiner/karabiner.json (defaults holds only window geometry).

# Sparkle telemetry opt-out (telemetry ONLY — auto-update left enabled).
# SUSendProfileInfo controls the anonymous system-profile payload Sparkle appends
# to each appcast request. Domain set drifts as casks change — re-discover with:
#   for d in $(defaults domains | tr ',' '\n' | sed 's/^ *//'); do \
#     defaults read "$d" 2>/dev/null | grep -q SUEnableAutomaticChecks && echo "$d"; done
SPARKLE_DOMAINS=(
  com.mitchellh.ghostty
  net.freemacsoft.AppCleaner
  org.m0k.transmission
  net.whatsapp.WhatsApp
)
for d in "${SPARKLE_DOMAINS[@]}"; do
  defaults write "$d" SUSendProfileInfo -bool false   # stop the anonymous system-profile telemetry payload
done

# Relaunch Transmission only if it was running before this script quit it.
$transmission_was_running && open -a Transmission 2>/dev/null || true

# Restart affected services so changes apply without a logout.
killall Dock Finder SystemUIServer 2>/dev/null || true

if [ "$failures" -gt 0 ]; then
  echo "macOS defaults applied with $failures failed write(s) — check TCC permissions (e.g. Full Disk Access for com.apple.universalaccess)." >&2
  exit 1
fi
mkdir -p "$(dirname "$stamp")"
printf '%s' "$self_hash" > "$stamp"
echo "macOS defaults applied."
