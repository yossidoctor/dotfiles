# Global CLAUDE.md

Behavioral rules for Claude Code, loaded every session. Section and rule names are stable IDs other docs cite; renaming one means updating its referencers.

**Terms.** A **falsifier** is the observable that proves a rule was broken. A rule's **carve-out** (`Skip:`) is what it deliberately doesn't cover. A **SoT** (source of truth) is the one file or command that owns a value.

## Making things

*Everything you author or change. A rule naming a surface (`*code*`, `*instructional text*`) is scoped to it; the rest bind everywhere.*

### Is it true

- **Accuracy first.** Verify with Read or Bash before asserting; "don't know" beats a guess. An empty grep means Read the source: a path, type, default, or convention is looked up, never inferred. A read backs only the span it covered. A verdict (unused, redundant, safe, broken) needs callers and invariants traced, not just facts collected, and a command re-run before the environment is blamed. Skip: a fact established earlier this session, never the subject it belongs to; language and tool knowledge no repo file owns. Falsifier: an assertion, a verdict included, whose support is not a Read/Bash result covering exactly it.
- **A supplied identifier needs a binding site, not a mention.** Before acting on an externally supplied value (address, account id, endpoint, key), find the config or consumer that would break if it were wrong; copies in prose, instructions, a rendered surface, or data the suspect writer produced are one source, not many. No binding site → ask. Skip: values the task itself mints; one confirmed this session. Falsifier: a supplied value written into a config, fixture, commit, or query backed only by copies of itself; a structure claim resting on a corpus the suspect writer populated.
- **Captured state is a lie waiting to happen.** Name the command that lists something live instead of listing it. Skip: values whose SoT is this file. Falsifier: a doc enumerating what one command would print.
- **A local ref is a cache; the remote is the state.** Fetch in the same command that reads a remote ref: `git fetch -q origin && git rev-parse origin/main`. Skip: a SHA that is itself the subject (a deployed commit, a merge-base), named as the commit it is. Falsifier: a branch tip, "up to date", or ahead/behind count with no fetch that turn.
- **No backward-looking phrasing.** Authored text states the current invariant. A sentence that only makes sense against a removed or changed mechanism is history and belongs in the commit; a gotcha stays only where nothing else can hold it, as a standing property of the thing. Skip: upstream deprecations, structural labels, variable names (`previous_status`). Falsifier: a contrast with a prior state, a negated old mechanism, or a name carried forward from one.

### Does it live in one place

- **Strict single SoT.** Every literal lives in one file; a mirror carries an inline "derived from / cache of `<SoT>`" tag and then satisfies this rule, so check the tag before reporting a duplicate. Falsifier: the same value in two tracked files with no tag; a tagged mirror reported as duplication.
- **Rules live where they fire.** *Instructional text.* A stage-specific rule sits inline in its stage; only cross-stage invariants are centralized. Falsifier: a one-stage rule in a shared preamble.

### Is it the minimal shape

- **Delete dead weight, don't reorganize it.** Remove pass-throughs, identity transforms, guards on cases upstream already excludes, and single-use helpers with no logic; don't wrap or rename them. Skip: genuine mappers and substantial single-use helpers; real work at the wrong level moves upstream (§ A fix lands where the defect is). Falsifier: such a layer kept, wrapped, or renamed.
- **A guard on a fallible producer reports; it does not repair.** Folding or capping a bad value in place hides a contract violation and leaves the producer unfixed. Skip: parsers and normalizers, whose job is the correction; an unparseable value, which fails at parse time. Falsifier: a value silently rewritten on a path whose contract forbade it.
- **It reads top-to-bottom as one flow.** *Code.* A linear main path; extract only named substance. Skip: substantial logic stays extracted, never inlined into one giant function. Falsifier: the main path needs hops through trivial forwarding helpers.
- **Names carry domain meaning, not lineage.** Name what a thing is, not its position or origin; rename inherited names that lie, and only those. Falsifier: `parent`, `copyOf`, `from_v1` where a domain term exists; a name asserting behavior the code no longer has.
- **No comments, no docstrings.** Code that needs prose gets clearer names and smaller functions; the why goes in the commit. A diff into a comment-dense file thins it. The bar is self-evident code, never confusing code. Skip: machine-required text; a script's header block in a config repo, which its README declares the SoT for that script and which is maintained, not thinned. Falsifier: a diff keeping a comment a name or structure could carry, or leaving more comments than it found; a header asserting behavior the script no longer has.
- **A script on a hot path spends nothing before it knows it has work.** *Hooks, runners, anything invoked per tool call.* Cheapest discriminating test first, `jq` for JSON; mechanics in the `hook-lib.sh` header. Skip: a one-shot script, where clarity wins. Falsifier: an interpreter spawned on a path that exits without acting.
- **Every behavioral rule carries three roles, compressed without loss.** What to do, the carve-out, the falsifier; a role with nothing real behind it is omitted, never invented. Trimming cuts filler, never a gotcha, edge case, carve-out, or falsifier, and never softens a MUST to a hedge; branch-only content goes to a reference file, not into an always-loaded one. A why-clause stays only when it names a consequence the reader cannot derive and would act on. Cite a source or state the content, never both. Skip: simple facts, one-line tool preferences. Falsifier: a rule missing a real role; a trim that dropped one or softened a MUST; an added sentence changing no behavior; a paraphrase beside its citation.

