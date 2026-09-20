# AeroSpace upstream — what changed May→Sep 2026, and what it means for this config

Checked 2026-09-20 against primary sources only: GitHub release notes,
`main` source at tag `v0.21.3-Beta`, the issue/discussion/PR trackers
(`gh api repos/nikitabobko/AeroSpace/...`), the rendered docs' `.adoc`
sources, and JankyBorders' source. Installed here: AeroSpace 0.21.3-Beta,
JankyBorders 1.9.0, macOS 27.0 (26A5416b). Re-derive any list below with
the command named beside it — this file is a snapshot.

## 1. Releases

| Tag | Date | Content |
|---|---|---|
| v0.21.0-Beta | 2026-06-30 | feature release (below) |
| v0.21.1-Beta | 2026-07-01 | 4 bug fixes: focus-follows-mouse vs fullscreen (#2142), vs menubar dropdowns (#2143), floating windows inserted into accordion (#2147), menu on non-main screen with separate-spaces off (#1496) |
| v0.21.2-Beta | 2026-07-07 | crash `refreshSessionEvent is not initialized` (#2157); floating windows snapping to top-left on workspace switch (#2153) |
| v0.21.3-Beta | 2026-07-16 | ignore windows with window id 0 (cmux, #2169); Wispr Flow popup detection (#2170) |

v0.21.3-Beta is still the newest release. `main` is 10 commits past the tag —
`gh api repos/nikitabobko/AeroSpace/compare/v0.21.3-Beta...main --jq .ahead_by`.
The unreleased work is toolchain and CI: Swift 6.4, a periphery build from
source, and **`Add macos-27` (2026-09-15)** — the OS this config runs on.

**0.21.0 items that touch this config** (source: release body,
`gh api repos/nikitabobko/AeroSpace/releases/tags/v0.21.0-Beta`):

- `auto-reload-config` config option (#163). Default `false`; the default
  config comments "After setting this to true, reload once manually to start
  the auto-reloading". `ConfigFileWatcher.swift`: `open(path, O_EVTONLY)` +
  `DispatchSource` on write/delete/rename/revoke, 200 ms debounce, reload via
  a light session. Enabled here; verified against a rename-style write
  (`sed -i`) with no other reload path involved.
- `on-window-detected` gained an inline-table syntax with `if = 'test …'`
  commands and `check-further-callbacks` — the form this config uses (§ 8); the
  older `[[on-window-detected]]` array-of-tables form "is still supported and
  probably will remain supported forever"
  (release notes; guide § 'on-window-detected' callback). TOML 1.1 (newlines
  in inline tables) is what makes the new form readable.
- `layout` with a single argument now exits 0 when already applied;
  `--fail-if-noop` restores the old behavior (commit b5f9e443). This is why
  `reap-ghosts.sh`'s re-float of an already-floating window was a silent
  no-op.
- `reload-config` emits warnings; `config-version` below max warns. Max is 2
  (guide § config-version) — this config is at 2.
- `aerospace subscribe` (#1514): events `focus-changed`,
  `focused-monitor-changed`, `focused-workspace-changed`, `mode-changed`,
  `window-detected`, `binding-triggered`. No window-closed, no
  window-minimized (commands § subscribe).
- `aerospace run-callback (on-focus-changed|on-focused-monitor-changed|on-window-detected)`
  (#107) — the on-demand trigger used to verify this config's callbacks.
- `aerospace list-exec-env-vars` — shows the PATH callbacks get; unless
  `[exec]` is overridden, AeroSpace prepends
  `/opt/homebrew/bin:/opt/homebrew/sbin` (guide § exec-* Environment
  Variables).
- Shell operators `;` `&&` `||` `|` in bindings and `eval`; `test`/`test-not`.
- Socket protocol made public (#1513) — breaking for direct socket clients;
  the CLI is unaffected.
- `focus-follows-mouse` (#12) — not enabled here.
- Bug fix #2084: repeated *read-only CLI calls* amplified a hot loop of
  failed AX registrations (Dock) to 58–65% CPU. Fixed in 0.21.0 per the
  maintainer's reply in discussion #2084. Relevant because this config's
  workaround is exactly repeated read-only CLI calls.

## 2. Project status and maintainer activity

- Issues are not accepted directly; bugs go to
  `discussions/categories/potential-bugs` (README § Community, CONTRIBUTING).
  Only 7 issues were created since 2026-05-01
  (`gh api 'search/issues?q=repo:nikitabobko/AeroSpace+is:issue+created:>=2026-05-01'`),
  ~100 discussions.
- Every incoming PR is auto-labelled `not-actionable` ("By default, all PRs
  have this label. If the PR makes sense, the label will be removed" — label
  description; workflow `label-incoming-prs.yml`, commit ae2aa7aa). No PR has
  had the label removed since; none merged since 2026-05-01
  (`search/issues?q=…+is:pr+is:merged+merged:>=2026-05-01` → 0).
- Maintainer commits 2026, by month: 11 Jan, 47 Mar, 47 Apr, 14 May, 102 Jun,
  9 Jul, 1 Aug, 7 Sep — re-derive with
  `gh api --paginate 'repos/nikitabobko/AeroSpace/commits?author=nikitabobko&since=2026-01-01T00:00:00Z' --jq '.[].commit.author.date[0:7]' | sort | uniq -c`.
  Discussion replies continue at low volume — 2026-08-08 (#2219),
  2026-08-18 (#2204), 2026-09-03 (#2250). Not abandoned; bursty, and the
  September burst is toolchain work including macOS 27 support. A quiet month
  is this project's normal rhythm, not a signal to fork: forking trades a
  ~400-line workaround layer for 21k lines of Swift across 283 files
  (`find Sources -name '*.swift' | wc -l`), and the two bugs that hurt most
  here are macOS platform limits that survive a fork — `setAxFrame` dispatches
  one async job per window because each window belongs to a different process
  (`Sources/AppBundle/tree/MacApp.swift`), and the maintainer's own comment at
  `Sources/AppBundle/GlobalObserver.swift` records that
  `kAXUIElementDestroyedNotification` is unreliable, which
  docs/aerospace/RETILE-DELAY.md § Rejected approaches confirmed independently.
  To patch and test without owning a fork: `install-from-sources.sh` in the
  upstream tree.
- README § Project status still lists the "big refactoring" (#1215) as the
  prerequisite for fixing windows jumping to the focused workspace (#1216)
  and native tabs (#68) — both unchecked.

## 3. The issues this config patches — status

| Patched here | Upstream | State 2026-09-14 |
|---|---|---|
| retile-on-close, ghosts, phantom tiles (`on-focus-changed` pokes, watcher, Karabiner, `reap-ghosts.sh`) | #1615 | open; 12 comments; last 2026-07-11 (pottom's `on-focus-changed` workaround — the one used here); no maintainer comment |
| fullscreen z-order (`raise-fullscreen.sh`) | #1424 `fullscreen --hide-others` | open, untouched since 2025-07-13 |
| AX destroyed-notification dead end | #445 | closed 2025-10-18 |
| Tahoe/27 WindowServer reorders | discussion #2155 | open, unanswered, 1 comment (author's escalation: rescued windows can surface *in front of* tiled windows) |
| exit-fullscreen-on-focus design | #422 | unchanged |

One data point against the retile bug being universal: dcarley (2026-07-10,
#1615) stopped seeing ghosts after 0.21.1, guessing #2084. This machine runs
0.21.3 and `reap.log` still records transient ghosts daily, so that fix did
not cover this setup.

## 4. Source-verified mechanics that bear on the patches (tag v0.21.3-Beta)

**New-window placement flash.** A window opening into a tiled workspace is
visible at its macOS birth position for 68–87 ms before AeroSpace moves it to
its slot, measured on this machine at 5 ms resolution over four trials
(x=0…116 near the left edge → its real slot at x=906…1502). The retile is not
atomic and the new window is placed *last*: siblings resize one at a time
first, so the new window is the one seen in the wrong place. Not caused by
anything in this config — the trace is unchanged with
`extract-fullscreen-pair.sh` disabled.

Nothing here can fix it. `MacApp.setAxFrame` cancels any pending job for that
window then dispatches a fresh async job per window, each hopping to its own
app's AX thread, because every window belongs to a different process; macOS
exposes no cross-process atomic move. `NSAutomaticWindowAnimationsEnabled` and
`NSWindowResizeTime` are already minimised in `mac/defaults.sh`, and Ghostty's
`window-position-x`/`-y` do not move the birth position (tested: windows still
appeared at x=0 and x=29). Fixing it upstream means placing the window before
it is made visible — the machinery hinted at by
`runHeavyCompleteRefreshSession(…optimisticallyPreLayoutWorkspaces:)`.

`Sources/AppBundle/layout/refresh.swift`:

- Every CLI connection runs `runLightSession`, which first does
  `activeRefreshTask?.cancel()` ("Give priority to runSession"), then
  `refreshModel_nonCancellable` → body → `refreshModel_nonCancellable` →
  `layoutWorkspaces()`, and finally
  `scheduleCancellableCompleteRefreshSession(event)`.
- Only `runHeavyCompleteRefreshSession` runs `refresh()` (the per-app
  `MacApp.refreshAllAndGetAliveWindowIds` garbage collection of closed
  windows) and `normalizeLayoutReason()` (native fullscreen / **minimized** /
  hidden detection). It is the cancellable task the light session cancels.
- Consequence for this config: a burst of CLI pokes (retry-poke's 2 calls at 0
  and 200 ms, plus reap-ghosts' 1 call — a second only when it floats a phantom
  — and raise-fullscreen's 1 on every focus event) re-cancels the heavy
  session on each call; GC and minimize detection run once the burst ends. Each poke does force the frame relayout — the
  "poke half" mechanism is real — but pokes cannot advance ghost removal or
  minimize detection, and a dense stream postpones them.

`Sources/AppBundle/normalizeLayoutReason.swift`: `_normalizeLayoutReason`
iterates every window of the workspace, floating included; a window whose
`isMacosMinimized(.cancellable)` returns true is bound to
`macosMinimizedWindowsContainer` regardless of layout. So a phantom that
stays in the visible workspace for hours (reap.log, id 13650 ×441 on
2026-08-25) means the AX minimized query kept returning false/failing for
that window, not that floating windows are exempt.

`Sources/AppBundle/command/impl/MacosNativeMinimizeCommand.swift`: the
unminimize branch is `.fail("The command is uncapable of unminimizing
windows yet. Sorry")` — confirms docs/aerospace/RETILE-DELAY.md.

`Sources/AppBundle/tree/MacApp.swift` `nativeFocus`: single monitor or same
window → `nsApp.activate(options: .activateIgnoringOtherApps)` only;
otherwise `window.set(Ax.isMainAttr, true)` → `kAXRaiseAction` →
`activate(options: .activateIgnoringOtherApps)`. `raise-window.swift` does
raise + `activate()` without setting `kAXMainAttribute` first.

## 5. New reports since June that match this setup

Discussions unless noted (`gh api graphql` on `repository.discussions`,
created ≥ 2026-05-01; ~100 total).

- **#2263 (2026-09-13)** Restoring a minimized window moves it to the
  *focused* workspace and emits no `subscribe` event; deterministic, "two
  windows, one Cmd+M". Directly relevant to the phantom-float heal: a
  window `reap-ghosts.sh` floated, later restored from the Dock, will land
  floating on whichever workspace is focused, not its original one.
- **#2264 (2026-09-13)** Lid-close sleep → wake re-detects every window
  onto the focused workspace, fullscreen lost (`window-detected` burst);
  `pmset sleepnow` does not reproduce. Windows with an `on-window-detected`
  rule get moved back by the rule; this config has rules only for floating
  apps, so tiled apps here would stay on the focused workspace.
- **Monitor connect/disconnect crashes** — issue #506 (open since 2024,
  updated 2026-09-12), #2197 (2026-07-22), #2233 (2026-08-18, `isUnitTest`
  → `NSClassFromString` on the hot path, `EXC_BAD_ACCESS`), #2259
  (2026-09-08), #2262 (2026-09-12, clamshell 2→3 displays, unbounded
  recursion in `Monitor.activeWorkspace`, `Workspace.swift:118`). All on
  0.21.3. This config switches between a 3-monitor and a 2-monitor setup
  with `workspace-to-monitor-force-assignment`; a fix PR exists (#2232) and
  is `not-actionable`. AeroSpace restarted here at 23:55 on 2026-09-13 with
  no crash report in `~/Library/Logs/DiagnosticReports` — cause unknown.
- **#2243 (2026-08-26)** Closing a focused Ghostty window activates another
  Ghostty window instead of the expected one; author isolated it to
  Ghostty's `window-decoration = false` and recommends
  `macos-titlebar-style = hidden` instead. Check `ghostty/config` here for
  `window-decoration`.
- **#2222 (2026-08-10)** Firefox detached tab not detected on Tahoe until
  moved/clicked — the same "detection blocked until an event" shape as #1615.
- **#2200 (2026-07-24)** After a transient dialog closes (1Password Quick
  Access), focus falls back to workspace MRU, not the previously focused
  window; can raise a window on another monitor. Root cause named:
  `MacWindow.garbageCollect` → `toLiveFocus()`.
- **#2096 (2026-05-19, 4 upvotes)** Tiled windows randomly steal focus while
  typing in a browser; several me-toos through 2026-08-15; one case traced to
  a search popup treated as a window.
- **#2247 (2026-08-30)** 15–20 idle wakeups/s from `MenuBarExtra` scene
  updates and `AxAppThread` polling in `refreshAllAndGetAliveWindowIds`.
- **Issue #2234 (2026-08-18)** macOS reuses window ids; AeroSpace caches
  trees of dead ids (lock-screen blackout defence) and restores them when an
  id reappears. For `reap-ghosts.sh`: a logged ghost id can legitimately be
  a live window later — observation-only, so harmless, but do not treat
  `reap.log` ids as stable identities.
- **#2261 (2026-09-09)** "All windows floating on 26.6.2" — retracted by the
  author (accordion misread); not a Tahoe regression.
- **#2256** feature idea `on-window-hidden`/`on-window-unhidden` callbacks —
  would be the first event covering the phantom/minimize class if it ever
  lands.

## 6. Pending PRs worth watching (all `not-actionable`, none merged)

`gh api 'repos/nikitabobko/AeroSpace/pulls?state=open&sort=updated'`

- **#2217** `list-windows --layout <layout>` filter — would replace the awk
  gate in `reap-ghosts.sh`/`diagnose-gap.sh` with
  `list-windows --workspace visible --layout tiling`.
- **#2179** (draft) cross-monitor focus via private SkyLight API; argues
  `NSRunningApplication.activate` is app-level and can make a *different*
  window of the same app key on another monitor — the same activate call
  `raise-window.swift` relies on.
- **#2228** fix for #1311 "MacWindow is already unbound" crash in `focus`
  over floating windows (reported on macOS 27.0 26A5388g, 2026-08-13).
- **#2232** cache `isUnitTest` — the monitor-reconfiguration crash above.
- **#2225** native macOS tabs (#68).
- **#1714** hotkeys via `CGEvent.tapCreate` with left/right modifier
  distinction (`lcmd`, `rshift`, …) — would remove the need for the
  Karabiner F17–F20 detour for Hyper+LeftShift+arrow. Maintainer reviewed it
  2025-12-14 with structural change requests; no movement since.
- **#2245 / #2238** focus-follows-mouse vs Control Center / overlays — n/a
  here (ffm off).

## 7. JankyBorders

- v1.9.0 (2026-05-14) is the latest: "Address flickering on window resize";
  ignore windows that ignore window cycling (#178). Installed here.
- Open issues: #200 "1.9.0 is not reliable" (Mail/iTerm borders
  intermittent; one comment blames the new cycle-ignore filter for Ghostty
  not registering as active), #201 macOS 27 beta: border missing after
  leaving fullscreen until fullscreen is toggled again. No maintainer reply
  on either.
- `ax_focus=off` in `aerospace.toml` is correct: `src/main.c` sets
  `g_settings.ax_focus = ax_check_trust(true)` (auto-on when the process has
  AX trust) before `parse_settings` applies the explicit `ax_focus=off`; man
  page: "the (slower) accessibility API … Enabled automatically if the
  (parent) process has accessibility permissions".

## 8. Where this config stands against the above

Standing state (each verified live on 2026-09-14):

- Ghostty `window-decoration = true` in `ghostty/config`, so #2243's
  close-focus hand-off defect does not apply.
- `retry-poke.sh` sends two pokes (0 and 200 ms) — the minimum that covers
  both close orderings — because each CLI call cancels the daemon's heavy
  refresh (§4). Timed at ~0.57 s end to end including the reaper.
- `raise-window.swift` sets `kAXMainAttribute` before `kAXRaiseAction`, then
  activates the app: the `nativeFocus` sequence. `.activateIgnoringOtherApps`
  is omitted — the macOS 14 SDK marks it "will have no effect".
- `auto-reload-config = true` in `aerospace.toml`; AeroSpace reloads itself
  on save, so no external reload hook exists.
- `on-window-detected` uses the inline-table `if = 'test …'` form, placed
  above the first `[table]` header (a top-level key after a header is
  parsed into that table — AeroSpace reports it as
  `workspace-to-monitor-force-assignment.on-window-detected[…]`).
  `reload-config --warnings-as-errors` exits 0;
  `run-callback --for-every-window on-window-detected` applies the Safari
  rule.

Open, conditional on events not yet seen:

- **Phantom float + #2263** — a floated phantom restored from the Dock lands
  on the focused workspace (AeroSpace behavior for any restored minimized
  window, float or not). If that bites, a parking-workspace heal
  (`move-node-to-workspace`, layout-class) is the candidate — design with
  the user first, per the reaper's invariant.
- **Dock/undock crash class** — after a WORK↔HOME switch, check
  `ls -t ~/Library/Logs/DiagnosticReports | grep -i aerospace`; a
  `Monitor.activeWorkspace` recursion or `isUnitTest` frame ties it to
  #2262/#2233.
