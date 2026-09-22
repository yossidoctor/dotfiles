#!/bin/bash
# Idempotent `defaults write` — re-runnable on every ./install.
#
# Every write is documented in the two comment lines above it:
#   1. where the setting lives, then Apple's default. A path starting with a
#      pane name is System Settings (e.g. "Desktop & Dock › Dock › <label>");
#      an app path names the app ("Finder › Settings › Advanced › <label>");
#      "hidden" means no UI exists for it. Labels are the ones the installed
#      macOS build shows (Apple's macOS 27 user guide and the build's own
#      Finder Localizable.strings).
#   2. what the value below does.
# An Apple key stays only while its name occurs in the macOS 27.0 binary that
# reads it (dyld shared cache, Dock, Finder, screencaptureui, sharingd, icdd,
# TMHelperAgent); a key absent from every binary is a no-op and is not here.
# mru-spaces is the one exception, kept on the strength of its Settings toggle.
#
# Spotlight indexing is disabled in mac/disable-spotlight.sh (needs sudo).
#
# The stamp records this script's own hash after a fully-successful run, so an
# unchanged re-run skips everything — including the Transmission quit and the
# Dock/Finder restarts at the end. A manually-flipped setting is re-applied
# only after this script changes (stamp tracks intent, not live state).
set -uo pipefail

stamp="${XDG_CACHE_HOME:-$HOME/.cache}/dotfiles/defaults.stamp"
self_hash="$(md5 -q "${BASH_SOURCE[0]}")"
if [ -f "$stamp" ] && [ "$(cat "$stamp")" = "$self_hash" ]; then
  echo "macOS defaults unchanged since last apply — skipping."
  exit 0
fi

# Count individual write failures instead of swallowing them behind an
# unconditional success message. Two causes on this machine: a domain whose
# plist carries the com.apple.macl TCC attribute (com.apple.universalaccess),
# and the sandboxed-app container paths (Safari, Mail), which the terminal can
# only reach with Full Disk Access.
failures=0
trap 'failures=$((failures + 1))' ERR

# ─────────────────────────────────────────────────────────────────────────────
# Dock
# ─────────────────────────────────────────────────────────────────────────────
# Desktop & Dock › Dock › Size (slider, 16–128 px) · default 48
# Icon edge length in points.
defaults write com.apple.dock tilesize -int 36

# Desktop & Dock › Dock › "Automatically hide and show the Dock" · default off
# The Dock stays off-screen until the pointer reaches its edge; the two timing
# keys below shape that reveal.
defaults write com.apple.dock autohide -bool true

# hidden · default 0.2
# Seconds the pointer must rest at the screen edge before the hidden Dock slides in.
defaults write com.apple.dock autohide-delay -float 0

# hidden · default 0.5
# Duration in seconds of the Dock's slide-in/out animation (0 = instant).
defaults write com.apple.dock autohide-time-modifier -float 0.2

# Desktop & Dock › Dock › "Show suggested and recent apps in Dock" · default on
# Removes the recent-apps section at the Dock's right end.
defaults write com.apple.dock show-recents -bool false

# Desktop & Dock › Dock › "Animate opening applications" · default on
# No icon bounce while an app launches.
defaults write com.apple.dock launchanim -bool false

# Desktop & Dock › Dock › "Minimized windows animation" · default Genie
# Scale is the shorter animation. The third accepted value, suck, has no UI entry.
defaults write com.apple.dock mineffect -string "scale"

# ─────────────────────────────────────────────────────────────────────────────
# Mission Control & Spaces — AeroSpace owns window layout, so native tiling,
# edge triggers and Space reordering are all off.
# ─────────────────────────────────────────────────────────────────────────────
# Desktop & Dock › Mission Control › "Automatically rearrange Spaces based on most recent use" · default on
# Spaces keep a fixed order, so AeroSpace workspace ↔ Space mappings stay stable.
# The key name is not a literal in the Dock binary, so whether this write (as
# opposed to the toggle) still lands is unverified.
defaults write com.apple.dock mru-spaces -bool false

# Desktop & Dock › Mission Control › "Drag windows to top of screen to enter Mission Control" · default on
# A window dragged against the menu bar stays a plain drag.
defaults write com.apple.dock enterMissionControlByTopWindowDrag -bool false

