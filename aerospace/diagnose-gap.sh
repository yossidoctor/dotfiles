#!/usr/bin/env bash
# Evidence capture for a visible tiling gap (empty half-screen / sliced
# layout). Run it THE MOMENT a gap is on screen — it separates the three
# #1615 failure modes documented in docs/aerospace/RETILE-DELAY.md:
#
#   stale layout — tree matches the window server; the aerospace connection
#                  this script opens forces refreshModel+layoutWorkspaces
#                  and heals the gap by itself (the "poke half"),
#   ghost node   — tree holds a window-id the window server doesn't; only
#                  `close --window-id` removes it, and nothing does that
#                  automatically (see the 2026-07-29 incident in
#                  docs/aerospace/RETILE-DELAY.md — reap-ghosts.sh only logs candidates),
#   phantom tile — a minimized window AeroSpace still tiles (blocked
#                  minimize-detection, #1615): the gap is its invisible
#                  slot; reap-ghosts.sh auto-floats these (its header has
#                  the full story),
#   GC hang      — the list-windows call itself stalls multi-second: the
#                  daemon is stuck querying an unresponsive app (the
#                  maintainer-described internal GC pass; nothing local can
#                  unstick it, but naming the moment + running apps is the
#                  evidence docs/aerospace/RETILE-DELAY.md says is missing).
#
# Order matters: the window-server snapshot is taken FIRST, because any
# aerospace CLI connection can heal the gap before it's recorded. The
# aerospace call runs with a 5s watchdog so a GC hang yields a verdict
# instead of a hung script. Full snapshots land in
# ~/.cache/aerospace/diagnose-<timestamp>.log; verdict prints to stdout,
# and with --notify also lands as a macOS notification — that flag exists
# for the alt-shift-d binding in aerospace.toml, so the capture is one
# keystroke at the moment a gap is on screen, no terminal needed.
# Uses reap-ghosts.sh's compiled window-oracle (builds it the same way if
# missing); its ALL line is the window-server read taken before and after the
# aerospace call, and its PHANTOM line the minimize verdict.
set -euo pipefail

NOTIFY=0
[ "${1:-}" = "--notify" ] && NOTIFY=1
verdict() {
  echo "VERDICT: $1"
  echo "$2"
  if [ "$NOTIFY" = 1 ]; then
    /usr/bin/osascript -e "display notification \"$(printf '%s' "$2" | head -c 200)\" with title \"diagnose-gap: $1\"" >/dev/null 2>&1 || true
  fi
}

AS=/opt/homebrew/bin/aerospace
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/aerospace"
BIN="$CACHE/bin/window-oracle"
ts=$(date '+%Y%m%d-%H%M%S')
LOG="$CACHE/diagnose-$ts.log"
mkdir -p "$CACHE/bin"

ids_of() { printf '%s\n' "$1" | /usr/bin/awk -v k="$2" '$1 == k { $1 = ""; print }' | tr ' ' '\n' | /usr/bin/awk 'NF'; }

src="$DIR/window-oracle.swift"
if [ ! -x "$BIN" ] || [ "$src" -nt "$BIN" ]; then
  tmp=$(mktemp "$CACHE/bin/.window-oracle-XXXXXX")
  xcrun swiftc -O -o "$tmp" "$src"
  mv -f "$tmp" "$BIN"
fi

cg_before=$(ids_of "$("$BIN")" ALL | sort -u)
{
  echo "=== diagnose-gap $ts ==="
  echo "--- window-server ids (before any aerospace call) ---"
  printf '%s\n' "$cg_before"
} >> "$LOG"

t0=$(perl -MTime::HiRes=time -e 'printf "%d", time()*1000')
tree_json=""
tmp=$(mktemp)
"$AS" list-windows --all --json > "$tmp" 2>&1 &
as_pid=$!
elapsed=0
while kill -0 "$as_pid" 2>/dev/null && [ "$elapsed" -lt 5000 ]; do
  sleep 0.1
  now=$(perl -MTime::HiRes=time -e 'printf "%d", time()*1000')
  elapsed=$((now - t0))