### How the edit lands

- **A fix lands where the defect is, as a rewrite, never as a layer beside it.** Restate the owning rule, function, or check so it covers the case by construction and reads as though it always did; a clause narrating the triggering case, or one more OR on a falsifier, is the same defect inside the right target. Nothing upstream can absorb it → write the missing rule or validator where it fires. Skip: new scope with no owner; a real enumeration gaining a row; an adapter at a boundary you don't control. Falsifier: a fix that added a bullet, branch, guard, or wrapper while the owning rule went untouched; the same guidance in two places.
- **Surgical updates.** Touch only the lines the change requires: `Edit` with the minimum unique `old_string`; `Write` only for a new file or a rewrite the user asked for or § A fix lands where the defect is demands. Falsifier: a `Write` where targeted `Edit`s would land; an edit restating untouched lines; this rule cited to license what another bans.
- **A tool that caused the trap is the defect.** *Skills, hooks, docs, runners.* When an error traces to missing or misleading guidance in a tool, fix the tool in the same session; reaching for a second approach because a tool misled you is the signal. Skip: your own misuse; a stale test (fix the test); genuinely new scope. Falsifier: a tool trap routed around without editing the tool.

## Explaining things

- **A table that earns its place is drawn as aligned columns in a code block.** UPPERCASE headers, a dashed rule under them, 3-space gutters, no pipes, no outer frame. Emoji belong in cells; an emoji or variation-selector char measures **2** columns, and the header row and data rows must end at identical widths (CJK counts as 2 too). Skip: a table inside a file whose format is fixed by its own conventions (a markdown doc, a README). Falsifier: a pipe-delimited or framed table in output; a column whose header and cells disagree on width.

```
SERVICE       TASK       GRADE          OWNER
-----------   --------   ------------   -------------
⛩️ Gateway    DON-6578   🔴 13 behind   Ron Likvornik
🤹 operator   DON-6753   🟣 synced      Ron Likvornik
```

- **A number series carrying a shape gets drawn, not described.** Counts over time, distributions, rankings — in a code block, multi-column if long; same for anything where ASCII/Unicode conveys structure faster than prose. Color: a `diff` fence renders `+` green and `-` red, for pass/fail verdict lists, never for aligned tables (the marker steals a column); emoji carry hue elsewhere, and color is never the only signal. Skip: unordered or tiny sets; a file whose format its own conventions fix. Falsifier: a series or hierarchy described in prose where one of these forms fits; color as the sole carrier of a distinction.

```
bars      2026-04 █▏14    2026-05 ███ 35     ranked magnitudes
spark     2023-08 ▁▃▂▁▂▃▄█▃▂ 2026-07         a whole series in one cell
waffle    ■■■■■■■□□□□□□□□□□□ 7%              part-to-whole
range     age ├───█────────────┤ 3..1088     min / median / max
columns     █                                shape over labels
          ▃ █ ▅
          08 09 10
tree      migrations/                        hierarchy, always aligns
          ├─ heal_order_io.ts    ran
          └─ backfill_city.ts    ran
```

## Workspace mechanics

- **Several sessions share every working tree; touch only paths you edited.** `git stash`, `restore`, `checkout --`, `clean`, `reset`, and `add` take an explicit path; a committed version is read with `git show HEAD:<path>`. Skip: a repo this session created. Falsifier: a tree- or index-wide git command with no path operand; a staged path this session did not edit.
- **The two config repos commit straight to `master`.** `~/dotfiles` (the public base) and the private layer installed on top of it (`readlink -f ~/.config/git/local.gitconfig` resolves into its tree) are solo repos: no branch, no PR. Each README owns its layout; its `install.conf.yaml` is the manifest, and a tracked file it does not declare is not deployed. Falsifier: a branch or PR there; a new tracked file with no manifest line.
- **Git identity comes from git config, never from the session.** Mechanism: `~/dotfiles/README.md` § Git identity & credentials; a tree's email is `git config -f <scope file> user.email`. `# userEmail` is the Claude account and is no git identity. Skip: `# userEmail` where the Claude account itself is the subject (attribution, account swaps). Falsifier: `# userEmail` used as an email or a credential key.
- **Read, Edit, and Write take the physical path, never a symlink.** Everything dotbot deploys is a link into a config repo; `readlink -f` resolves it (this file: `~/dotfiles/claude/CLAUDE.md`). Prose and `Bash` keep the deployed name. Skip: a linked dir whose target is not a repository (`/tmp` → `/private/tmp`). Falsifier: a `file_path` reaching a repo through a link.
- **Reading a file is `Read`, not `cat` or `sed -n`.** `enforce-read-over-shell-read.sh` denies the shell form and names the call to make.
- **A command names its own directory instead of riding a `cd`.** `git -C`, `poetry -C`, `make -C`, `npm --prefix`, `gh -R`. Skip: a command with no directory flag; a multi-directory sweep; a subshell `( cd … )`. Falsifier: `cd <dir> && <cmd>` where `<cmd>` takes a directory flag.
- **Before touching a hook or an install step, read the conventions.** `~/dotfiles/README.md` § Script conventions (bash 3.2, idempotent `shell:` steps, case files) and the `hook-lib.sh` header (payload parsing, live symlinked hooks). Falsifier: a hook or install-step change that breaks a convention stated there.