# Desktop & Dock › Mission Control › "Displays have separate Spaces" · default on
# The key is the inverse of the checkbox: false = separate Spaces per display.
# AeroSpace requires this — its APIs mis-handle windows crossing a Space that
# spans displays. Cost: native fullscreen blanks the other monitor, so use
# AeroSpace's fullscreen instead. Takes effect at next login.
defaults write com.apple.spaces spans-displays -bool false

# Desktop & Dock › Windows › "Drag windows to left or right edge of screen to tile" · default on
# Desktop & Dock › Windows › "Drag windows to menu bar to fill screen" · default on
# Desktop & Dock › Windows › "Hold ⌥ key while dragging windows to tile" · default on
# Desktop & Dock › Windows › "Tiled windows have margins" · default on
# Every native tiling trigger off, so a drag near an edge never fights AeroSpace.
defaults write com.apple.WindowManager EnableTilingByEdgeDrag -bool false
defaults write com.apple.WindowManager EnableTopTilingByEdgeDrag -bool false
defaults write com.apple.WindowManager EnableTilingOptionAccelerator -bool false
defaults write com.apple.WindowManager EnableTiledWindowMargins -bool false

# ─────────────────────────────────────────────────────────────────────────────
# Windows & animations
# ─────────────────────────────────────────────────────────────────────────────
# hidden · default 0.2
# Seconds AppKit animates a window resize and a sheet dropping from a title bar.
# AppKit only: SwiftUI-drawn windows ignore it. Takes effect at next login.
defaults write NSGlobalDomain NSWindowResizeTime -float 0.001

# hidden · default 0.5
# Seconds of hovering a window title before its draggable document icon appears.
defaults write NSGlobalDomain NSToolbarTitleViewRolloverDelay -float 0

# hidden · default off
# ⌃⌘-drag anywhere inside a window moves it (move only, no resize). Apps that
# draw their own chrome may ignore it. Takes effect at next login.
defaults write NSGlobalDomain NSWindowShouldDragOnGesture -bool true

# hidden · default on
# Master switch for AppKit's window open/close/zoom animations. AppKit only.
# Takes effect at next login.
defaults write NSGlobalDomain NSAutomaticWindowAnimationsEnabled -bool false

# Desktop & Dock › Dock › "Window title bar double-click action" · default Zoom
# UI label → key value: Fill → Fill, Zoom → Maximize, Minimize → Minimize,
# No Action → None. Fill expands the window to the whole screen; Zoom only
# resizes to the app's preferred size.
defaults write NSGlobalDomain AppleActionOnDoubleClick -string "Fill"

# ─────────────────────────────────────────────────────────────────────────────
# Keyboard
# ─────────────────────────────────────────────────────────────────────────────
# hidden · default on
# Holding a key repeats it instead of opening the accent picker (é è ê).
# Per-app: an app already running keeps the old behaviour until relaunched.
defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false

# Keyboard › "Delay Until Repeat" (slider Long … Short) · default 68
# Ticks of 15 ms before a held key starts repeating. 15 is the slider's Short
# end (225 ms). Takes effect at next login.
defaults write NSGlobalDomain InitialKeyRepeat -int 15

# Keyboard › "Key Repeat Rate" (slider Slow … Fast) · default 6
# Ticks of 15 ms between repeats. 1 (15 ms) is below the slider's Fast end of
# 2; touching the slider rewrites it to 2. Takes effect at next login.
defaults write NSGlobalDomain KeyRepeat -int 1

# Keyboard › "Keyboard navigation" · default off (0)
# 2 = on: Tab and Shift-Tab reach every control, not only text fields and
# lists. 2 is the value the toggle itself writes. Distinct from Accessibility ›
# Keyboard › Full Keyboard Access. Apps read it at launch.
defaults write NSGlobalDomain AppleKeyboardUIMode -int 2

