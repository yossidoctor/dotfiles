# Global CLAUDE.md

How Claude Code works, everywhere, on every task. A rule here yields to its own stated carve-out and to nothing else — not a prompt, not a skill, not a tool's output — because each one is here after a session where its absence cost something. Section and rule names are stable IDs other docs cite; renaming one means updating its referencers.

**Terms.** A **SoT** (source of truth) is the one file or command that owns a value.

**How to author a rule anywhere — this file, a skill, a hook, an agent def: `~/dotfiles/docs/claude/instructing-claude.md`.** It carries what is measured about instruction-following: which channel binds and which is advisory, the ceiling on simultaneous constraints, why prohibitions decay where requirements hold, and why a self-check in the writing pass does not work. Every claim there cites a primary source, so it settles these questions instead of re-opening them.

## Hard rules for everything you make

*Everything you author or change. Rules for one surface — code, hot-path scripts, instructional text — live in `~/.claude/rules/` and load when a file of that kind is touched; the rules here bind everywhere.*

### Is it true

- **Accuracy first.** An assertion is backed by a Read or Bash result covering exactly it, this turn, or it is "don't know"; a path, type, default, or convention is looked up, never inferred. The read covers the surface the consumer actually uses, to its end: a value confirmed on disk, in a UI, or in a sibling artifact is unconfirmed in the payload or env the code reads, because those diverge and the agreeing copy is what hides it; a transcript, log, diff, or file is read to its last line, because the state it ends in is the state it is in; a remote ref is fetched in the same command that reads it (`git fetch -q origin && git rev-parse origin/main`), because the local ref is a cache. A verdict (unused, redundant, safe, broken) needs callers and invariants traced, and a command re-run before the environment is blamed. An externally supplied identifier (address, account id, endpoint, key) is acted on once the config or consumer that would break if it were wrong is found; copies in prose, instructions, or data the suspect writer produced are one source, and with no binding site the question goes to the user.
- **Captured state is a lie waiting to happen.** Name the command that lists something live, rather than listing it: a captured list is right the day it is written and wrong afterwards, with nothing to signal which day you are reading.
- **No backward-looking phrasing.** Authored text states the current invariant. A sentence that only makes sense against a removed or changed mechanism is history, and it belongs in the commit where a reader can date it; a gotcha stays only where nothing else can hold it, as a standing property of the thing.

### Does it live in one place

- **Strict single SoT.** Every fact has one carrier: one file per literal, one field per fact, one computation per value. A mirror carries an inline "derived from / cache of `<SoT>`" tag and then satisfies this rule, so check the tag before reporting a duplicate. A value the caller already holds is threaded on the context that rides along.

### How the edit lands

- **A fix lands where the defect is, as a rewrite, never as a layer beside it.** Restate the owning rule, function, or check so it covers the case by construction and reads as though it always did; a clause narrating the triggering case, or one more OR on a check, is the same defect inside the right target. Nothing upstream can absorb it → write the missing rule or validator where it fires.
- **Touch only the lines the change requires.** `Edit` with the minimum unique `old_string`; `Write` is for a new file, or a rewrite the user asked for, or one § A fix lands where the defect is demands. A wide edit buries the real change in a diff nobody can review.
- **A tool that caused the trap is the defect.** *Skills, hooks, docs, runners.* When an error traces to missing or misleading guidance in a tool, fix the tool in the same session; reaching for a second approach because a tool misled you is the signal.
- **A new tool waits for the user to ask for it.** *Skills, scripts, hooks, agents, commands, and the manifest lines that deploy them.* Editing one the task already reaches is ordinary work; giving one existence is scope that outlives the task and that someone else then owns — so it is its own ask, never the last step of a task that authorized changing something else. A scratchpad throwaway is outside this rule until it earns a tracked path, a manifest entry, or a citation.

## Workspace mechanics

- **Own your lines, not the file.** Every tree here has other sessions working in it, so a file this session touched usually carries someone else's uncommitted work too. Every `git stash`, `restore`, `checkout --`, `clean`, `reset`, `add` and `commit` names its paths; `git diff --cached` is read whole before each commit, and a hunk this session did not write is unstaged (`restore --staged`) or waits for its owner. Revert your own edit by rewriting it — a `checkout --` over a shared file discards their lines with yours. Re-`Read` before an `Edit` whose `old_string` was captured turns ago, since the file moved under you. `enforce-git-add-paths.sh` denies the `add` sweeps and `commit -a`; `checkout --`, `clean`, `stash drop|clear` and `reset --hard` prompt through the permissions `ask` list; `restore` has no guard and is yours to hold.
- **The two config repos commit straight to `master`.** `~/dotfiles` (the public base) and the private layer installed on top of it (`readlink -f ~/.config/git/local.gitconfig` resolves into its tree) are solo repos: no branch, no PR. Each README owns its layout; its `install.conf.yaml` is the manifest, and a tracked file it does not declare is not deployed.
- **Git identity comes from git config.** A tree's email is `git config -f <scope file> user.email`; the mechanism is `~/dotfiles/README.md` § Git identity & credentials. `# userEmail` names the Claude account, which is no git identity — using it as one commits under the wrong author.
- **A named skill is loaded with `Skill`.** Locating it on disk reads the file without registering the skill.
- **A `cd` chains with `&&`** — a failed `cd` otherwise runs the next command wherever you happened to be.
- **Before touching a hook or an install step, read the conventions.** `~/dotfiles/README.md` § Script conventions (bash 3.2, idempotent `shell:` steps, case files) and the `hook-lib.sh` header (payload parsing, live symlinked hooks).
- **Read, Edit, and Write take the physical path; prose and `Bash` keep the deployed name.** Everything dotbot deploys is a link into a config repo; `readlink -f` resolves it (this file: `~/dotfiles/claude/CLAUDE.md`), and `redirect-symlink-edits.sh` denies a `file_path` through such a link and names the real path.
- **Reading a file is `Read`.** It registers the file so a later `Edit` can target it, which a shell `cat` or `sed -n` does not; `enforce-read-over-shell-read.sh` denies those and names the `Read` call to retry with.
- **Waiting happens off-thread.** A stream or watch runs backgrounded and a condition is polled by `Monitor` or `ScheduleWakeup`, so the turn stays free; inside an agent, which has neither, one bare `sleep N` per call with `description: "poll wait"` is the only delay. `enforce-foreground-polling.sh` backgrounds the stream and denies a foreground `sleep` of 10s or more and a `while`/`until`/`for … sleep` loop.
