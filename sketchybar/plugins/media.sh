#!/usr/bin/env bash
# media.sh — the now-playing item and its per-source popup.
#
# Two kinds of source feed this, because they are reachable in different ways:
#
#   * The SYSTEM session — whatever currently owns macOS's now-playing slot (a
#     Safari tab, VLC, Spotify when it holds the slot). macOS exposes exactly one
#     of these to third parties, so media-control can never report a second one;
#     that single session arrives here as $TITLE/$ARTIST/$BUNDLE from
#     media-stream.sh. Control Center's multi-row panel uses access no third
#     party gets.
#   * SCRIPTABLE PLAYERS, read through their own AppleScript dictionaries. This
#     is what makes more than one row possible at all: Spotify and VLC each
#     answer for their own state even while another app owns the system session,
#     so a paused Spotify and a playing video can both be listed.
#
# The bar pill shows the system session, since that is the audio actually
# playing. The popup lists every source with a track loaded, so a second player
# is one hover away rather than invisible. A player that IS the system session is
# listed once, not twice.
#
# The pill stays expanded whenever something is playing — a title you have to
# hover for is no use while it is the thing making noise — and collapses to a
# bare glyph when nothing is.
set -uo pipefail

# sketchybar runs scripts with a minimal PATH; media-control and jq live in
# Homebrew's prefix and are both reached below.
export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:/usr/bin:/bin:/usr/sbin:/sbin"

source "$HOME/.config/sketchybar/theme.sh"
source "$HOME/.config/sketchybar/icon_map.sh"

# What the last paint drew. The hover branches need both and cannot ask
# sketchybar: it reports null for a popup item's drawing state, and the pill's
# icon color is a per-app brand tint rather than one comparable value.
SOURCE_COUNT_FILE="${TMPDIR:-/tmp}/sketchybar-media-sources"
PLAYING_FILE="${TMPDIR:-/tmp}/sketchybar-media-playing"
# Exists only while the pointer is on the pill; see the paint at the bottom.
HOVER_FILE="${TMPDIR:-/tmp}/sketchybar-media-hover"

case "$SENDER" in
  mouse.entered)
    # Hover expands the pill, and opens the source list only when there is a
    # second source to choose between — with one source the popup would just
    # repeat the pill.
    # The label is NOT expanded here. Whether the title shows is decided by
    # playback alone — playing shows it, paused hides it — so hovering a paused
    # pill must not unwrap a title the paint deliberately collapsed.
    # The popup opens only when there is a SECOND source to choose between. One
    # source needs no menu: the pill already names it, and a one-row dropdown is
    # just the pill again.
    : > "$HOVER_FILE"
    sketchybar --set "$NAME" background.color="$HOVER_BG"
    if [ "$(cat "$SOURCE_COUNT_FILE" 2>/dev/null || echo 0)" -gt 1 ]; then
      sketchybar --set "$NAME" popup.drawing=on
    fi
    exit 0
    ;;
  mouse.exited)
    # Deliberately does NOT close the popup: the pointer leaves the pill on its
    # way INTO the popup, so closing here would make the rows unreachable.
    # plugins/media-row.sh owns the dismissal, from the rows' own exit.
    #
    # Only the fill is cleared. The label's width belongs to the paint, which
    # sets it from playback state; touching it here is what made a paused pill
    # unwrap on hover and snap shut on exit.
    rm -f "$HOVER_FILE"
    sketchybar --set "$NAME" background.color=0x00000000
    exit 0
    ;;
  media_update | routine)
    # While the popup is open the list is FROZEN. Two things otherwise happen
    # under the pointer: the periodic tick rewrites label.width and collapses
    # the hover mid-gesture, and a change of system session swaps which rows the
    # dedup hides, so the entries appear to reorder while being read. Neither is
    # acceptable in an open menu, and neither loses anything by waiting — the
    # repaint happens as soon as the popup closes.
    #
    # The tick doubles as the popup's backstop. Every event-driven close depends
    # on the pointer crossing an item boundary, and a pointer that leaves the bar
    # by a path that fires no such event would strand the menu open until the
    # next hover. Checking the position here means a stranded popup closes
    # within one update_freq no matter how it was orphaned.
    if [ "$(sketchybar --query media 2>/dev/null | jq -r '.popup.drawing')" = "on" ]; then
      y="$("$HOME/.config/sketchybar/pointer-y" 2>/dev/null || echo 0)"
      if [ "$y" -gt "$POPUP_BOTTOM" ]; then
        sketchybar --set "$NAME" popup.drawing=off
      fi
      exit 0
    fi
    ;;
  mouse.exited.global)
    # Fires whenever the pointer leaves ANY item, including on its way from the
    # pill into the popup — so this must not close blindly, or the popup dies
    # the instant it opens. It asks where the pointer actually is instead, which
    # makes this the general close path: a row's own mouse.exited cannot be
    # relied on, since leaving the popup sideways or quickly fires no row event
    # at all and would leave the menu stranded open.
    rm -f "$HOVER_FILE"
    sketchybar --set "$NAME" background.color=0x00000000

    # The same settle media-row.sh uses, and for a stronger reason: this fires
    # on EVERY item boundary the pointer crosses, so moving from one popup row
    # to the next triggers it mid-flight. Sampling immediately catches the
    # pointer in the gap between two rows and closes the menu underneath a
    # gesture that never left it.
    sleep 0.25

    y="$("$HOME/.config/sketchybar/pointer-y" 2>/dev/null || echo 0)"
    if [ "$y" -gt "$POPUP_BOTTOM" ]; then
      sketchybar --set "$NAME" popup.drawing=off
    fi
    exit 0
    ;;