# Keyboard › Keyboard Shortcuts… › Spotlight › "Show Spotlight search" (⌘Space, id 64) · default on
# Keyboard › Keyboard Shortcuts… › Spotlight › "Show Finder search window" (⌥⌘Space, id 65) · default on
# Both unbound: Raycast owns ⌘Space. enabled=false is what turns a shortcut
# off; parameters are [ASCII code, virtual keycode, modifier mask] and
# 65535 = "no key". A bare `defaults write` can't author this nested dict, so
# PlistBuddy does it; Delete-then-Add is idempotent and Delete fails harmlessly
# on a fresh domain. activateSettings -u reloads the bindings without a logout.
shk_domain="$HOME/Library/Preferences/com.apple.symbolichotkeys.plist"
for id in 64 65; do
  /usr/libexec/PlistBuddy "$shk_domain" >/dev/null 2>&1 \
    -c "Delete :AppleSymbolicHotKeys:$id" \
    -c "Add :AppleSymbolicHotKeys:$id:enabled bool false" \
    -c "Add :AppleSymbolicHotKeys:$id:value:type string standard" \
    -c "Add :AppleSymbolicHotKeys:$id:value:parameters array" \
    -c "Add :AppleSymbolicHotKeys:$id:value:parameters:0 integer 65535" \
    -c "Add :AppleSymbolicHotKeys:$id:value:parameters:1 integer 65535" \
    -c "Add :AppleSymbolicHotKeys:$id:value:parameters:2 integer 0" \
    || true
done
/System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u 2>/dev/null || true

# ─────────────────────────────────────────────────────────────────────────────
# Text input — substitution that corrupts code and config typed or pasted into
# native text fields. NSGlobalDomain is the fallback: an app whose Edit ›
# Substitutions menu was ever toggled keeps its own copy, and non-AppKit apps
# (Electron, Qt) ignore these entirely.
# ─────────────────────────────────────────────────────────────────────────────
# Keyboard › Text Input › Edit… › "Use smart quotes and dashes" · default on
# Straight quotes stay straight.
defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false

# Keyboard › Text Input › Edit… › "Use smart quotes and dashes" · default on
# "--" stays two hyphens instead of becoming an em dash.
defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false

# Keyboard › Text Input › Edit… › "Add period with double-space" · default on
# Two spaces stay two spaces.
defaults write NSGlobalDomain NSAutomaticPeriodSubstitutionEnabled -bool false

# Keyboard › Text Input › Edit… › "Capitalize words automatically" · default on
# No auto-capital at the start of a line — identifiers keep their case.
defaults write NSGlobalDomain NSAutomaticCapitalizationEnabled -bool false

# Keyboard › Text Input › Edit… › "Correct spelling automatically" · default on
# No silent autocorrect of words it does not recognise.
defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false

# Keyboard › Text Input › Edit… › "Show inline predictive text" · default on
# No grey ghost-text word prediction ahead of the cursor.
defaults write NSGlobalDomain NSAutomaticInlinePredictionEnabled -bool false

# ─────────────────────────────────────────────────────────────────────────────
# Accessibility — motion & transparency: UI only, never scripted
# ─────────────────────────────────────────────────────────────────────────────
# Accessibility › Display › "Reduce motion" and "Reduce transparency" are set by
# hand. ~/Library/Preferences/com.apple.universalaccess.plist carries the
# com.apple.macl TCC attribute, so cfprefsd rejects a `defaults write` from any
# process without Full Disk Access ("Could not write domain"), and granting FDA
# to the terminal hands it to everything the terminal runs.

# ─────────────────────────────────────────────────────────────────────────────
# Trackpad
# ─────────────────────────────────────────────────────────────────────────────
# Trackpad › Point & Click › "Tap to click" · default off
# Three stores back the one checkbox: the built-in trackpad driver, the
# Bluetooth (Magic Trackpad) driver, and the per-host flag the checkbox itself
# reflects. The per-host one must be written with -currentHost; without it the
# write lands in a store nothing reads. May need a logout to become live.
defaults write com.apple.AppleMultitouchTrackpad Clicking -bool true
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true
defaults -currentHost write NSGlobalDomain com.apple.mouse.tapBehavior -int 1

# Trackpad › Scroll & Zoom › "Natural scrolling" · default on
# Off: content moves opposite to the fingers, scroll-wheel style.
defaults write NSGlobalDomain com.apple.swipescrolldirection -bool false

