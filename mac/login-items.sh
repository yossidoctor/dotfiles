#!/usr/bin/env bash
# Idempotent login items — re-runnable on every ./install.
# LaunchServices stores these in an opaque backgrounditems.btm; the supported
# editing surface is System Events' login-item AppleScript, so each app is added
# only if not already present (name match against the existing login-item list).
# AeroSpace is not here: aerospace.toml's start-at-login registers it itself.
set -uo pipefail

apps=(
  /Applications/BetterCmdTab.app
  /Applications/noTunes.app
)

# Touching System Events makes macOS fire an "App Background Activity" notice on
# every run. The stamp records the app set last registered; skipping the whole
# AppleScript block when it matches avoids the notice. Stamp tracks intent, not
# live login-item state — a manually-removed item won't be re-added until reset.
stamp="${XDG_CACHE_HOME:-$HOME/.cache}/dotfiles/login-items.stamp"
want="$(printf '%s\n' "${apps[@]}" | sort)"
if [ -f "$stamp" ] && [ "$(cat "$stamp")" = "$want" ]; then
  exit 0
fi

if ! existing="$(osascript -e 'tell application "System Events" to get the name of every login item')"; then
  echo "login-items: cannot read login items — grant System Events automation permission and re-run" >&2
  exit 1
fi
# System Events returns ", "-separated; collapse the separator only, so a name
# that itself contains spaces still matches.
existing="$(printf '%s' "$existing" | sed 's/, /,/g')"

fail=0
for app in "${apps[@]}"; do
  name="$(basename "$app" .app)"
  case ",$existing," in
    *",$name,"*) continue ;;
  esac
  if ! osascript -e "tell application \"System Events\" to make login item at end with properties {path:\"$app\", hidden:false}" >/dev/null; then
    echo "login-items: failed to add $name — grant System Events automation permission and re-run" >&2
    fail=1
    continue
  fi
  echo "added login item: $name"
done

# The stamp is written only on full success, so a permission failure is retried
# on the next run instead of being silently latched.
[ "$fail" = 0 ] || exit 1
mkdir -p "$(dirname "$stamp")"
printf '%s' "$want" > "$stamp"
