# Setup audit — what was checked, what changed, what was rejected (2026-09-21)

Snapshot of one research pass over this machine's whole setup: ten fresh-context agents, each given the inventory and told to return only what the setup lacked, then every claim that a command could settle was settled on this machine. Dated: the verdicts below were true on 2026-09-21 against Claude Code 2.1.278, Homebrew 7.0.4, git 2.55, Ghostty 1.3.1, Karabiner 16.3.0, AeroSpace 0.21.3-Beta, macOS 27.0. Re-derive a verdict with the command beside it before acting on it a season later. Purpose: the next "what am I missing" pass starts from here instead of re-running the research.

## Adopted, and where it lives

Each row is now a standing property of a tracked file, which is the SoT; this table only says which.

```
CHANGE                                             SOT
------------------------------------------------   ------------------------------------------
Bash-tool sandbox (Seatbelt), credential deny      claude/settings.json § sandbox, README § Permissions
hook `if` filter, `async` side-effect hooks        claude/settings.json, README § Claude Code hooks
PermissionDenied logger                            claude/hooks/log-permission-denied.sh
subagent model fill only (bg is harness default)   claude/hooks/fill-subagent-model.sh
surface-scoped rules with paths: frontmatter       claude/rules/*.md, README § Layers
system prompt from file                            zsh/zshrc claude()
100k-line shared history                           zsh/zshrc
SSH commit signing, per-identity keys              git/config, git/identity, README § Git identity
git maintenance, geometric, machine-local include  git/config, README § Git identity
push.useForceIfIncludes and 8 other knobs          git/config
mergiraf merge driver                              git/config, git/attributes
gitleaks in the commit gate                        git/hooks/pre-commit
Brewfile tap trust per item                        brew/Brewfile
brew vulns + union drift over Brewfile.d           brew/brew-maintenance.sh, install.conf.yaml
duti read-back, terminal-notifier banners          mac/duti.sh, claude/hooks/notify-agent-idle.sh
Ghostty window-save-state, Starship module shell   ghostty/config, starship/starship.toml
#!/bin/bash pinned everywhere, .shellcheckrc       README § Script conventions
Touch ID sudo, firewall + stealth                  machine state: /etc/pam.d/sudo_local, socketfilterfw
```

Verify the machine half: `cat /etc/pam.d/sudo_local`; `/usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate --getstealthmode`; `launchctl list | grep git-scm`; `git log -1 --show-signature`.

## Rejected, with the reason

Re-open one only if its reason has changed.

- **shfmt as a commit gate.** Its formatting fights the repo's case-arm indentation and continuation layout in 31 of 38 scripts; a gate would either block every commit or rewrite the tree. `shfmt -d <file>` shows the disagreement.
- **`CLAUDE_CODE_SUBAGENT_MODEL_FORCE`.** Overrides every agent definition's own `model:` (docs: sub-agents § choose a model). The hook that fills only an omitted or `fable` model is the finer instrument.
- **`sandbox.credentials` deny on `~/.config/gh`.** gh keeps its tokens in the keychain; the directory holds only account names, and the deny broke every `gh` call and therefore `git push`. `grep -c oauth_token ~/.config/gh/hosts.yml` should stay 0.
- **`allowUnixSockets` for git's fsmonitor socket.** Neither `~/**` nor an absolute glob matched; `core.fsmonitor=false` for Bash-tool git via `GIT_CONFIG_COUNT` did. `GIT_CONFIG_PARAMETERS` is the sandbox's own variable.
- **AeroSpace monitor assignment by regex.** The work setup has two identical DELLs that only an index can tell apart; the index table already covers both setups (`aerospace list-monitors`).
- **Karabiner 16 variables driven from AeroSpace, sketchybar.** No use case for the first; the second is out by decision.
- **`teach` skill as `context: fork`.** It runs an interactive lesson loop a fork cannot hold.
- **`memory:` on the project agents.** They are stateless per dispatch by design.
- **Exec-form hook `args`.** Would hardcode the home path where `"$HOME"` stands now, for ~2 ms per hook.
- **Human-only CLI tools** (yazi, television, macmon, numbat, watchexec, sd, atuin, zsh-autosuggestions). Nobody types in this terminal; Claude cannot drive a TUI. The same argument covers the already-installed bat, eza, dust, duf, procs, glow, tlrc, btop, fzf-tab, zoxide, which `zsh/zshrc` disables under Claude Code anyway; pruning them is an open decision.
- **jaq / gojq.** jq 1.8 starts in 2.8 ms here (`hyperfine --shell=none 'jq -n empty'`); python3 at 16 ms is where hook latency is.
- **Desktop scheduled tasks and cloud routines** as the runner for machine-local jobs. This machine runs the CLI; the three prompt files under `~/.claude/scheduled-tasks/` have no schedule and nothing fires them. The runner for a local job here is a LaunchAgent generated from `$HOME`, the pattern of `claude/cswap-auto.sh`.
- **`git maintenance start` and any `git config --global` write.** Would replace the `~/.gitconfig` symlink with a copy; README § Git identity names the machine-local include instead.