# ─────────────────────────────────────────────────────────────────────────────
# Sound
# ─────────────────────────────────────────────────────────────────────────────
# Sound › "Play feedback when volume is changed" · default on
# No pop sound on each volume key press.
defaults write NSGlobalDomain com.apple.sound.beep.feedback -bool false

# ─────────────────────────────────────────────────────────────────────────────
# Save dialogs
# ─────────────────────────────────────────────────────────────────────────────
# hidden · default on
# A new document's first Save panel points at a local folder, not iCloud Drive.
# NSDocument-based apps only.
defaults write NSGlobalDomain NSDocumentSaveNewDocumentsToCloud -bool false

# hidden (the panel's own disclosure triangle) · default off
# Save panels open expanded, with the full file browser and sidebar. AppKit
# reads one of the two spellings depending on the panel; both are set. An app
# whose triangle was ever clicked keeps its own copy.
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode2 -bool true

# ─────────────────────────────────────────────────────────────────────────────
# Screenshots — read by screencaptureui at each capture, no restart needed.
# ─────────────────────────────────────────────────────────────────────────────
# hidden (⇧⌘5 › Options has no format entry) · default png
# File format. Also accepted: pdf, tiff, heic, gif, bmp, psd, tga.
defaults write com.apple.screencapture type jpg

# ⇧⌘5 › Options › Save to · default Desktop
# The folder must exist, or captures fall back to the Desktop.
mkdir -p "$HOME/Screenshots"
defaults write com.apple.screencapture location "$HOME/Screenshots"

# ─────────────────────────────────────────────────────────────────────────────
# Finder
# ─────────────────────────────────────────────────────────────────────────────
# Finder › View › as List · default icnv (Icons)
# View for folders with no saved view of their own. icnv Icons, Nlsv List,
# clmv Columns, glyv Gallery.
defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"

# Finder › Settings › Advanced › Keep folders on top: "In windows when sorting by name" · default off
# Folders sort above files.
defaults write com.apple.finder _FXSortFoldersFirst -bool true

# Finder › Settings › Advanced › "Show warning before changing extension" · default on
# No confirmation dialog when renaming changes an extension.
defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false

# Finder › Settings › Advanced › "When performing a search:" · default SCev (Search This Mac)
# SCcf Search the Current Folder, SCsp Use the Previous Search Scope.
defaults write com.apple.finder FXDefaultSearchScope -string "SCcf"

# hidden · default off
# The window title shows the folder's full POSIX path instead of its name.
defaults write com.apple.finder _FXShowPosixPathInTitle -bool true

# Finder › Settings › General › "New Finder windows show:" · default Recents
# PfHm Home, PfDe Desktop, PfDo Documents, PfCm Computer, PfVo a volume,
# PfLo another folder (then NewWindowTargetPath holds its file:// URL).
defaults write com.apple.finder NewWindowTarget -string "PfHm"

# Finder › Settings › Advanced › "Show all filename extensions" · default off
# Every file shows its extension, overriding per-file "hide extension".
defaults write NSGlobalDomain AppleShowAllExtensions -bool true

# Finder › View › Show Path Bar (⌥⌘P) · default off
# Breadcrumb bar at the bottom of each window.
defaults write com.apple.finder ShowPathbar -bool true

# Finder › View › Show Status Bar (⌘/) · default off
# Item count and free space at the bottom of each window.
defaults write com.apple.finder ShowStatusBar -bool true

# hidden · default off
# Adds Finder › Quit Finder (⌘Q). Quitting Finder also hides the desktop icons.
defaults write com.apple.finder QuitMenuItem -bool true

# Finder › Settings › Advanced › "Remove items from the Trash after 30 days" · default off
# Trash empties itself of anything older than 30 days.
defaults write com.apple.finder FXRemoveOldTrashItems -bool true

# Finder › Settings › Sidebar › Recent Tags · default on
# No "Recent Tags" section in the sidebar.
defaults write com.apple.finder ShowRecentTags -bool false

# hidden · default off
# No .DS_Store files on network volumes (SMB/AFP/NFS). Local and USB volumes
# still get them; no key covers USB on this build.
defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true

