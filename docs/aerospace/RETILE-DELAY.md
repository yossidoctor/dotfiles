# AeroSpace retile on window close: mechanisms and watchdogs

**TL;DR.** AeroSpace does not re-tile when a window closes (macOS Tahoe and
later, upstream [#1615](https://github.com/nikitabobko/AeroSpace/issues/1615),
open). Every `aerospace` CLI call forces the pending layout pass, so the
workaround is to poke the daemon from every signal a close can emit. The
pokes are Hammerspoon handlers in `hammerspoon/init.lua` (focus change, the
workhorse; app termination) plus the Karabiner Cmd+Q / Cmd+W rules
(`retry-poke.sh`, off the keystroke). Three further failure modes ride the
same bug — ghost nodes, phantom tiles, and a daemon GC hang — and the
Hammerspoon minimize handler heals the second by floating.

Scope: the window-close retile bug and the handlers around it. General
AeroSpace setup is `aerospace.toml` itself; `retry-poke.sh`'s header is the
SoT for its own mechanics, and the Hammerspoon section's comment for its.

## The bug

On macOS 26.x and 27.0, AeroSpace (0.21.2-Beta through 0.21.3-Beta) leaves
the gap of a closed window empty until something forces a refresh. #1615 is
open with no maintainer response and no fix in any release note;
`aerospace subscribe` (0.21.0+) has no window-closed event. Everything here
is a workaround that a future release could make unnecessary or break.

## Root cause, verified against AeroSpace source

The daemon and the `aerospace` CLI talk over a Unix-domain socket.
`Sources/AppBundle/server.swift` (`newConnection`) and
`Sources/AppBundle/layout/refresh.swift` (`runLightSession`): **every**
incoming connection, whatever command it carries — even a read-only
`list-windows` — makes the daemon run `refreshModel` + `layoutWorkspaces`.
The daemon cannot tell a Hammerspoon task from Karabiner from a terminal.

So any `aerospace` CLI call, from anywhere, forces the pending layout pass.
Measured cost: ~14ms per call (50-call average on this machine). Credit:
pottom's 2026-07-11 comment on #1615 identified the effect empirically; the
source read confirms the mechanism.

`runLightSession` also cancels the daemon's in-flight heavy refresh
(`activeRefreshTask?.cancel()`) and reschedules it after the frame relayout,
and only the heavy pass garbage-collects closed windows and detects native
minimize. A dense burst of pokes therefore postpones exactly the work the
ghost and phantom handling waits on: two pokes cover "window still in the
tree" and "window already torn down", and more is worse. This is why
`aerospace.toml` registers no `on-focus-changed` or
`exec-on-workspace-change` callback: one CLI call per focus change, from
Hammerspoon, is the budget.

## What Hammerspoon can and cannot see (measured 2026-10-04, TextEdit)

| macOS event                  | `hs.window.filter` / `hs.application.watcher` | delay   |
|------------------------------|-----------------------------------------------|---------|
| app quit / kill              | `terminated`                                  | ~150ms  |
| window minimized             | `windowMinimized`                             | ~450ms  |
| window unminimized           | `windowUnminimized`                           | ~400ms  |
| focus moved to survivor      | `windowFocused`                               | ~370ms after the close command, retile ~70ms later |
| single window closed (Cmd+W) | nothing: `windowDestroyed` fires only at app quit | — |
| an UNFOCUSED window closed (mouse on its close button) | nothing, on any of the 21 filter events; no focus event either | AeroSpace's own pass resized the survivor within 2s (Terminal), the dead node stayed in `list-windows` until the next poke |
| `hs.window:id()`             | equals the AeroSpace window-id                |         |

The filter is `hs.window.filter.new(true)` (every window): the default
filter drops invisible windows, so a minimized window leaves it and
`windowUnminimized` never fires for it.

## Mechanisms in place

**Focus handler (`windowFocused`).** Closing a window reassigns macOS focus
to the survivor, which fires this event; the handler's
`list-windows --focused` read is the poke, and its answer drives the
fullscreen raise (`FULLSCREEN-ZORDER.md`). Measured end to end: the
survivor's frame grows ~70ms after the read.

**Termination handler (`hs.application.watcher.terminated`).** Cmd+Q, Force
Quit, Dock/menu Quit, `killall`, crashes all end in
`NSWorkspace.didTerminateApplicationNotification`, which this event wraps;
the handler pokes `list-windows --all`. The notification fires at process
exit, which trails window-gone-from-tree by an app-dependent margin (Slack
~950ms, PyCharm ~2.3s, Linear ~0-80ms), so the focus handler normally wins
and this poke is a no-op. It stays as the backstop for the one case that
cannot be safely tested: no other window or app anywhere to receive focus,
where no focus event fires at all.

**Karabiner Cmd+Q and Cmd+W rules (`karabiner/karabiner.json`).** Send the
real keystroke through, then run `retry-poke.sh`: two pokes at 0 and 200ms,
backgrounded so Karabiner's event chain never waits. A keystroke and an OS
notification are independent signals; redundant pokes cost one extra ~14ms
socket call and nothing else.

**Minimize handler (`windowMinimized` / `windowUnminimized`).** Auto-heal
for phantoms, below. **It never closes, kills, or minimizes a window.**
Close-based reaping is banned: an empty oracle read as "no windows exist"
once classified every unfocused window as a ghost and closed four live ones
in one pass (2026-07-29). Layout-changing remediation is the allowed class;
anything stronger is designed with the user before it ships.

## Failure modes

**Stale layout.** The tree is right, the frames are old. Any poke fixes it;
the three poke mechanisms above exist for this.

**Ghost node.** A closed window leaves a dead node that slices the layout.
Only `close --window-id` removes it (`reload-config` and
`flatten-workspace-tree` do not). Observed ghosts are transient: across six
weeks of logs (3976 lines, 887 runs with candidates) the longest-lived id
appeared in 7 consecutive runs, and most cleared within ~80ms on their own,
faster than any callback reacts. Ghosts are never closed.

**Phantom tile.** A window the user minimized stays `h_tiles` in the tree,
holding a slot at full alpha: AeroSpace's native-minimize detection has
stalled. Neither a ghost (the window exists) nor stale layout (the tree
really contains it). `macos-native-minimize` cannot resync the model (its
unminimize branch returns "uncapable of unminimizing windows yet"), so the
heal inside the allowed class is `layout floating --window-id`: the slot
collapses and siblings retile. The handler runs it 1s after
`windowMinimized` if the window is still minimized and `list-windows --all`
still reports it as non-floating; a window AeroSpace already took out of the
tree is absent from that list and left alone. On `windowUnminimized` a
window this handler floated gets `layout tiling --window-id`, so it rejoins
the tree instead of coming back floating (verified: slot collapses on float,
frames restore on re-tile). Detection can stay stalled for hours while the
window stays minimized.

**Daemon GC hang.** The maintainer, closing
[#445](https://github.com/nikitabobko/AeroSpace/issues/445): *"AeroSpace
garbage collects dead windows in a sequential manner, by querying every
application on a system. If any of the applications doesn't respond,
AeroSpace infinitely waits for the application and cannot proceed further."*
This fits the multi-second stalls that reproduce on no schedule and that no
callback wiring changes: the poke arrives in ~90ms and the daemon does not
act on it (worst observed answer 7531ms). Evidence that would
confirm a specific hang: `aerospace debug-windows` or Activity Monitor open
at the moment of the stall, showing which app is unresponsive.

**Frames not applied.** The tree is right while the screen is wrong: the
daemon is not applying frames,
consistent with the GC hang, or a phantom tile. Recovery: alt-shift-semicolon
then `r` (`flatten-workspace-tree`).

## Rejected approaches

- **Continuous poller.** Every poke is a full `refreshModel` +
  `layoutWorkspaces`, so a 200ms poll is ~7% duty cycle of relayout all day
  for a rare event, and each poke cancels the heavy pass the ghost/phantom
  handling needs. Every community workaround in the upstream threads is
  event-driven.
- **AX `kAXUIElementDestroyedNotification`**, directly or through
  Hammerspoon's `windowDestroyed`. A minimal observer registered on both the
  window and the app element (`AXObserverCreate` /
  `AXObserverAddNotification` both `err=0`) never fired on a plain TextEdit
  Cmd+W, and `windowDestroyed` fires only once the app quits (table above).
  Upstream abandoned it for the same reason (#445: "macOS AX callbacks are
  unreliable, and sometimes windows can close but the callback is not
  invoked").
- **Per-focus-change AX scan for phantoms.** Enumerating every app's windows
  over AX on each focus event costs 30-110ms per click and still races
  AeroSpace's own detection; the minimize event is direct and the 1s grace
  lets AeroSpace handle the normal case itself.
- **Compiled Swift helpers + a LaunchAgent.** Hammerspoon already runs at
  login with Accessibility permission and receives the same NSWorkspace
  notifications, so a separate resident process and an `xcrun swiftc`
  compile step at callback time bought nothing.
- **Close-based reaping** in any form (time-based debounce, immediate close
  of unfocused empty-title windows, a polling reaper). Banned; see the
  minimize handler above.

## What is not measured

Every probe here reads AeroSpace's internal model (`list-windows`) and
Hammerspoon's events, never rendered pixels, except the close test above,
which reads the survivor's frame through `hs.window:frame()`. A perceived
half-second stall while the model says done points at the redraw layer,
which no test here can see.

## If a stall resurfaces

Open `aerospace debug-windows` or Activity Monitor while the gap is visible.
Do not add a poller or re-litigate AX. Check whether the closing app was the only window
on the system: that is the one case with no focus event, and it needs a
signal other than focus-change or termination. A window-removed event in
`aerospace subscribe`, if a release ever ships one, replaces every workaround
here.
