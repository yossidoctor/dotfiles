#!/bin/bash
# Sourced by mac/defaults.sh: `defaults` below shadows the command for the
# `write` verb, so every setting line there compares before it writes, and the
# script reports by key instead of by count.
#
#   defaults [-currentHost] write <domain> <key> <type> <value...>
#     Reads the live value and leaves an equal one alone (no cfprefsd churn, so
#     no app quit and no Dock restart for nothing). A differing value is
#     written, read back, and the domain appended to `written`; a write that
#     fails or reads back wrong appends a `failed: <domain> <key>` line to
#     `failed`. The wanted value is canonicalised by writing it to a scratch
#     plist and reading it back, so every type compares in `defaults read`'s
#     own print form; a -dict-add entry is compared as a block contained in the
#     live dict's print, since the scratch plist holds that one entry. Any
#     other verb passes straight through to the command.
#   check=true   report mode, set by the caller before sourcing: a differing
#                key prints as `<domain> <key>: <live> → <wanted>` and counts
#                in `drift`; nothing is written, quit or restarted.
#   quit_first <domain>
#     Transmission rewrites its plist on exit, so it is quit before the first
#     write to its domain in a run and, if it was running, listed in
#     `relaunch` for the caller to reopen once every write is done.
# Runs under macOS bash 3.2 (README § Script conventions): `$host` is a string,
# because an empty array expands as unbound there under `set -u`.

: "${check:?set to true or false by the caller before sourcing}"
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT
written=''    # one domain per key written this run, space-separated
failed=''     # one "  failed: <domain> <key>" line per miss
relaunch=''   # apps quit_first stopped and found running
quit=''       # apps quit_first already stopped this run
drift=0

# holds <live> <wanted> <type>: the live print form carries the wanted one.
holds() {
  if [ "$3" = -dict-add ]; then
    case "$1" in *"$2"*) return 0 ;; esac
    return 1
  fi
  [ "$1" = "$2" ]
}

quit_first() {
  local app
  case "$1" in org.m0k.transmission) app=Transmission ;; *) return 0 ;; esac
  case " $quit " in *" $app "*) return 0 ;; esac
  quit="$quit $app"
  pgrep -xq "$app" && relaunch="$relaunch $app"
  killall "$app" 2>/dev/null || true
}

# shellcheck disable=SC2086  # $host is empty or -currentHost, split on purpose
defaults() {
  local host=''
  [ "$1" = -currentHost ] && { host=-currentHost; shift; }
  [ "$1" = write ] || { command defaults $host "$@"; return; }
  local domain=$2 key=$3; shift 3
  local live want='' back
  live=$(command defaults $host read "$domain" "$key" 2>/dev/null)
  command defaults write "$scratch/want.plist" "$key" "$@" \
    && want=$(command defaults read "$scratch/want.plist" "$key" 2>/dev/null)
  rm -f "$scratch/want.plist"
  [ "$1" = -dict-add ] && want=$(printf '%s\n' "$want" | sed '1d;$d')
  holds "$live" "$want" "$1" && return 0
  if $check; then
    [ "$1" = -dict-add ] && live="entry $2 differs"
    printf '%s %s: %s → %s\n' "$domain" "$key" \
      "$(printf '%s' "${live:-unset}" | tr -s ' \n' ' ')" "$(printf '%s' "$want" | tr -s ' \n' ' ')"
    drift=$((drift + 1))
    return 0
  fi
  quit_first "$domain"
  if command defaults $host write "$domain" "$key" "$@" \
     && back=$(command defaults $host read "$domain" "$key" 2>/dev/null) \
     && holds "$back" "$want" "$1"; then
    written="$written $domain"
  else
    failed="$failed  failed: $domain $key"$'\n'
  fi
}