done

if kill -0 "$as_pid" 2>/dev/null; then
  kill "$as_pid" 2>/dev/null || true
  {
    echo "--- aerospace list-windows: NO RESPONSE after ${elapsed}ms (killed) ---"
    echo "--- running apps at this moment ---"
    ps -axo pid,pcpu,state,comm | sort -k2 -rn | head -25
  } >> "$LOG"
  rm -f "$tmp"
  verdict "GC HANG" "Daemon did not answer within 5s — stuck querying an unresponsive app (#1615, docs/aerospace/RETILE-DELAY.md 'What's actually happening'). Top CPU processes captured in $LOG — check which app is hung/spinning right now."
  exit 0
fi
wait "$as_pid" || true
tree_json=$(cat "$tmp"); rm -f "$tmp"
now=$(perl -MTime::HiRes=time -e 'printf "%d", time()*1000')
call_ms=$((now - t0))

tree_ids=$(printf '%s\n' "$tree_json" | /usr/bin/grep -o '"window-id" : [0-9]*' | /usr/bin/grep -o '[0-9]*' | sort -u)
ghosts=$(comm -23 <(printf '%s\n' "$tree_ids") <(printf '%s\n' "$cg_before"))
sleep 0.3
cg_after=$(ids_of "$("$BIN")" ALL | sort -u)

{
  echo "--- aerospace tree (call took ${call_ms}ms) ---"
  printf '%s\n' "$tree_json"
  echo "--- ghosts (tree ids absent from window server) ---"
  printf '%s\n' "${ghosts:-none}"
  echo "--- window-server ids (after) ---"
  printf '%s\n' "$cg_after"
} >> "$LOG"

tiled=$("$AS" list-windows --workspace visible --format '%{window-id} %{window-layout}' 2>/dev/null | /usr/bin/awk '$2 != "floating" { print $1 }' | tr '\n' ' ')
phantoms=""
[ -n "${tiled// /}" ] && phantoms=$(ids_of "$("$BIN" $tiled 2>/dev/null || true)" PHANTOM)
{
  echo "--- phantom tiles (visible-workspace, minimized but still tiled) ---"
  printf '%s\n' "${phantoms:-none}"
} >> "$LOG"

echo "aerospace answered in ${call_ms}ms; full snapshots in $LOG"
if [ -n "$phantoms" ]; then
  verdict "PHANTOM TILE(S)" "Minimized window(s) still holding a tiling slot — the gap IS their invisible tile (#1615 blocked minimize-detection): $(printf '%s ' $phantoms). reap-ghosts.sh floats these automatically on the next focus event; happening now via this run's poke. If the gap persists, float manually: aerospace layout floating --window-id <id>."
elif [ -n "$ghosts" ]; then
  verdict "GHOST NODE(S)" "Tree holds ids the window server doesn't: $(printf '%s ' $ghosts). Nothing closes these automatically (close-based reaping banned — 2026-07-29 incident, docs/aerospace/RETILE-DELAY.md). After confirming an id is truly dead: aerospace close --window-id <id>. Candidates log: ~/.cache/aerospace/reap.log."
elif [ "$call_ms" -ge 1000 ]; then
  verdict "SLOW DAEMON (${call_ms}ms)" "GC-hang territory, but it answered. This connection itself forced a relayout; if the gap just healed, it was a stale layout behind a slow daemon."
else
  verdict "NO GHOSTS, DAEMON FAST (${call_ms}ms)" "Gap just healed = stale layout (this call forced the relayout). Gap STILL visible = model and screen disagree: frames not applied (app ignoring AX resize, or the unmeasured redraw layer — docs/aerospace/RETILE-DELAY.md). Recovery: alt-shift-semicolon then r (flatten-workspace-tree)."
fi
