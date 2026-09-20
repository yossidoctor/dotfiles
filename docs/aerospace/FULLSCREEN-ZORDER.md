# AeroSpace fake-fullscreen z-order

**TL;DR.** AeroSpace's `fullscreen` command (bound to Hyper+f) is a frame
resize, not real fullscreen — and AeroSpace does zero z-order management,
so the fullscreened window can end up rendered BEHIND tiled siblings that
macOS raised more recently. The fix is an explicit raise (AXRaise + app
activate — the identical pair AeroSpace itself uses in its one and only
raise path) right after the Hyper+f toggle and on every focus event that lands
on a fullscreen window. See `raise-fullscreen.sh`'s header for mechanics and
`raise-window.swift` for the raise itself; wiring is the Hyper+f binding and
the second `on-focus-changed` entry in `aerospace.toml`.

## Root cause, verified against AeroSpace source (0.21.3-Beta era, main)

- `Window.layoutFullscreen` (`Sources/AppBundle/layout/layoutRecursive.swift`)
  does exactly one thing: `setAxFrame(monitorRect, size)`. Frames only.
- `FullscreenCommand.run` sets model flags (`isFullscreen`,
  `markAsMostRecentChild`) — no raise. Re-running it no-ops ("Already
  fullscreen").
- The ONLY raise in the entire codebase is `MacApp.nativeFocus`
  (`Sources/AppBundle/tree/MacApp.swift`): `kAXRaiseAction` + app
  `activate()`, fired solely when focus *changes*
  (`refresh.swift`: `focusBefore != focusAfter`).
- Therefore fake fullscreen sits on top only by the luck of being focused
  at toggle time. Anything that raises a sibling without moving AeroSpace's
  focus — Tahoe-era WindowServer does unrequested reorders (upstream
  discussion #2155) — buries it permanently: the layout pass restores
  frames every refresh but never z-order.

Local trials confirming the model (z-order read via
`CGWindowListCopyWindowInfo(.optionOnScreenOnly)` front-to-back order):
fullscreening a window whose same-monitor frontmost sibling belonged to a
DIFFERENT app left it buried under that sibling (the reported bug,
reproduced); AXRaise from a non-active app could not beat the active app's
z-band (macOS semantics — activation is what crosses app z-bands, which is
why the fix activates too).

## Upstream status (as of 2026-09-14: no release after 0.21.3-Beta, #1424 open)

- No z-order promise in the `fullscreen` docs; no config option for it.
- Exit-on-focus-change to another tiling window in the same workspace is
  intended design — maintainer declined to change it (#422) and endorses
  accordion + `accordion-padding = 0` as the persistent-fullscreen
  alternative.
- #1424 (open): planned `fullscreen --hide-others` flag would make
  occlusion impossible; unmerged.
- #2142 (closed, fixed 0.21.1-Beta): focus-follows-mouse hitting windows
  behind a fullscreen window — fixed in hit-testing only, not z-order.

## The fix and its residual gap

`raise-fullscreen.sh` no-ops unless the FOCUSED window is fullscreen, so:
no focus theft (it activates the app already owning focus), floating
windows can still be focused over a fullscreen one, and the upstream
exit-on-tiling-focus design is untouched. Residual gap: a burial with zero
subsequent focus events sits until the next one — deliberate; continuous
polling is rejected on cost grounds (docs/aerospace/RETILE-DELAY.md
§ Rejected approaches). If that gap bites in practice, the two
upstream-sanctioned alternatives are a `macos-native-fullscreen` binding
(real Space, physically unoccludable, costs the Space animation) or the
accordion setup above.

Failures of the raise itself append to `~/.cache/aerospace/raise.log`
(silent log = raise never failed).