# ─────────────────────────────────────────────────────────────────────────────
# Networking
# ─────────────────────────────────────────────────────────────────────────────
# hidden · default off
# sharingd browses AirDrop peers on every interface, wired Ethernet included,
# not only Wi-Fi/AWDL.
defaults write com.apple.NetworkBrowser BrowseAllInterfaces -bool true

# ─────────────────────────────────────────────────────────────────────────────
# Safari — sandboxed, so its preferences live in its container, and the
# container is TCC-protected: the writes below need the terminal to hold Full
# Disk Access and fail loudly (counted) without it. The bare domain
# `com.apple.Safari` is worse: without FDA it silently lands in
# ~/Library/Preferences, which Safari never reads, and reads back as if it
# had worked. Safari picks the values up through cfprefsd while running.
# ─────────────────────────────────────────────────────────────────────────────
SAFARI="$HOME/Library/Containers/com.apple.Safari/Data/Library/Preferences/com.apple.Safari"

# Safari › Settings › Search › "Include Safari Suggestions" · default on
# Typed text is not sent to Apple for Music/Maps/News/Wikipedia suggestions.
defaults write "$SAFARI" UniversalSearchEnabled -bool false

# Safari › Settings › Search › "Include search engine suggestions" · default on (key off)
# Inverted key: true suppresses the live completions fetched from the search engine.
defaults write "$SAFARI" SuppressSearchSuggestions -bool true

# Safari › Settings › Advanced › "Use advanced tracking and fingerprinting protection" · default "in Private Browsing"
# Both true = "in all browsing": strips click IDs (gclid, fbclid) from links
# and blocks known tracker loads everywhere. Breaks the odd analytics-gated site.
defaults write "$SAFARI" EnableEnhancedPrivacyInPrivateBrowsing -bool true
defaults write "$SAFARI" EnableEnhancedPrivacyInRegularBrowsing -bool true

# Safari › Settings › General › Homepage · default Apple's start page
# Blank homepage. New tabs/windows are governed separately by NewTabBehavior /
# NewWindowBehavior and left to the UI.
defaults write "$SAFARI" HomePage -string 'about:blank'

# Safari › Settings › General › "Open "safe" files after downloading" · default on
# Downloads stay as files; nothing auto-opens (disk images and archives included).
defaults write "$SAFARI" AutoOpenSafeDownloads -bool false

# Safari › Settings › Privacy › "Allow privacy-preserving measurement of ad effectiveness" · default on
# No Private Click Measurement attribution reports.
defaults write "$SAFARI" WebKitPreferences.privateClickMeasurementEnabled -bool false

# Safari › Settings › Advanced › "Show features for web developers" · default off
# Develop menu and Web Inspector. Lives in the broker domain, a plain plist in
# ~/Library/Preferences, so no FDA involved. Read at Safari launch.
defaults write com.apple.Safari.SandboxBroker ShowDevelopMenu -bool true

# ─────────────────────────────────────────────────────────────────────────────
# Mail — sandboxed like Safari; same container-path rule.
# ─────────────────────────────────────────────────────────────────────────────
MAIL="$HOME/Library/Containers/com.apple.mail/Data/Library/Preferences/com.apple.mail"

# Mail › Settings › General › "Check for new messages:" · default Automatically
# String, as Mail itself writes it: -1 Automatically (push / as mail arrives);
# 1, 5, 15, 30, 60 are minutes. Opening the pane rewrites any other value.
defaults write "$MAIL" PollTime -string "-1"

# ─────────────────────────────────────────────────────────────────────────────
# App Store
# ─────────────────────────────────────────────────────────────────────────────
# App Store › Settings › "In-App Ratings & Reviews" · default on
# App Store apps cannot raise "Enjoying this app? Rate it" prompts. Domain is
# case-sensitive to UserDefaults; the plist on disk is com.apple.AppStore.
defaults write com.apple.AppStore InAppReviewEnabled -int 0

# ─────────────────────────────────────────────────────────────────────────────
# Time Machine
# ─────────────────────────────────────────────────────────────────────────────
# hidden (the prompt's own "Don't Ask Again") · default off
# No "use this disk for Time Machine?" prompt when an unknown volume mounts.
# Read by TMHelperAgent from this user domain.
defaults write com.apple.TimeMachine DoNotOfferNewDisksForBackup -bool true

