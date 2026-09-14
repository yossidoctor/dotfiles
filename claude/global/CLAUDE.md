# Global CLAUDE.md

Behavioral rules for Claude Code, loaded every session. Section and rule names are stable IDs other docs cite; renaming one means updating its referencers.

**Terms.** A **falsifier** is the observable that proves a rule was broken. A rule's **carve-out** (`Skip:`) is what it deliberately doesn't cover. A **SoT** (source of truth) is the one file or command that owns a value.

## Making things

*Everything you author or change.*

### Is it true

- **Accuracy first.** Verify with Read or Bash before asserting; "don't know" beats a guess. A read backs only the span it covered; a verdict (unused, safe, broken) needs callers and invariants traced, not just facts collected; a timing claim is a `hyperfine` result with its deviation, not one run. Falsifier: an assertion whose support is not a Read/Bash result covering exactly it.
- **A supplied identifier needs a binding site, not a mention.** Before acting on an externally supplied value (address, account id, endpoint, key), find the config or consumer that would break if it were wrong; copies in prose, instructions, or generated data are one source, not many. No binding site → ask. Falsifier: a supplied value written into a config, fixture, commit, or query backed only by copies of itself.
- **Captured state is a lie waiting to happen.** Name the command that lists something live instead of listing it, unless this file is the value's SoT. Falsifier: a doc enumerating what one command would print.
- **A local ref is a cache; the remote is the state.** Fetch in the same command that reads a remote ref: `git fetch -q origin && git rev-parse origin/main`. Falsifier: a branch tip, "up to date", or ahead/behind count with no fetch that turn.
- **No backward-looking phrasing.** Authored text states the current invariant. A sentence that only makes sense against a removed or changed mechanism is history and belongs in the commit; a gotcha stays only where nothing else can hold it, as a standing property of the thing. Falsifier: a contrast with a prior state, a negated old mechanism, or a name carried forward from one.

### Does it live in one place

- **Strict single SoT.** Every literal lives in one file; a mirror carries an inline "derived from / cache of `<SoT>`" tag and then satisfies this rule. Falsifier: the same value in two tracked files with no tag.
- **Rules live where they fire.** A stage-specific rule sits inline in its stage; only cross-stage invariants are centralized. Falsifier: a one-stage rule in a shared preamble.

### Is it the minimal shape

- **Delete dead weight, don't reorganize it.** Remove pass-throughs, identity transforms, guards on cases upstream already excludes, and single-use helpers with no logic; don't wrap or rename them. Falsifier: such a layer kept, wrapped, or renamed.
- **A guard on a fallible producer reports; it does not repair.** Folding or capping a bad value in place hides a contract violation. Skip: parsers and normalizers, whose job is the correction. Falsifier: a value silently rewritten on a path whose contract forbade it.
- **It reads top-to-bottom as one flow.** *Code.* A linear main path; extract only named substance. Falsifier: the main path needs hops through trivial forwarding helpers.
- **Names carry domain meaning, not lineage.** Name what a thing is, not its position or origin; rename inherited names that lie, and only those. Falsifier: `parent`, `copyOf`, `from_v1` where a domain term exists.
- **No comments, no docstrings.** Code that needs prose gets clearer names and smaller functions; the why goes in the commit. Skip: machine-required text; a script's header block in a config repo, which its README declares the SoT for that script and which is maintained, not thinned. Falsifier: a diff leaving more comments than it found; a header asserting behavior the script no longer has.
- **A script on a hot path spends nothing before it knows it has work.** *Hooks, runners, anything invoked per tool call.* Cheapest discriminating test first, `jq` for JSON; mechanics in the `hook-lib.sh` header. Falsifier: an interpreter spawned on a path that exits without acting.
- **Every behavioral rule carries three roles, compressed without loss.** What to do, the carve-out, the falsifier; a role with nothing real behind it is omitted. Branch-only content goes to a reference file, never into an always-loaded one. Cite a source or state the content, never both. Falsifier: a rule missing a real role; an added sentence changing no behavior; a paraphrase beside its citation.

### How the edit lands

- **A fix lands where the defect is, as a rewrite, never as a layer beside it.** Restate the owning rule, function, or check so it covers the case by construction; a clause narrating the triggering case, or one more OR on a falsifier, is the same defect inside the right target. Nothing upstream can absorb it → write the missing rule or validator where it fires. Falsifier: a fix that added a bullet, branch, guard, or wrapper while the owning rule went untouched.
- **Surgical updates.** `Edit` with the minimum unique `old_string`, preserving surrounding structure; `Write` only for a new file or a rewrite the user asked for. Falsifier: a `Write` where targeted `Edit`s would land.
- **A tool that caused the trap is the defect.** *Skills, hooks, docs, runners.* When an error traces to missing or misleading guidance in a tool, fix the tool in the same session. Skip: your own misuse; a stale test (fix the test). Falsifier: a tool trap routed around without editing the tool.

## Explaining things

- **Draw it before you say it.** Any account of how parts relate opens with a fenced diagram, unasked; prose carries only the verdict, the anomaly, the ask, the why. Grammar and budget: `~/.claude/references/diagrams.md`. Skip: a single hop; a value lookup. Falsifier: relations or order explained in prose with no diagram in the same reply.

## Workspace mechanics

- **Several sessions share every working tree; touch only paths you edited.** `git stash`, `restore`, `checkout --`, `clean`, `reset`, and `add` take an explicit path; a committed version is read with `git show HEAD:<path>`. Skip: a repo this session created. Falsifier: a tree- or index-wide git command with no path operand.
- **A subagent gets only its prompt.** It starts in the session's project directory with the same CLAUDE.mds; paths, decisions, and error text go in the prompt string.
- **Git identity comes from git config, never from the session.** Mechanism: `~/dotfiles/README.md` § Git identity & credentials; a tree's email is `git config -f <scope file> user.email`. `# userEmail` is the Claude account and is no git identity. Falsifier: `# userEmail` used as an email or a credential key.
- **Read, Edit, and Write take the physical path, never a symlink.** Everything dotbot deploys is a link into a config repo; `readlink -f` resolves it (this file: `~/dotfiles/claude/global/CLAUDE.md`). Prose and `Bash` keep the deployed name. Falsifier: a `file_path` reaching a repo through a link.
- **Reading a file is `Read`, not `cat` or `sed -n`.** `enforce-read-over-shell-read.sh` denies the shell form and names the call to make.
- **A command names its own directory instead of riding a `cd`.** `git -C`, `poetry -C`, `make -C`, `npm --prefix`, `gh -R`. Falsifier: `cd <dir> && <cmd>` where `<cmd>` takes a directory flag.
- **The two config repos commit straight to `master`.** `~/dotfiles` (the public base) and the private layer installed on top of it (`readlink -f ~/.config/git/local.gitconfig` resolves into its tree) are solo repos: no branch, no PR. Each README owns its layout; its `install.conf.yaml` is the manifest, and a tracked file it does not declare is not deployed. Falsifier: a branch or PR there; a new tracked file with no manifest line.
- **Hooks and install steps run under macOS bash 3.2 and are table-tested.** `#!/usr/bin/env bash`, no bash-4 syntax without a version gate; an install `shell:` step is idempotent and carries `|| true` when it needs sudo or a TTY; every regex-gating hook has a `cases-<hook>.txt` run by its `tests/run-tests.sh`. Mechanics: the `hook-lib.sh` header. Falsifier: a bash-4 construct in a hook; a regex change with no case and no run.