esac

# Titles are NOT truncated, here or by label.max_chars: the pill and the rows
# both size to their content, so a long track name is shown in full rather than
# cut. The pill grows leftward from the clock and the popup widens to its widest
# row, which is the trade — a wide pill in exchange for never hiding the thing
# the item exists to report.

# The app-font glyph and brand tint for a source, from the bundle id
# media-control reports. WebKit.GPU is the process that owns playback for every
# Safari tab, so a YouTube video arrives under that id rather than Safari's own.
# Sets icon_result and brand_result together, since both key off the same id.
__source_icon() {
  case "$1" in
    com.apple.WebKit.GPU | com.apple.Safari)
      __icon_map "Safari"; brand_result="$BRAND_SAFARI" ;;
    com.spotify.client)
      __icon_map "Spotify"; brand_result="$BRAND_SPOTIFY" ;;
    com.apple.Music)
      __icon_map "Music"; brand_result="$BRAND_MUSIC" ;;
    com.apple.TV)
      __icon_map "TV"; brand_result="$BRAND_TV" ;;
    org.videolan.vlc)
      __icon_map "VLC"; brand_result="$BRAND_VLC" ;;
    com.google.Chrome)
      __icon_map "Google Chrome"; brand_result="$BRAND_CHROME" ;;
    *)
      icon_result=":default:"; brand_result="$BRAND_DEFAULT" ;;
  esac
}

# Each scriptable player as: row item, app name, bundle id, and the two
# AppleScript snippets that read its state and its current title. Adding a
# player is one row here; nothing below is per-player.
#
# Every player is asked whether it is RUNNING first, via System Events: naming a
# stopped app inside `tell application` would launch it, so a bar repaint must
# never address one directly without that guard.
PLAYERS=(
  "media.row.spotify|Spotify|com.spotify.client|player state as string|name of current track & \" — \" & artist of current track"
  "media.row.vlc|VLC|org.videolan.vlc|(playing as string)|name of current item"
)

title="${TITLE:-}"
artist="${ARTIST:-}"
playing="${PLAYING:-}"
bundle="${BUNDLE:-}"

# A media_update carries the session in its environment. Every other sender —
# the routine tick, system_woke, a click repaint — carries nothing, so the
# session is read directly here.
#
# That routine tick is what makes the pill self-healing: media-stream.sh is a
# LaunchAgent whose child does not always survive a sketchybar restart, and
# without a second path to the state the pill would sit blank until the next
# track change. It costs one media-control get per tick — the frequency is a
# balance against that, and the popup-open branch above returns before spending
# it at all.
if [ "$SENDER" != "media_update" ]; then
  eval "$(
    media-control get 2>/dev/null | jq -r '
      @sh "title=\(.title // "") artist=\(.artist // "") playing=\(.playing // false) bundle=\(.bundleIdentifier // "")"
    ' 2>/dev/null
  )"
fi

if [ -n "$artist" ]; then
  label="$title — $artist"
else
  label="$title"
fi

__source_icon "$bundle"
pill_icon="$icon_result"

# Playing draws the source in its own brand color; paused drops to the muted
# grey so a silent player recedes rather than competing with the live one.
if [ "$playing" = "true" ]; then
  color="$brand_result"
  width=dynamic
else
  color="$OVERLAY"
  width=0
fi

args=()
sources=0
playing_row_label=""
playing_row_color=""
playing_row_icon=""

# The system row mirrors the pill: whatever owns the now-playing slot.
if [ -n "$title" ]; then
  sources=$((sources + 1))
  if [ "$playing" = "true" ]; then
    state="$ICON_PAUSE"
  else
    state="$ICON_PLAY"
  fi
  args+=(--set media.row.system
    drawing=on
    icon="$state"
    icon.color="$color"
    label="$label"
    label.color="$TEXT")
