# AeroSpace retile on window close: mechanisms and watchdogs

**TL;DR.** AeroSpace does not re-tile when a window closes (macOS Tahoe and
later, upstream [#1615](https://github.com/nikitabobko/AeroSpace/issues/1615),
open). Every `aerospace` CLI call forces the pending layout pass, so the
workaround is to poke the daemon from every signal a close can emit:
`on-focus-changed` in `aerospace.toml` (the workhorse, ~40-90ms), the
`retile-on-quit-watcher` LaunchAgent (app-termination notification), and the
Karabiner Cmd+Q / Cmd+W rules (`retry-poke.sh`, off the keystroke). Three
further failure modes ride the same bug — ghost nodes, phantom tiles, and a
daemon GC hang — and `reap-ghosts.sh` observes the first, heals the second by
floating, and `diagnose-gap.sh` (alt-shift-d) tells all of them apart on a
live gap. Upstream state, with the commands to re-derive it: `UPSTREAM-2026-09.md`.

Scope: the window-close retile bug and the callbacks around it. General
AeroSpace setup is `aerospace.toml` itself; each helper script's header is
the SoT for its own mechanics.

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
The daemon cannot tell a config callback from Karabiner from a terminal.

So any `aerospace` CLI call, from anywhere, forces the pending layout pass.
Measured cost: ~14ms per call (50-call average on this machine). Credit:
pottom's 2026-07-11 comment on #1615 identified the effect empirically; the
source read confirms the mechanism.

`runLightSession` also cancels the daemon's in-flight heavy refresh
(`activeRefreshTask?.cancel()`) and reschedules it after the frame relayout,
and only the heavy pass garbage-collects closed windows and detects native
minimize. A dense burst of pokes therefore postpones exactly the work the
ghost and phantom tooling waits on: two pokes cover "window still in the
tree" and "window already torn down", and more is worse.

## Mechanisms in place

**`on-focus-changed` (`aerospace.toml`).** Closing a window reassigns macOS
focus to the survivor, which fires this callback; it runs `reap-ghosts.sh`,
whose `list-windows --all` snapshot is the poke, and `raise-fullscreen.sh`.
Measured against a
50ms poll of the tree: a `didDeactivate`/`didActivate` pair lands 40-90ms
after the window leaves the tree in every trial, on Cmd+W and Cmd+Q alike,
including apps that stay resident with zero windows (Slack). Syntax gotcha:
the value is a list of independent subcommand invocations, so each element is
one complete `exec-and-forget <shell command>`; `['exec-and-forget a',
'/bin/bash', '-c', 'b']` parses as three subcommands and `reload-config`
fails with `Unrecognized subcommand '/bin/bash'`. The callback PATH includes
`/opt/homebrew/bin` (`aerospace list-exec-env-vars`), so scripts run by bare
path.

**`retile-on-quit-watcher` (LaunchAgent `dev.yossidoctor.retile-on-quit-watcher`).**
`retile-on-quit-watcher.swift`, compiled and installed by
`retile-on-quit-watcher.sh` (wired in `install.conf.yaml`), observes
`NSWorkspace.didTerminateApplicationNotification` and pokes `list-windows`
on every app termination: Cmd+Q, Force Quit, Dock/menu Quit, `killall`,
crashes all end in that one notification. `RunAtLoad` + `KeepAlive` respawn
it within ~3s of a `kill -9`. The notification fires at process exit, which
trails window-gone-from-tree by an app-dependent margin (Slack ~950ms,
PyCharm ~2.3s, Linear ~0-80ms), so in every measured trial
`on-focus-changed` had already retiled and this poke was a no-op. It stays
as the backstop for the one case that cannot be safely tested: no other
window or app anywhere to receive focus, where no focus event fires at all.

**Karabiner Cmd+Q and Cmd+W rules (`karabiner/karabiner.json`).** Send the
real keystroke through, then run `retry-poke.sh`: two pokes at 0 and 200ms,
backgrounded so Karabiner's event chain never waits, then the log-only
reaper so the zero-focus-event case still gets observed. A keystroke and an
OS notification are independent signals; redundant pokes cost one extra
~14ms socket call and nothing else.

**`reap-ghosts.sh` (`on-focus-changed`, `exec-on-workspace-change`, tail of
`retry-poke.sh`).** Observation for ghosts, auto-heal for phantoms; header is
the SoT. Ghost detection uses window-server ground truth: AeroSpace window
ids are CGWindowIDs (every `list-windows` id appears as a `kCGWindowNumber`),
so a tree id absent from `CGWindowListCopyWindowInfo(.optionAll)` is a dead
node whatever its title. It logs candidates to `~/.cache/aerospace/reap.log`,
times every daemon answer and tags slow ones `SLOW`, and tags a run whose
oracle returns fewer ids than the tree holds `ORACLE-SUSPECT`, trusting
nothing on that run. **It never closes, kills, or minimizes a window.**
Close-based reaping is banned: an empty oracle read as "no windows exist"
once classified every unfocused window as a ghost and closed four live ones
in one pass. Layout-changing remediation is the allowed class; anything
stronger than logging is designed with the user before it ships.

**`diagnose-gap.sh` (alt-shift-d).** Captures the moment a gap is visible
and delivers a verdict as a macOS notification: GC HANG (daemon did not
answer within 5s), GHOST NODE(S), PHANTOM TILE(S), or NO GHOSTS, DAEMON FAST
(stale layout, or frames not applied). These states heal before anyone else
can look, so the user captures them.

## Failure modes

**Stale layout.** The tree is right, the frames are old. Any poke fixes it;
the three poke mechanisms above exist for this.

**Ghost node.** A closed window leaves a dead node that slices the layout.
Only `close --window-id` removes it (`reload-config` and
`flatten-workspace-tree` do not). Observed ghosts are transient: across six
weeks of `reap.log` (3976 lines, 887 runs with candidates) the longest-lived
id appeared in 7 consecutive runs, and most cleared within ~80ms on their
own, faster than any callback reacts. Ghosts are logged, never closed.

**Phantom tile.** A window the user minimized stays `h_tiles` in the tree,
holding a slot at full alpha with `kCGWindowIsOnscreen == false` and AX
`kAXMinimizedAttribute == true`: AeroSpace's native-minimize detection has
stalled. Neither a ghost (the window exists) nor stale layout (the tree
really contains it). `macos-native-minimize` cannot resync the model (its
unminimize branch returns "uncapable of unminimizing windows yet"), so the
heal inside the allowed class is `layout floating --window-id`, which
`reap-ghosts.sh` applies behind three gates to tiled windows only
(`%{window-layout}` ≠ `floating`), logging `PHANTOM floated`. Detection can
stay stalled for hours while the window stays minimized.

**Daemon GC hang.** The maintainer, closing
[#445](https://github.com/nikitabobko/AeroSpace/issues/445): *"AeroSpace
garbage collects dead windows in a sequential manner, by querying every
application on a system. If any of the applications doesn't respond,
AeroSpace infinitely waits for the application and cannot proceed further."*
This fits the multi-second stalls that reproduce on no schedule and that no
callback wiring changes: the poke arrives in ~90ms and the daemon does not
act on it. `reap.log` shows the fingerprint as consecutive `SLOW` runs
(worst observed 7531ms) with a ghost pair riding them. Evidence that would
confirm a specific hang: `aerospace debug-windows` or Activity Monitor open
at the moment of the stall, showing which app is unresponsive.

**Frames not applied.** The tree is right while the screen is wrong, with
clean-tree `reap.log` runs throughout: the daemon is not applying frames,
consistent with the GC hang, or a phantom tile. Recovery: alt-shift-semicolon
then `r` (`flatten-workspace-tree`).

## Rejected approaches

- **Continuous poller.** Every poke is a full `refreshModel` +
  `layoutWorkspaces`, so a 200ms poll is ~7% duty cycle of relayout all day
  for a rare event, and each poke cancels the heavy pass the ghost/phantom
  tooling needs. Every community workaround in the upstream threads is
  event-driven.
- **AX `kAXUIElementDestroyedNotification`.** A minimal observer registered
  on both the window and the app element (`AXObserverCreate` /
  `AXObserverAddNotification` both `err=0`) never fired, on quit or on a plain
  TextEdit Cmd+W. Upstream abandoned it for the same reason (#445: "macOS AX
  callbacks are unreliable, and sometimes windows can close but the callback
  is not invoked").
- **Close-based reaping** in any form (time-based debounce, immediate close
  of unfocused empty-title windows, a polling reaper). Banned; see
  `reap-ghosts.sh` above.

## What is not measured

Every probe here reads AeroSpace's internal model (`list-windows`) and
NSWorkspace notifications, never rendered pixels. A perceived half-second
stall while the model says done in ~90ms points at the redraw layer, which
no test here can see.

## If a stall resurfaces

Press alt-shift-d while the gap is visible and read the verdict. Do not add
a poller or re-litigate AX. Check whether the closing app was the only window
on the system: that is the one case with no focus event, and it needs a
signal other than focus-change or termination. A window-removed event in
`aerospace subscribe`, if a release ever ships one, replaces every workaround
here.
