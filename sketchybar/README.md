# sketchybar

A status bar for the AeroSpace setup: a chip per workspace carrying its app
icons and names, and a right side with now-playing, volume, battery and a clock.
Each script's header comment is the SoT for its own behavior; this file holds
what no single script owns — the geometry contract, and the traps that cost a
session to find.

## Layout

| File | Role |
|---|---|
| `sketchybarrc` | entry point; every item declared, nothing computed |
| `theme.sh` | every color and font, sourced by the rc and by each plugin |
| `icon_map.sh` | upstream app-name → ligature map (vendored, regenerate from the font's release) |
| `plugins/aerospace.sh` | repaints one workspace chip |
| `plugins/clock.sh`, `battery.sh`, `volume.sh`, `media.sh` | one item each |
| `plugins/media-control.sh` | the popup's transport buttons |
| `media-stream.sh` | the now-playing daemon |
| `media-stream-agent.sh` | installs that daemon as a LaunchAgent |

## The geometry contract

**`BAR_HEIGHT` must equal the menu bar's reserved height.** Read it live:

```bash
xcrun swift -e 'import AppKit; let s = NSScreen.main!
print((s.frame.origin.y + s.frame.height) - (s.visibleFrame.origin.y + s.visibleFrame.height))'
```

It is 38.0 on the built-in display and equals `safeAreaInsets.top`. A taller bar
leaves its bottom border visible beneath the menu bar whenever that slides in; a
shorter one sits above the menu bar's lower edge. Both read as "one pixel off".

**`gaps.outer.top` in `aerospace.toml` stays 6, like every other edge.** AeroSpace
measures outer gaps from the *visible frame*, which already excludes the bar's
area. Setting it to bar height + 6 stacks the two and leaves a 40pt band of
wallpaper under the bar.

**The bar is a flat fill, not an island.** No `margin`, no `corner_radius`, no
bar-level border — the native menu bar's shape. `margin` additionally insets the
frame on every side, so a bar carrying one can never sit flush at its exact
height.

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
JetBrains Mono's ink, not the layout, and per-digit padding is not worth it.

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
at the top level returns null and looks like the property never applied.

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

macOS exposes exactly **one** now-playing session to third parties, so the item
follows whichever app owns it and cannot be pinned to one or show several at
once. Control Center's multi-row panel uses access no third party gets.

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