else
  args+=(--set media.row.system drawing=off)
fi

for entry in "${PLAYERS[@]}"; do
  IFS='|' read -r row app bundle_id state_script title_script <<< "$entry"

  # A player that already owns the system session is drawn by the row above;
  # listing it again would show the same track twice.
  if [ "$bundle" = "$bundle_id" ] || \
     ! osascript -e "tell application \"System Events\" to (name of processes) contains \"$app\"" 2>/dev/null | grep -q true; then
    args+=(--set "$row" drawing=off)
    continue
  fi

  state="$(osascript -e "tell application \"$app\" to $state_script" 2>/dev/null)"
  __source_icon "$bundle_id"
  case "$state" in
    playing | true) row_color="$brand_result"; row_state="$ICON_PAUSE" ;;
    paused | false) row_color="$OVERLAY"; row_state="$ICON_PLAY" ;;
    *) args+=(--set "$row" drawing=off); continue ;;
  esac

  row_label="$(osascript -e "tell application \"$app\" to $title_script" 2>/dev/null)"
  if [ -z "$row_label" ]; then
    args+=(--set "$row" drawing=off)
    continue
  fi

  sources=$((sources + 1))

  # Remembered for the pill: the first player found actually playing, used when
  # the system session itself is paused. First rather than last so PLAYERS order
  # decides the winner when two are somehow playing at once.
  if [ "$row_color" != "$OVERLAY" ] && [ -z "$playing_row_label" ]; then
    playing_row_label="$row_label"
    playing_row_color="$row_color"
    playing_row_icon="$icon_result"
  fi

  args+=(--set "$row"
    drawing=on
    icon="$row_state"
    icon.color="$row_color"
    label="$row_label")
done

if [ "$sources" -eq 0 ]; then
  sketchybar --set "$NAME" drawing=off popup.drawing=off
  printf '0' > "$SOURCE_COUNT_FILE"
  printf 'false' > "$PLAYING_FILE"
  exit 0
fi

# The pill follows what is AUDIBLE, not what holds the system session. macOS
# leaves the now-playing slot with the last app to claim it, so a video paused
# ten minutes ago still owns it while another player is actually making noise —
# the pill would then show a paused source and call it the current one. If the
# system session is not playing and some scriptable player is, that player takes
# the pill instead.
if [ "$playing" != "true" ] && [ -n "$playing_row_label" ]; then
  label="$playing_row_label"
  color="$playing_row_color"
  pill_icon="$playing_row_icon"
  width=dynamic
  playing=true
fi

# A repaint must not touch label.width while the pointer is on the item: the
# hover branch expanded it, and rewriting it here snaps the pill shut under the
# pointer a second later, which is what made the hover look like it randomly
# gave up. Hover is tracked by a file the hover branches stamp — sketchybar has
# no "is the mouse over this" query, and --query reports background.color as
# null, so neither can answer it.
hovered=off
[ -e "$HOVER_FILE" ] && hovered=on

# Deliberately NOT animated. A paint changes the label's content, and animating
# width on a content change makes the pill visibly grow from nothing every time
# a new track starts or a different app takes the session — most obviously when
# launching a player, where it reads as the bar being broken. Only the hover
# branches above animate, because there the width change IS the gesture.
if [ "$hovered" = on ]; then
  sketchybar --set "$NAME" \
    drawing=on \
    icon="$pill_icon" \
    icon.font="$FONT_APP:Regular:14.0" \
    icon.color="$color" \
    label="$label" \
    "${args[@]}"
else
  sketchybar --set "$NAME" \
    drawing=on \
    icon="$pill_icon" \
    icon.font="$FONT_APP:Regular:14.0" \
    icon.color="$color" \
    label="$label" \
    label.width="$width" \
    "${args[@]}"
fi

printf '%s' "$sources" > "$SOURCE_COUNT_FILE"
printf '%s' "$playing" > "$PLAYING_FILE"

# A repaint triggered by a row's own click clears media-row.sh's pending-close
# stamp: clicking a row makes the pointer leave it briefly, and the deferred
# close that fires from would otherwise shut the popup a moment after the click
# landed.
#
# A popup left open as its second source disappears would strand a menu with
# nothing to choose in it, so it closes when the count drops to one — but never
# on a click's own repaint, which would dismiss the menu as the reward for
# using it.
if [ "$SENDER" = "media_refresh" ]; then
  rm -f "${TMPDIR:-/tmp}/sketchybar-media-popup-leave"
elif [ "$sources" -le 1 ]; then
  sketchybar --set "$NAME" popup.drawing=off
fi
