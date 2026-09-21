#!/bin/sh
# Git credential helper: picks the gh CLI account whose token a github.com URL
# gets, from the identity files in ~/.config/git/identities.d/*.sh. Each file
# declares one account — URL_PREFIX (org or user segment of the repo URL),
# GH_LOGIN (the gh account), TREE (a filesystem root whose repos default to it).
# This repo deploys personal.sh there; another layer may deploy its own file, and
# the helper never knows how many there are.
#
# Decision order:
#   1. URL path (git sends it because useHttpPath=true): the identity whose
#      URL_PREFIX matches github.com/<prefix>/... — the right signal for a clone,
#      where no local repo exists yet.
#   2. Filesystem root (`git rev-parse --show-toplevel`, else $PWD): the identity
#      whose TREE contains it — third-party clones, forks.
#   No match fails loud: a repo outside every TREE with an unrouted URL never
#   silently borrows an account, mirroring user.useConfigOnly.
#
# Git invokes this with verb `get` (creds out) or `store`/`erase` (no-op; gh owns
# the token store, so those return before reading a single identity file).
#
# gh is resolved with a Homebrew fallback because git maintenance's launchd
# jobs run with launchd's own PATH, which has no /opt/homebrew/bin; without it
# every hourly prefetch of a private repo fails on "gh auth token".

[ "$1" = "get" ] || exit 0

ID_DIR="$HOME/.config/git/identities.d"

p=
while IFS='=' read -r key val; do
  [ -z "$key" ] && break
  [ "$key" = "path" ] && p="$val"
done
p_lower=$(printf '%s' "$p" | tr '[:upper:]' '[:lower:]')

L=
for f in "$ID_DIR"/*.sh; do
  [ -f "$f" ] || continue
  URL_PREFIX= GH_LOGIN= TREE=
  . "$f"
  case "$p_lower" in
    "$(printf '%s' "$URL_PREFIX" | tr '[:upper:]' '[:lower:]')"/*) L="$GH_LOGIN"; break ;;
  esac
done

if [ -z "$L" ]; then
  root=$(git rev-parse --show-toplevel 2>/dev/null || echo "$PWD")
  for f in "$ID_DIR"/*.sh; do
    [ -f "$f" ] || continue
    URL_PREFIX= GH_LOGIN= TREE=
    . "$f"
    [ -n "$TREE" ] || continue
    case "$root" in
      "$TREE"|"$TREE"/*) L="$GH_LOGIN"; break ;;
    esac
  done
fi

if [ -z "$L" ]; then
  echo "credential-helper: no identity in $ID_DIR routes URL path '$p' or repo '$root' — add an identity file or set credential.helper per repo" >&2
  exit 1
fi

gh_bin=$(command -v gh 2>/dev/null || echo /opt/homebrew/bin/gh)
token=$("$gh_bin" auth token --user "$L" 2>/dev/null)
if [ -z "$token" ]; then
  echo "gh auth token failed for user '$L' — run: gh auth login --user $L" >&2
  exit 1
fi
echo "username=$L"
echo "password=$token"