## Checked and already right

Do not re-research: hooks as enforcement with prose as steering (now stated verbatim in Claude Code's memory docs); a falsifier per rule; the fresh-context audit receipt as a commit gate; the table-driven hook tests; single-SoT with tagged mirrors plus the citation checker; grep-first with no vector index (Anthropic's own A/B found agentic search ahead of RAG); `zdiff3`, `histogram`, `fsmonitor`, `rerere`; `fzf --zsh`; zsh-syntax-highlighting sourced last; no plugin manager at four plugins; HTTPS plus the custom `gh auth token --user` credential helper (gh has no per-account routing, cli/cli#8875, and `gh auth setup-git` would override it); `gitdir:` identity routing over `hasconfig:remote.*.url` (the latter cannot fire before a remote exists); `launchctl bootstrap` over `load`; Karabiner over kanata; JankyBorders with AeroSpace; dated upstream snapshots with re-derive commands.

## Open

Each waits on a decision; the verify-with command says whether it is still open.

- **Time Machine snapshots.** None exist (`tmutil listlocalsnapshotdates /`). Either a Time Machine destination, or a LaunchAgent running `tmutil localsnapshot` hourly.
- **Weekly retro LaunchAgent.** `claude -p` on a Monday schedule: aggregate `~/.cache/claude/permission-denied.jsonl` and the transcripts' hook denials, run `/insights`, refresh plugins (`claude plugin marketplace update` before `claude plugin update`, the latter alone reads a stale clone), write one dated doc. `ls ~/Library/LaunchAgents | grep retro` says whether it exists.
- **Tool wiring.** git-absorb, duckdb and hurl are installed and idle until the skill that owns the task names them.
- **Prune the human-only tools** from `brew/Brewfile` (list above).
- **`check-doc-refs.sh` matches a `§` cite against every heading in the repo**, not the cited file; two dangling cites passed it. Fix is to resolve the cited file first.
- **`sandbox.excludedCommands` and `allowWrite` tuning** after a week of prompts; `~/.cache/claude/permission-denied.jsonl` is the input.
- **Starship's `statusline claude-code` provider** (1.25+) as a replacement for `claude/statusline-command.sh`, only if it can render the account rows; `starship statusline --help`.

## Harness facts learned the hard way

Mechanisms, not versions, so they hold until the mechanism changes.

- A type error anywhere in `settings.json` makes Claude Code drop the whole file; the visible symptom is the statusline disappearing. Validate before trusting: `curl -sL https://json.schemastore.org/claude-code-settings.json -o "$TMPDIR/s.json" && uv run --with jsonschema python3 -c 'import json,sys;from jsonschema import Draft7Validator as V;print(len(list(V(json.load(open(sys.argv[1]))).iter_errors(json.load(open(sys.argv[2]))))),"errors")' "$TMPDIR/s.json" ~/.claude/settings.json`.
- Under the sandbox a Bash-tool call has no `/dev/fd`, so `<( … )`, `diff <( … )` and `grep -f <( … )` fail; `$TMPDIR` is the writable scratch; `.git/config` is write-denied even inside an allowed tree; a nested `claude -p` cannot start its own sandbox and cannot write its transcript under `~/.claude/projects`, so `scripts/rule-audit.sh` passes `--settings '{"sandbox":{"failIfUnavailable":false}}'`.
- bash 3.2 parses a `case` pattern's `)` inside `$( … )` as the end of the substitution; `bash -n` on the file passes and the failure appears at run time. `[[ x == pattern ]]` has no paren. `date +%s%3N` prints a literal `N`; there is no `EPOCHREALTIME`; `perl -MTime::HiRes` is the millisecond clock.
- A `… 2>&1 | grep -v noise` pipeline returns grep's status, which is 1 when nothing survived the filter, so an `&&` chain after it stops on success.
- `git commit --amend` amends HEAD, whatever commit the fix was meant for; a mis-aimed amend is repaired in a scratch worktree with `cherry-pick -n` and `update-ref`, never by force-pushing the mistake.
- `gh auth refresh` has no `--user`; it acts on the active account, so a second account needs `gh auth switch` around it.
