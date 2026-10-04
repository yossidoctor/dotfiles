#!/bin/bash
# test-harness.sh — screen recording, stills and an input log around an
# AeroSpace test run, so a result is checked in pixels and a run the user
# touched is detected instead of reported. Protocol: brief the user (what,
# stay off the Mac, seconds, end screen) and get a yes before `start`.
#
#   test-harness.sh start <name> <seconds>   input tap on, one recording per display
#   test-harness.sh snap  <name> <label>     still of every display, for review
#   test-harness.sh stop  <name>             tap off, workspace 1, "TEST DONE" banner,
#                                            waits for the recordings to finish
#   test-harness.sh verdict <name>           input events during the run; CLEAN or TOUCHED
#   test-harness.sh frames  <name>           contact sheets from the recordings, 2 frames/s,
#                                            12 frames (6s) per sheet, for review with an image reader
#   test-harness.sh discard <name>           delete the run's recordings, stills, sheets and log
#
# Files: $AEROSPACE_TEST_DIR/<name>.<display>.mov, <name>.<label>.<display>.png,
# <name>.sheet.<display>.<nn>.png, <name>.input.log (default dir
# /tmp/aerospace-tests). The input log carries a timestamp and the event type
# only (keyDown, mouseMoved, leftMouseDown, rightMouseDown, scrollWheel), never
# a key code. Recordings are `screencapture -v -V <seconds>`: fixed length, no
# early stop (SIGINT is ignored, and a killed recorder writes no file), so size
# <seconds> to the run and `stop` waits the remainder, saying how long.
# Every recording is deleted with `discard` once reviewed; nothing here is
# kept. The input tap runs inside Hammerspoon through `hs -c` (hs.ipc is
# loaded by hammerspoon/init.lua), stills are `screencapture -x`, and `frames`
# is the one step that needs ffmpeg (brew/Brewfile). The `hs` bridge has been seen to stop
# answering (observed 2026-10-04 after a run was killed mid-call), so every
# call here is given 5s and then fails loud with the recovery command, instead
# of hanging the run.
set -euo pipefail

cmd="${1:-}"; name="${2:-}"
[ -n "$cmd" ] && [ -n "$name" ] || { sed -n '2,12p' "$0" >&2; exit 2; }
dir="${AEROSPACE_TEST_DIR:-/tmp/aerospace-tests}"
log="$dir/$name.input.log"
HS=/opt/homebrew/bin/hs
AS=/opt/homebrew/bin/aerospace

hs_call() {
  local tmp pid i=0
  tmp=$(mktemp)
  "$HS" -c "$1" >"$tmp" 2>/dev/null & pid=$!
  while kill -0 "$pid" 2>/dev/null && [ $i -lt 50 ]; do sleep 0.1; i=$((i+1)); done
  if kill -0 "$pid" 2>/dev/null; then
    kill "$pid" 2>/dev/null; rm -f "$tmp"
    echo "test-harness: Hammerspoon bridge not answering; recover with: killall Hammerspoon; open -g -a Hammerspoon" >&2
    return 1
  fi
  tail -n 1 "$tmp"; rm -f "$tmp"
}

displays=$(hs_call 'return #hs.screen.allScreens()')

case "$cmd" in
  start)
    seconds="${3:?seconds}"
    mkdir -p "$dir"; : > "$log"
    hs_call "
      _aeroTestLog = io.open('$log', 'a'); _aeroTestLog:setvbuf('no')
      local t = hs.eventtap.event.types
      local names = { [t.keyDown]='keyDown', [t.mouseMoved]='mouseMoved', [t.leftMouseDown]='leftMouseDown', [t.rightMouseDown]='rightMouseDown', [t.scrollWheel]='scrollWheel' }
      _aeroTestTap = hs.eventtap.new({ t.keyDown, t.mouseMoved, t.leftMouseDown, t.rightMouseDown, t.scrollWheel }, function(e)
        _aeroTestLog:write(string.format('%.3f %s\n', hs.timer.secondsSinceEpoch(), names[e:getType()] or e:getType()))
        return false
      end):start()
      return 'tap on'" >/dev/null
    for d in $(seq 1 "$displays"); do
      screencapture -v -V "$seconds" -x -D "$d" "$dir/$name.$d.mov" >/dev/null 2>&1 &
    done
    printf '%s START %s displays=%s seconds=%s\n' "$(date +%s.%N | cut -c1-14)" "$name" "$displays" "$seconds" >> "$log"
    ;;
  snap)
    label="${3:?label}"
    for d in $(seq 1 "$displays"); do
      screencapture -x -D "$d" "$dir/$name.$label.$d.png"
    done
    printf '%s SNAP %s\n' "$(date +%s.%N | cut -c1-14)" "$label" >> "$log"
    ;;
  stop)
    hs_call "if _aeroTestTap then _aeroTestTap:stop(); _aeroTestTap = nil end; if _aeroTestLog then _aeroTestLog:close(); _aeroTestLog = nil end; return 'tap off'" >/dev/null
    printf '%s STOP\n' "$(date +%s.%N | cut -c1-14)" >> "$log"
    "$AS" workspace 1 >/dev/null 2>&1 || true
    hs_call 'hs.notify.new({ title = "TEST DONE", informativeText = "AeroSpace test finished, the Mac is yours" }):send(); return 1' >/dev/null
    started=$(awk '/ START /{print $1; exit}' "$log"); budget=$(awk '/ START /{sub("seconds=", "", $NF); print $NF; exit}' "$log")
    remaining=$(awk -v s="$started" -v b="$budget" -v now="$(date +%s)" 'BEGIN{r = s + b - now; if (r < 0) r = 0; printf "%d", r}')
    echo "test-harness: waiting ${remaining}s for the recording to finish (fixed ${budget}s budget)"
    while pgrep -f "screencapture -v .* $dir/$name\." >/dev/null; do sleep 1; done
    ;;
  frames)
    for mov in "$dir/$name".*.mov; do
      d=${mov##*.}; d=${mov%.mov}; d=${d##*.}
      ffmpeg -loglevel error -y -i "$mov" -vf "fps=2,scale=640:-1,tile=4x3" "$dir/$name.sheet.$d.%02d.png"
    done
    ls -- "$dir/$name".sheet.*.png
    ;;
  verdict)
    events=$(grep -v -E ' (START|SNAP|STOP)' "$log" || true)
    if [ -z "$events" ]; then echo "CLEAN: no user input during $name"; else
      echo "TOUCHED: $(printf '%s\n' "$events" | wc -l | tr -d ' ') input events during $name"; printf '%s\n' "$events"; exit 1; fi
    ;;
  discard)
    rm -f -- "$dir/$name".*.mov "$dir/$name".*.png "$log"
    echo "test-harness: $name discarded, $(ls -A "$dir" | wc -l | tr -d ' ') files left in $dir"
    ;;
  *) sed -n '2,12p' "$0" >&2; exit 2 ;;
esac
