#!/usr/bin/env bash
# media-stream.sh — the long-running half of the media item: consumes
# `media-control stream` and triggers sketchybar's media_update event.
#
# It exists as a daemon because sketchybar kills every item script at 60
# seconds, so a stream cannot be an item's `script=`. Installed as a LaunchAgent
# by media-stream-agent.sh.
#
# Three upstream behaviors are handled here, each of which otherwise shows up as
# a wrong or blank pill:
#
#   * The stream's FIRST message is an empty payload ({}), before any real state.
#     Passing it through would blank the item on every start, so a record with no
#     title is dropped rather than published.
#   * `diff` defaults to true: a payload carries only the fields that CHANGED, so
#     a pause event arrives with no title at all. --no-diff makes every payload
#     complete, which costs bandwidth this consumer does not care about and
#     removes the need to hold merge state in shell.
#   * durationMicros can be `inf`, which is not valid JSON and kills a parser
#     mid-stream. --no-artwork drops the 500KB-1MB base64 blob per payload, and
#     duration is never read here, so neither field reaches jq.
#
# A non-zero exit from the adapter is fatal per its own contract (do not
# reinvoke), so the agent's KeepAlive is what restarts this, deliberately not a
# retry loop in here.
set -uo pipefail

export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:/usr/bin:/bin:/usr/sbin:/sbin"

media-control stream --no-diff --no-artwork 2>/dev/null | while IFS= read -r line; do
  [ -z "$line" ] && continue

  # One jq pass emits the four fields as shell-quoted assignments; a record with
  # no title (the empty first message, or a session ending) emits nothing and is
  # skipped without touching the bar.
  # `stream` wraps each record in .payload; `get` returns the same fields at the
  # top level. Reading `.payload // .` accepts either, so this filter stays
  # correct if a caller ever pipes a one-shot `get` through it.
  eval "$(
    printf '%s' "$line" | jq -r '
      (.payload // .) |
      select(.title != null and .title != "") |
      @sh "TITLE=\(.title) ARTIST=\(.artist // "") PLAYING=\(.playing // false) BUNDLE=\(.bundleIdentifier // "")"
    ' 2>/dev/null
  )"

  [ -z "${TITLE:-}" ] && continue

  sketchybar --trigger media_update \
    TITLE="$TITLE" \
    ARTIST="${ARTIST:-}" \
    PLAYING="${PLAYING:-false}" \
    BUNDLE="${BUNDLE:-}"

  unset TITLE ARTIST PLAYING BUNDLE
done