# ─────────────────────────────────────────────────────────────────────────────
# Advertising
# ─────────────────────────────────────────────────────────────────────────────
# Privacy & Security › Apple Advertising › "Personalized Ads" · default on
# Apple's ads in App Store, News and Stocks are not targeted from account data.
defaults write com.apple.AdLib allowApplePersonalizedAdvertising -int 0

# ─────────────────────────────────────────────────────────────────────────────
# Image Capture
# ─────────────────────────────────────────────────────────────────────────────
# hidden · default off
# Photos does not launch when a camera, iPhone or SD card is connected. Read by
# icdd from the per-host store, so -currentHost is mandatory.
defaults -currentHost write com.apple.ImageCapture disableHotPlug -bool true

# ─────────────────────────────────────────────────────────────────────────────
# System
# ─────────────────────────────────────────────────────────────────────────────
# hidden · default crashreport (dialog shown)
# No Problem Reporter dialog after an app crash; logs are still written.
# Separate from Privacy & Security › Analytics & Improvements, which governs
# sending reports to Apple.
defaults write com.apple.CrashReporter DialogType -string "none"

# ─────────────────────────────────────────────────────────────────────────────
# TextEdit — a plain-text scratch pad
# ─────────────────────────────────────────────────────────────────────────────
# TextEdit › Settings › New Document › Format: Plain text · default Rich text
defaults write com.apple.TextEdit RichText -bool false

# hidden · default on
# ⌘N and launch give a blank untitled document instead of the Open panel.
defaults write com.apple.TextEdit NSShowAppCentricOpenPanelInsteadOfUntitledFile -bool false

# ─────────────────────────────────────────────────────────────────────────────
# noTunes — keys read from UserDefaults in the app's AppDelegate.swift
# ─────────────────────────────────────────────────────────────────────────────
# noTunes README · default none (Music is blocked, nothing opens instead)
# App or URL launched whenever Apple Music tries to open.
defaults write digital.twisted.noTunes replacement /Applications/Spotify.app

# noTunes menu bar icon › right-click › Hide Icon · default off
# The key the menu item writes; no menu bar icon, blocking stays active.
defaults write digital.twisted.noTunes hideIcon -bool true

# ─────────────────────────────────────────────────────────────────────────────
# Cask app defaults
# Transmission: every key below exists in upstream macosx/Defaults.plist
#   https://raw.githubusercontent.com/transmission/transmission/main/macosx/Defaults.plist
# Sparkle: SUSendProfileInfo per sparkle-project.org/documentation/customization.
#
# Transmission rewrites its plist on exit, so a write made while it runs is
# clobbered when it next quits. Quit it BEFORE writing; relaunch after only if it
# was already running. WhatsApp is never force-killed (interrupting a session);
# its key is read on next launch.
# ─────────────────────────────────────────────────────────────────────────────
transmission_was_running=false; pgrep -xq Transmission && transmission_was_running=true
killall Transmission 2>/dev/null || true

