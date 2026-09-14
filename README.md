# dotfiles

Dotfiles managed via [dotbot](https://github.com/anishathalye/dotbot). Public: the shell, terminal, Homebrew, macOS defaults, window management, and the global Claude Code config of one Mac. Private layers install on top of it (§ Layers).

## Install

New Mac, from a bare Terminal:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
git clone https://github.com/yossidoctor/dotfiles.git ~/dotfiles && ~/dotfiles/install
```

`./install` puts Homebrew on PATH, trusts the taps `brew/Brewfile` names, runs
`brew bundle` when the Brewfile isn't satisfied (casks may prompt for your
password), then runs dotbot over `install.conf.yaml`. Idempotent; re-run anytime
to activate symlinks or pick up a Brewfile change. A private layer (§ Layers)
installs after this, with its own `install`.

## Adding new dotfiles

1. Copy the file into its topic directory (`zsh/`, `git/`, `claude/global/`, etc.).
2. Declare it in `install.conf.yaml`:
   - Single file: `~/.target: topic/source` under `link:`.
   - Whole directory: a `path:` block with `relink: true, force: true` (see the `claude/global/skills`, `claude/global/output-styles` entries).
   - Shell action (compile, import, run script): under the `shell:` section.
3. Run `./install` — creates the symlink and reruns any shell actions.
4. Commit the topic file + the `install.conf.yaml` change together.

## How it works

### Git identity & credentials

No default identity. `git/config` sets `user.useConfigOnly = true` and routes by `includeIf gitdir:`: `~/dotfiles/` → `git/identity`, which holds the personal `user.email` (shared `user.name` lives once in base `git/config`); `git config -f ~/dotfiles/git/identity user.email` reads it. A commit outside every included scope fails loud until a per-repo identity is set. Another layer adds its own tree's scope through `~/.config/git/local.gitconfig`, which `git/config` includes when present and which this repo never ships.

Auth via `git/credential-helper.sh`: it sources every identity file in `~/.config/git/identities.d/` (`URL_PREFIX`, `GH_LOGIN`, `TREE`; this repo deploys `identities.sh` there as `personal.sh`) and picks the gh account whose `URL_PREFIX` matches the repo URL, else whose `TREE` contains the repo; no match fails loud rather than borrowing an account. A second layer drops a second file and the helper needs no change.

### Layers

This repo is the base: shell, terminal, Homebrew, macOS defaults, and the global Claude Code config. A private layer repo installs its own dotbot manifest on top — its `install` after this one — and reaches everything here only through the paths dotbot deploys (`~/.claude/…`, `~/.config/git/…`); nothing in this repo names a layer. A layer's project rules load through its own `CLAUDE.md` when that project directory is the session root.

### Claude Code hooks

Global hooks register in `claude/global/settings.json` and fire in every session; scripts sit beside them in `claude/global/hooks/` and deploy per file to `~/.claude/hooks/`. A project layer registers its own hooks in its project settings file, which Claude loads when that directory is the session root; those hooks source the deployed prologue at `~/.claude/hooks/hook-lib.sh` and run their case files through the deployed harness at `~/.claude/hooks/tests/run-tests.sh`.

The prologue is `claude/global/hooks/hook-lib.sh` — payload parsing (`hook_read_raw`, `hook_parse_input`), the command-shape normalizer (`hook_command_shape`: heredoc bodies dropped, newlines mapped to `;`, quoted regions removed, so a hook carries its regex and nothing else), the rule-repo resolver (`hook_rule_roots`: the repositories behind `~/.claude/CLAUDE.md` and the project's `CLAUDE.md`), and the decision emitters (`deny`/`ask`). Each function's contract is documented in the lib's own header.

Each script's header comment is the SoT for its exact behavior and rationale — the rows below are one-line orientation only. All are covered by the table-driven tests under `claude/global/hooks/tests/`.

**Global** (registrations: `claude/global/settings.json`):

| Event | Hook |
|---|---|
| `SessionStart` | `ask-matt-banner.sh` — one colored line naming the `/mattpocock-skills:ask-matt` router; banner only. |
| `PreToolUse: Bash` | `enforce-foreground-polling.sh` — rewrites follow streams / watch commands to run off-thread; denies foreground sleeps and sleep-loops. `enforce-read-over-shell-read.sh` — denies a `cat <file>` or `sed -n '<a>,<b>p' <file>` whose bytes would land in the transcript, naming the exact `Read` call to retry with; pipes, redirects, heredocs, multi-file `cat`, `sed -i`, and throwaway paths pass. Also denies `rg -r`, ripgrep's replace flag typed from grep habit. |
| `PreToolUse: Agent` | `force-background-agents.sh` — normalizes every subagent dispatch: `run_in_background: true` so the main thread never blocks, and a non-fork dispatch with `model` omitted or `fable` is rewritten to `opus` so a subagent never launches as Fable (an explicitly named non-fable model is kept). |
| `PreToolUse: Read`/`Write`/`Edit` | `redirect-symlink-edits.sh` — denies a symlink, or a path through a symlinked directory whose target is inside a git repository, and reports the real path so the first Read already keys it; a symlinked dir outside any repo (`/tmp`) passes. |
| `PreToolUse: Write`/`Edit` | `warn-existing-occurrence.sh` — on a rule file, hands back the lines already carrying the backticked tokens the edit adds and the first line of every `§` section it cites; context only, never a decision. |
| `UserPromptSubmit` | `caffeinate-claude.sh` — keeps macOS awake while Claude works. `snapshot-rule-files.sh` — copies every rule file in each rule repo (`hook_rule_roots`) to `/tmp/claude-rule-snapshot-<session>/<repo>/` as the turn's baseline, so an edit the turn also commits still diffs. |
| `Stop` | `caffeinate-claude.sh` — 30-min post-turn linger. `audit-docs-on-stop.sh` — blocks a stop while a rule file's cumulative diff is unaudited (CLAUDE.md, skills, agent defs, skill references — not session docs), diffing against the turn-start snapshot where one exists and `HEAD` otherwise, appending the findings of the project's `scripts/check-doc-refs.sh` when it has one, and writing it all to a file Claude reads so the terminal gets one line; at most one block per turn that edits rule text. |
| `Notification` | `notify-agent-idle.sh` — macOS banner when Claude needs input or a background subagent finishes. |

### Permissions

`.permissions` arrays are edited directly in `claude/global/settings.json`, which holds the rules that apply everywhere. Claude Code merges permission rules across settings scopes (union), so a project layer's settings file adds only its own extras and never re-lists a global entry. `deny`/`ask` are safety-critical — review every change individually.

### Statusline (`claude/global/statusline-command.sh`)

```
model  ctx%  (effort: High)  [bypass]
  1 ● <email local-part>   5h ▰▰▱▱▱  26% (03h 21m)   7d ▰▰▰▱▱  65% (06h 41m)   <scoped> ▰▰▰▰▰  92%
  2   <email local-part>   5h …                                                        stale
  <job-id> working    45k <job name> (2 in flight)
```

Header line, then one row per claude-swap account, then one row per live background job. Colors are the Catppuccin roles in `starship/starship.toml`, cached in `claude/global/statusline-lib.sh` together with the shared color ramp. No cwd, scope, or git state — the line is workspace-agnostic.

Account rows come from `~/.claude-swap-backup/cache/usage.json` (the active number from `sequence.json`): account number, `●` on the active account, the email's local-part padded to 8, then a 5h meter, a 7d meter, and the scoped per-model meter when present — each a 5-cell bar, percentage, and reset countdown. Inactive rows are faded. `stale` marks a cache older than 15 minutes, and a stale cache kicks `cswap auto --once --dry-run` in the background at most once per 2 minutes. The rows are absent when claude-swap isn't installed or has no cache; run `cswap list` for the registered accounts and their quotas. Job rows list every `~/.claude/jobs/*/state.json` in state `working`/`blocked` updated within 12h, while the daemon named in `~/.claude/daemon.lock` is alive.

What changes that account is the `dev.yossidoctor.cswap-auto` LaunchAgent (generated from `$HOME` and installed idempotently by `claude/global/cswap-auto.sh`, a `./install` shell step): it runs `cswap auto --model all` (the script is the SoT for the arguments; per-model weekly windows count alongside the account-wide 5h/7d ones), kept alive across logout and reboot, rotating to the account with the most quota left once the active one hits `cswap`'s default 90% threshold. Actual switches land in `cswap`'s own 1MB-rotated `~/.claude-swap-backup/claude-swap.log`; the per-minute "no switch, below threshold" ticks go to `/dev/null` rather than an unrotated file that grows a line a minute forever. The agent's stderr is kept in `auto-stderr.log` beside the rotated log, so a crash-loop leaves evidence. `launchctl list | grep cswap` shows whether it's running. Registering an account is manual and interactive (`cswap add`) — it never runs from `./install`.

Context pct rides `ramp_color`: muted grey below the warm threshold, red deepening to bold, and from the alarm threshold a filled white-on-red pill (a deeper foreground red stops reading as more urgent once the channels bottom out). Thresholds warm/bold/alarm: 25/40/50 by default, 45/65/80 for Sonnet. Account meters use the muted ramp at 40/70 (softer red, no bold, no pill). `(effort: Low|Mid|High|XHi|Max)` (muted) shows the current reasoning-effort level; unmapped values pass through raw; absent when the model doesn't support the effort parameter. `bypass` badge (red) shows only in bypass-permissions mode. Render cost, `hyperfine` 20 runs: 59.9 ± 4.5 ms.

### Subagent statusline (`claude/global/subagent-statusline.sh`)

Overrides the agent-panel rows via `subagentStatusLine`. Per row: description left, then `model  ctx%  elapsed · ↓tokens` right-aligned to the payload's `columns` width (padding computed on visible length, ANSI-stripped). ctx% is `tokenCount / contextWindowSize` on the main line's default ramp (25/40, no pill); `startTime` is epoch ms; fractional counts are floored. Rows without a resolved `contextWindowSize` keep their default rendering.

### Brew maintenance

`brew/brew-maintenance.sh` (on PATH as `brew-maintenance`) runs `update`, `upgrade`, `upgrade --cask --greedy`, `bundle check` (Brewfile drift), `missing`, `autoremove`, `cleanup --prune=all`, `doctor` — continues on per-step failure, collects them into end summary. `brew update` itself fails → run flagged STALE (later steps hit stale tap metadata). Cask upgrades pass `--no-quit`, so a running app is left alone and serves its old binary until quit by hand. Closes with inventory of pinned formulae, `:latest` casks, started services.

### macOS defaults

`mac/defaults.sh` writes Dock, animation, keyboard, Finder, screenshot prefs via `defaults write`. `mac/disable-spotlight.sh` disables Spotlight indexing via `mdutil` because Raycast handles indexing — run from `./install` guarded by `|| true` since it needs sudo (read the script for the exact flags). `mac/duti.sh` binds default apps per file type (e.g. `*.json` → VS Code); unknown UTIs warn, don't abort.

### Keyboard & window management

Two layers, each its own SoT:

- **Karabiner** (`karabiner/karabiner.json`) — Caps Lock becomes a Hyper modifier; Hyper+letter launches an app. The JSON is the SoT for the launcher map — read its `to` `shell_command`s rather than trusting a copy.
- **AeroSpace** (`aerospace/aerospace.toml`) — tiling window manager. The toml self-documents monitor layouts, bindings, and app rules in its header, and sets `auto-reload-config`, so AeroSpace reloads itself on every save. Three docs live under `docs/aerospace/`, outside the dir the whole-dir link deploys: `RETILE-DELAY.md` (window-close retile bug, ghost/phantom watchdog, the alt-shift-d diagnose keystroke), `FULLSCREEN-ZORDER.md` (fake-fullscreen buried behind tiles), and `UPSTREAM-2026-09.md` (dated snapshot of upstream releases, open reports, and pending PRs that bear on this config, with the commands to re-derive it); each helper script's header is the SoT for its mechanics. `retile-on-quit-watcher.sh` compiles the watcher into `~/.cache/aerospace/bin` and generates its LaunchAgent plist from `$HOME`.

### Shell prompt (`starship/starship.toml`)

[Starship](https://starship.rs) prompt. The toml lists only deviations from Starship defaults — language/cloud modules are default-on and render contextually. `[custom.git_identity]` surfaces the active git account; it reads identity live, so no email literal is mirrored into the prompt config.

### Commit gate (`git/hooks/pre-commit`)

Wired via `core.hooksPath` in `git/identity`, and a no-op outside `~/dotfiles`. Two checks. This repo is public, so the first is a denylist over the staged tree: a commit that names a private layer or an employer term fails and prints the line; the pattern lives in the hook, and the hook file itself is the one path excluded from its own scan. The second is `scripts/check-doc-refs.sh`, deployed on PATH as `check-doc-refs [--strict] [<root>]`: a skill citing a `.sh`/`.md` or a `skills/…` path that does not exist, or an `install.conf.yaml` `link:` naming an absent source, fails the commit; `§ Section` citations warn unless `--strict`. It knows no project, so a layer repo wraps it with its own passes and runs it against its own root.
