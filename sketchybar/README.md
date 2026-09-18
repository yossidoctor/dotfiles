# sketchybar

A status bar for the AeroSpace setup, styled to read as macOS's own: a
translucent full-bleed strip in SF Pro with SF Symbols, a chip per workspace
carrying its app icons and names, the focused window, and a right side with
now-playing, volume, battery and a clock. It replaces the native menu bar
outright rather than sitting over it — see § Suppressing the native menu bar.

Each script's header comment is the SoT for its own behavior; this file holds
what no single script owns — the geometry contract, and the traps that cost a
session to find.

## Layout

| File | Role |
|---|---|
| `sketchybarrc` | entry point; every item declared, nothing computed |
| `theme.sh` | every color and font, sourced by the rc and by each plugin |
| `icon_map.sh` | upstream app-name → ligature map (vendored, regenerate from the font's release) |
| `plugins/aerospace.sh` | repaints every workspace chip in one pass |
| `plugins/front-app.sh` | the focused window's app name and title |
| `plugins/clock.sh`, `battery.sh`, `volume.sh`, `media.sh` | one item each |
| `plugins/media-row.sh` | hover and dismissal for the now-playing source rows |
| `plugins/hover.sh` | the pointer fill, for items with no script of their own |
| `plugins/menubar.sh` | re-applies the native menu bar suppression |
| `media-stream.sh` | the now-playing daemon |
| `media-stream-agent.sh` | installs that daemon as a LaunchAgent |
| `menubar-hide.c`, `pointer-y.c`, `makefile` | two C helpers; the rc builds them when stale |

## The geometry contract

**`BAR_HEIGHT` must equal the menu bar's reserved height.** Read it live:

```bash
xcrun swift -e 'import AppKit; let s = NSScreen.main!
print((s.frame.origin.y + s.frame.height) - (s.visibleFrame.origin.y + s.visibleFrame.height))'
```

It is 38.0 on the built-in display and equals `safeAreaInsets.top`. A taller bar
leaves its bottom border visible below that reserved band; a shorter one sits
above its lower edge. Both read as "one pixel off".

**`gaps.outer.top` in `aerospace.toml` stays 6, like every other edge.** AeroSpace
measures outer gaps from the *visible frame*, which already excludes the bar's
area. Setting it to bar height + 6 stacks the two and leaves a 40pt band of
wallpaper under the bar.

**The bar is full-bleed, not an island.** No `margin`, no `corner_radius`, no
bar-level border — the native menu bar's shape. `margin` additionally insets the
frame on every side, so a bar carrying one can never sit flush at its exact
height. It is translucent rather than opaque: `blur_radius=34` under a low-alpha
`BAR_BG` is a real backdrop blur (`SLSSetWindowBackgroundBlurRadius`), which
works on macOS 27 — the renderer bugs that once made it unusable no longer bite.

**Items draw no background at rest.** Text sits directly on that glass, so
`icon.shadow` / `label.shadow` carry the legibility: the blur is a plain Gaussian
with none of `NSVisualEffectView`'s contrast clamping, so a shadow is
load-bearing here rather than decorative. The one filled shape is the focused
workspace chip.

## Traps, each found the hard way

**`y_offset` is positive-UP, one point per unit.** Verified by setting it on a
live item and measuring the ink: `+4` moved a glyph from 14.0pt to 10.0pt.

**Do not add `y_offset` to centre text.** sketchybar centres a text run in its
background already. Offsets stack — item, text and bracket each take their own —
and once the total pushes an item's background past the bar's bottom edge the
background is clipped, every subsequent measurement of "the pill" is wrong in
the same direction, and each wrong measurement justifies another offset. The
config carries none.

**Centring is a padding problem, not an offset problem.** The default
`icon.padding_left=8` / `icon.padding_right=4` exists so an icon sits tight
against the label beside it. An item whose label is hidden (the hover group
while collapsed) or empty (a workspace with no apps) has nothing to balance the
wider left pad, so its glyph sits ~1.6-3pt right of centre. Give those items
symmetric padding.

**Padding is integer while glyph advance widths are odd.** `8/4` sits right,
`6/6` sits left by the same half point, `7/6` lands inside a device pixel at 2x.
There is no offset that fixes this; the padding must absorb the odd remainder.

**One item, one font size.** The clock mixed an 11.0pt date with an 11.5pt time;
the taller run drove the item's height and pushed its own baseline low inside
the pill. Weight distinguishes the two runs instead.

**Digits are not all the same width.** With identical padding, chips showing
`4`, `6` or `9` measure up to 1pt off where `2`, `3`, `5` measure 0.00. That is
the face's ink, not the layout, and per-digit padding is not worth it. Where
digits must not shift the layout — the clock — `label.font.features=tnum` puts
them on a fixed advance instead.

**Glyph sets differ in orientation.** The Material Design battery codepoints
(`U+F0079`…) draw vertically; the Font Awesome ones (`U+F240`…) draw
horizontally and are what the reference configs use.

**Write glyphs as UTF-8 byte escapes.** Hooks and `./install` steps run under
macOS `/bin/bash` 3.2 (`README.md` § Script conventions), which expands neither
`$'\Uxxxxxxxx'` nor `printf '\U'` — both yield the literal text. `theme.sh`
spells each glyph as the bytes of its codepoint with the codepoint in a comment.
A raw private-use character in the file does not survive every editor round
trip; these were silently empty strings once already.

**`--query` nests `background` under `geometry`.** Reading `.background.height`
at the top level returns null and looks like the property never applied. Several
properties are not reported at all — `background.color` and a popup item's
`drawing` both come back null — so a script that needs to know its own last
state stamps a file rather than asking. `media.sh` and `hover.sh` both do.

**sketchybar validates no font string.** `label.font="SF Pro:Regular:12.0"`
exits 0 and prints nothing whether or not the family resolves, then silently
renders a fallback — CoreText substitutes **Times New Roman**. Only AppKit can
answer whether a family exists:

```bash
xcrun swift -e 'import AppKit
print(NSFont(name: "SF Pro Text", size: 12)?.fontName ?? "MISSING")'
```

**SF Pro is a download, not a system font**, installed here to `~/Library/Fonts`
from Apple's `SFProFonts.pkg`. It matters beyond the typeface: **SF Symbols live
inside it as Private Use Area codepoints**, and the system's own `.SF NS` does
*not* carry them (`CTFontGetGlyphsForCharacters` returns no glyph). Bare
`"SF Pro"` resolves to `SFPro-Black`, the variable font's heaviest instance, so
name the optical size — `SF Pro Text`.

**Only the first letter of an `--animate` curve is read**, and two of the named
curves do not exist. `animation.c` branches on `tanh`, `sin`, `quadratic`, `exp`
and `circ`; `bounce` and `overshoot` are `#define`d but never dispatched, so they
animate linearly with no error. Duration is a **frame count on a 60Hz basis**,
not seconds — Apple's ~0.3s ease is `--animate sin 18`, and `0.3` truncates to 0.

**A shadow's angle is polar, and y grows up.** `offset.y = -distance*sin(angle)`,
so `angle=90` puts the shadow *below* the text and `270` lifts it above.

**Never run `sketchybarrc` by hand against a live bar.** Every `--add` reports
"already exists" and every `--set` re-declares the item, wiping labels the
plugins had populated; the bar is left as empty pills. `sketchybar --reload`, or
restart the process.

## AeroSpace integration

Two custom events, both triggered from `aerospace.toml`:

- `aerospace_workspace_change` on `exec-on-workspace-change`, appended after the
  `&` that backgrounds `reap-ghosts.sh` so the bar repaints without waiting on it.
- `aerospace_window_change` on `on-window-detected`, as the first entry carrying
  `check-further-callbacks = true` — without that flag it would match every
  window and end the list, and no app would ever be floated again.

**There is no window-closed or window-minimized event** (`docs/aerospace/UPSTREAM-2026-09.md`
§ 1), so a closed window's icon stays on its chip until the next workspace
switch repaints it. That staleness is deliberate: the alternative is a polling
timer, and every AeroSpace CLI call cancels the daemon's heavy refresh session
(same doc, § 4) that the retile patches depend on.

**`aerospace list-workspaces --all` omits an empty workspace.** The nine come
from `WORKSPACES` in the rc, declared to match the `alt-1`…`alt-9` bindings; a
chip that appears only once a window lands there defeats drawing all nine.

**`display=N` draws nowhere when monitor N is absent**, which silently deletes
chips 3-6 on the laptop alone. `ws_display()` pins only to a monitor that
`aerospace list-monitors --count` reports.

## Now-playing

macOS exposes exactly **one** now-playing session to third parties, so
`media-control` can never report a second. Control Center's multi-row panel uses
access no third party gets.

A second row is nonetheless possible, from a different direction: a **scriptable
player answers for its own state** even while another app owns the session, so
Spotify and VLC are each read through their AppleScript dictionaries. `PLAYERS`
in `media.sh` is the table — one line per player, carrying the row item, the app
name, its bundle id and the two snippets that read its state and title. A player
that *is* the system session is listed once, not twice.

**Ask System Events whether a player is running first.** Naming a stopped app
inside `tell application` **launches it**, so an unguarded repaint would boot
Spotify every fifteen seconds.

**The pill follows what is audible, not what holds the session.** macOS leaves
the now-playing slot with the last app to claim it, so a video paused ten minutes
ago still owns it while another player is making noise; the pill would then name
a paused source as the current one.

**A popup cannot be dismissed on `mouse.exited`.** That event fires on small
movements *within* a row as well as on leaving it, and the pointer must leave the
pill to reach the rows at all — so closing there makes the rows unreachable.
Deferring the close and cancelling it when another row is entered fixes every row
but the last, where nothing below it can cancel. `pointer-y` answers the actual
question: the menu closes only when the pointer is genuinely past the popup's
extent.

**Repaints are frozen while the popup is open.** Otherwise the periodic tick
rewrites `label.width` and collapses the hover mid-gesture, and a change of
system session swaps which rows the dedup hides, so entries appear to reorder
while being read.

The native `media_change` event is deprecated on macOS 26+ and its MediaRemote
path has been entitlement-blocked since 15.4, so the data comes from
`media-control`, which trampolines through `/usr/bin/perl` (entitled as
`com.apple.perl5`). Three behaviors `media-stream.sh` handles:

- the stream's **first message is an empty payload**, before any real state
- `diff` defaults to true, so a payload carries only changed fields — the daemon
  passes `--no-diff`
- `durationMicros` can be `inf`, which is not valid JSON; `--no-artwork` also
  keeps a 500KB-1MB base64 blob off the hot path

`stream` wraps each record in `.payload`; `get` returns the same fields at the
top level. The jq filter reads `.payload // .` so either shape works.

Seek is unreliable on macOS 26+ upstream, so the popup wires only
`previous-track`, `toggle-play-pause` and `next-track`.

## Suppressing the native menu bar

macOS has **no setting for this**. "Automatically hide and show the menu bar"
keeps the hover reveal in every one of its states, and that reveal is enforced by
the window server rather than a preference. Every third-party menu bar tool —
Ice, Bartender, Hidden Bar, Dozer — manages *items*, not the strip.

`menubar-hide.c` is the mechanism: `SLSSetMenuBarInsetAndAlpha(cid, 0, 1, 0.0)`.
At alpha **exactly 0.0** this is not merely a transparent bar — the menu bar stops
accepting mouse events, so the reveal never fires and clicks fall through. yabai
documents the same call under its `menubar_opacity` config.

**SIP can stay enabled.** It is a plain SkyLight call on an ordinary connection,
not a Dock.app injection; yabai reaches it without its scripting addition. Link
against SkyLight through the framework search path — CoreGraphics does not export
the symbol, and the on-disk `Versions/A/SkyLight` does not exist on this OS.

**macOS resets the alpha** on space changes, display changes and on leaving
Mission Control, so a one-shot call lasts until the first Ctrl+arrow.
`menubar.keeper` in the rc re-applies it on the corresponding events, and the rc
applies it once at startup for the reboot case. `./menubar-hide 1.0` restores the
bar.

## Restarting the bar

**`brew services restart` can silently leave the old process running.** The
command reports success, the service then sits in `error`, and a stale
`sketchybar` from hours earlier keeps drawing — which looks like config changes
having no effect, or the native menu bar bleeding through. Check what is actually
running before believing a restart:

```bash
ps -o lstart= -p "$(pgrep -x sketchybar)"
```

If it predates the change, `brew services stop sketchybar && pkill -x sketchybar`
and start it again.

**A restart kills the media stream.** `media-control stream` is a child of the
LaunchAgent and does not reliably come back, leaving the pill blank. The item
self-heals on its own tick, or:

```bash
launchctl kickstart -k gui/$(id -u)/dev.yossidoctor.sketchybar-media-stream
```

## Verifying a change

Screenshot and measure; do not judge alignment by eye, and do not trust a
detector that has not been shown to isolate the thing it claims to measure.
Catching a bracket border or the whole bar instead of the pill produces
confident, wrong numbers.

```bash
screencapture -x -R <x>,<y>,<w>,<h> /tmp/bar.png
```

Needs Screen Recording permission for the terminal. Measure the ink's
whitespace against the pill's fill on both axes — a glyph whose ink centre
matches the pill centre can still read low, because a font reserves descender
space digits and symbols never occupy.