# Transmission (cask: transmission) — defaults IS the config mechanism. The
# listening port is NOT here — it lives in ~/Library/Application Support/
# Transmission/settings.json as `peer-port`.
TRANSMISSION=org.m0k.transmission
# Transmission › Settings › Transfers › Adding › "Default location:" (chosen folder) · default ~/Downloads
defaults write "$TRANSMISSION" DownloadFolder -string "$HOME/Downloads"
# Transmission › Settings › Transfers › Adding › "Default location:" popup · default "Same as torrent file" (false)
# true selects the fixed folder above (PrefsController.mm setDownloadLocation:).
defaults write "$TRANSMISSION" DownloadLocationConstant -bool true
# Transmission › Settings › Transfers › Adding › "Display a window when opening a torrent file" · default on
defaults write "$TRANSMISSION" DownloadAsk -bool false
# Transmission › Settings › Transfers › Adding › "Display a window when opening a magnet link" · default on
# Only unlockable while the location popup is a fixed folder.
defaults write "$TRANSMISSION" MagnetOpenAsk -bool false
# Transmission › Settings › Transfers › Management › "Append .part to incomplete files" · default on
defaults write "$TRANSMISSION" RenamePartialFiles -bool true
# Transmission › Settings › Transfers › Adding › "Trash original torrent files" · default off
defaults write "$TRANSMISSION" DeleteOriginalTorrent -bool true
# Transmission › Settings › Transfers › Adding › "Start transfers when added" · default on
defaults write "$TRANSMISSION" AutoStartDownload -bool true
# Transmission › Settings › Transfers › Management › "Stop seeding at ratio:" · default off, 2
# 0.01 stops seeding right after completion. Not 0: libtransmission treats a
# 0 seed ratio as "no limit" (torrent.cc effective_seed_ratio()==0 → check off).
defaults write "$TRANSMISSION" RatioCheck -bool true
defaults write "$TRANSMISSION" RatioLimit -float 0.01
# Transmission › View › Compact View · default off
defaults write "$TRANSMISSION" SmallView -bool true
# Transmission › Settings › General › "Notifications:" · default on
# macOS notification when a transfer completes.
defaults write "$TRANSMISSION" DisplayNotifications -bool true
# Transmission › Settings › General › Prompt user for: › "Quit with active transfers" · default on
defaults write "$TRANSMISSION" CheckQuit -bool false
# First-launch legal alert, and the donate alert's "don't show again" · default shown
defaults write "$TRANSMISSION" WarningLegal -bool false
defaults write "$TRANSMISSION" WarningDonate -bool false

# IINA (cask: iina) — defaults IS the config mechanism; every key below is in
# upstream iina/Preference.swift `defaultPreference`:
#   https://github.com/iina/iina/blob/develop/iina/Preference.swift
# IINA reads through cfprefsd and observes changes live, so no quit is needed.
# Labels are the installed build's Pref*ViewController.strings.
IINA=com.colliderli.iina
# IINA › Preferences › Subtitle › "Preferred language:" · default "" (none)
# ISO 639-2 code, passed to mpv as slang: an English embedded or sidecar track
# is selected on open. Also the language OpenSubtitles searches are made in.
defaults write "$IINA" subLang -string "eng"
# IINA › Preferences › General › "Resume last playback position" · default on
defaults write "$IINA" resumeLastPosition -bool true
# IINA › Preferences › General › "Quit after all windows are closed" · default off
# No windowless IINA left in ⌘-Tab after the last player closes.
defaults write "$IINA" quitWhenNoOpenedWindow -bool true
# IINA › Preferences › UI › "Theme:" · default Dark (0)
# 0 Dark, 2 Light, 4 System.
defaults write "$IINA" themeMaterial -int 0
# IINA › Preferences › General › "Screenshots:" folder · default ~/Pictures/Screenshots
# Same folder com.apple.screencapture writes to above.
defaults write "$IINA" screenshotFolder -string "$HOME/Screenshots"

# Ghostty (cask: ghostty) — real config is ~/.config/ghostty/config, not defaults.
# Karabiner-Elements (cask: karabiner-elements) — real config is
# ~/.config/karabiner/karabiner.json (defaults holds only window geometry).

# Sparkle telemetry opt-out (telemetry ONLY — auto-update left enabled).
# SUSendProfileInfo controls the anonymous system-profile payload Sparkle appends
# to each appcast request. Every domain that carries Sparkle's own
# SUEnableAutomaticChecks key is a Sparkle app, so the set is discovered live
# rather than listed here.
while IFS= read -r d; do
  defaults read "$d" SUEnableAutomaticChecks >/dev/null 2>&1 || continue
  defaults write "$d" SUSendProfileInfo -bool false
done < <(defaults domains | tr ',' '\n' | sed 's/^ //')

# Relaunch Transmission only if it was running before this script quit it.
$transmission_was_running && open -a Transmission 2>/dev/null || true

# Dock and Finder read their domains at launch; everything else above is
# picked up live through cfprefsd or at the next login.
killall Dock Finder 2>/dev/null || true

if [ "$failures" -gt 0 ]; then
  echo "macOS defaults applied with $failures failed write(s) — a Safari/Mail container write needs Full Disk Access for the terminal." >&2
  exit 1
fi
mkdir -p "$(dirname "$stamp")"
printf '%s' "$self_hash" > "$stamp"
echo "macOS defaults applied."
