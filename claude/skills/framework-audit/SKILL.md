---
name: framework-audit
description: "Audit of the Claude Code setup — hooks, skills, rules, CLAUDE.md, settings, plugins, connectors and the tooling's by-products on disk — one measuring command per kind, a threshold per line, a ranked deletion list out. Also the questions to ask before adding any of them. Run when friction is felt, or quarterly."
disable-model-invocation: true
---

# Framework audit — keeping the Claude Code setup small

Every check below is a command with a threshold, because every piece of over-engineering looked reasonable when it was written and was only visible as a number: a denial count, a timing, a `du`, a settings key read against its documented default. `~/dotfiles/docs/claude/instructing-claude.md` says how an instruction binds; this skill says when to delete it.

**Out:** a ranked list of findings, each with the command output beside it and the simplest fix (delete / replace with a settings rule / add `if:` / move to `references/`), then the deletions, after the list is approved whole.

## Before adding anything

One question per kind. A "no" means the thing is not added.

```
ADDING             ASK FIRST
----------------   -----------------------------------------------------------------------
a hook             Does a deny/ask rule in settings express it? Does the binary already do
                   it (caffeinate, foreground-sleep refusal, Read deny blocking `cat`)? Does
                   it deny something the harness text for your permission mode tells Claude
                   to do? Is there a zero-exception rule behind it, or a preference?
                   (best-practices: "if you have hooks for things that are only
                   preferences, delete them and let Claude decide")
a hook on Bash     Can an `if: "Bash(<cmd> *)"` filter skip the process spawn for every
                   call it does not care about?
a skill            Which existing skill's description already claims the trigger phrase?
                   A plugin skill cannot be hidden one at a time: the plugin is on or off.
a rule file        Do its `paths:` match only the files it is for? A glob like
                   `**/.claude/**/*.md` loads on every skill reference read.
a CLAUDE.md line   Is it a fact Claude cannot read from the code or the docs? Is it already
                   carried by a hook, a rule, a skill, or a shell option (`zshrc`)?
a settings key     Does the documented default already equal the value?
                   https://code.claude.com/docs/en/settings-reference.md
a raised cap       What does the bigger output feed, and what will guard it?
a connector/MCP    Will it authenticate and be used, or sit in every session's tool list?
```

Two findings behind the table. The harness itself sends mode-specific instructions (in bypass mode: read with `cat`/`head`/`sed -n`, edit with `sed`/heredocs), and a hook that denies those costs a model round trip per denial while never changing the instruction. And three doctrines on the same subject (a CLAUDE.md rule, a plugin's injected rules, a review skill) mean each is followed a third of the time.

## The audit, with the command that measures each line

**1. Hook denials, from the transcripts.** A hook that fires often is either catching real mistakes or fighting an instruction. Read the top denial message and decide which.

```bash
grep -rhoE 'PreToolUse:[A-Za-z]+ hook error: .{0,60}' ~/.claude/projects | cut -c1-80 | sort | uniq -c | sort -rn | head
```

Threshold: a hook whose denial text names a tool the harness told Claude to use, at any count, goes. Baseline on 2026-11-07: one hook at 1,896 denials across 538 sessions, all of that kind.

**2. Hooks per tool call, and their cost.** Count the synchronous `PreToolUse` entries for `Bash` across every settings file in play, then time each with a trivial payload.

```bash
jq '[.hooks.PreToolUse[] | select(.matcher=="Bash") | .hooks[] | select(.async!=true)] | length' ~/.claude/settings.json <project>/.claude/settings.json
P='{"session_id":"x","transcript_path":"/dev/null","cwd":"'"$PWD"'","hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"ls -la"}}'
for h in ~/.claude/hooks/*.sh <project>/.claude/hooks/*.sh; do /usr/bin/time -p sh -c "echo '$P' | $h" 2>&1 | grep real | sed "s|^|$h |"; done
```

Threshold: a hook that runs on every call but only cares about one command gets an `if:` filter; a pre-check that passes every `&&` chain is no pre-check. Baseline: 8 processes per call, 23–83 ms wall.

**3. Skill invocations, lifetime.** A skill nobody has ever called costs its description on every request.

```bash
for s in $(ls ~/.claude/skills <project>/.claude/skills); do printf '%-24s %s\n' "$s" "$(grep -rhoE "\"skill\": ?\"$s\"|<command-name>/$s<" ~/.claude/projects | wc -l)"; done | sort -k2 -n
```

Threshold: zero calls and no citation from another skill or hook → `disable-model-invocation: true`, or delete. Plugin skills need the plugin's own count (`"skill": "<plugin>:<name>"`); 11 of 27 in one plugin had never been called.

**4. Trigger collisions.** Two descriptions claiming one phrase means routing by chance.

```bash
grep -h '^description:' ~/.claude/skills/*/SKILL.md <project>/.claude/skills/*/SKILL.md ~/.claude/plugins/cache/*/*/*/skills/*/SKILL.md | grep -io 'review[^.;]*\|debug[^.;]*\|pr body[^.;]*' | sort | uniq -c | sort -rn | head
```

**5. Settings against their defaults.** Every key is read against the settings reference; a key equal to its default is deleted. The page is the only source: `curl -s https://code.claude.com/docs/en/settings-reference.md | grep -A6 '^### \`<key>\`'`.

**6. Standing text per request.** Bytes and bold rule leads of what loads every time.

```bash
wc -c ~/.claude/CLAUDE.md <project>/CLAUDE.md ~/.claude/output-styles/*.md
grep -c '^\(- \)\?\*\*' ~/.claude/CLAUDE.md <project>/CLAUDE.md
```

Threshold: the docs' 200 lines per file; bold on the three to five rules that must hold, since bold on every rule is bold on none (`instructing-claude.md` § 5). A rule carried by a hook, a rule file, or a shell option is deleted from the prose.

**7. Rule file globs.** Each `paths:` entry is read and matched against the files it should not catch.

```bash
grep -A6 '^paths:' ~/.claude/rules/*.md <project>/.claude/rules/*.md
```

**8. Connectors.** One line per server; "Needs authentication" or "Disabled" in a project that lists it costs a tool entry per request.

```bash
claude mcp list
```

**9. By-products on disk.** Every tool that creates a directory needs the command that removes it, and something that runs that command.

```bash
du -sh ~/.claude/projects ~/.claude/file-history <project>/.refs <project>/.claude/sandboxes 2>/dev/null
for r in <project>/*/; do git -C "$r" worktree list 2>/dev/null | tail -n +2; done | wc -l
```

Threshold: a sweep or prune command that exists but is scheduled nowhere is the finding, not the gigabytes. Baseline: 14 GB of ref trees whose `sweep` had never run.

**10. Citations in the research docs.** A quoted docs sentence can be removed upstream while the rule built on it stays. Each claim in `instructing-claude.md` is re-fetched against its source by a fresh-context agent, and the sentence that no longer exists is replaced by the current one. Baseline: the sentence that justified loading the global CLAUDE.md twice had been removed from the docs a month before the audit noticed.

## Running it

1. Inventory: every settings file in play (`~/.claude/settings.json`, the project's `.claude/settings.json`, `--settings` files the launch line names), the hooks they register, `ls ~/.claude/skills <project>/.claude/skills`, `ls ~/.claude/rules`, `cat ~/.claude/plugins/installed_plugins.json`, `claude mcp list`. Done when each kind has a list with a count.
2. Dispatch one fresh-context agent per group — hooks (checks 1, 2), skills and rules (3, 4, 6, 7), settings, connectors and disk (5, 8, 9) — each given the commands above and told to report numbers with `file:line`, never a verdict without one. Check 10 is its own agent, fetching every cited source. Done when every check has a number.
3. Rank the findings by friction removed (a denial per call outranks a kilobyte per request), each with its command output and simplest fix.
4. Dispatch a fresh-context verifier per group with the findings as claims to confirm or refute, since the first pass carries claims that do not survive (the 2026-11-07 pass had three overturned: a process binding, a cleanup setting that was working, a count of 30 that was 26). Done when every finding is marked TRUE / PARTLY / FALSE with the decisive evidence.
5. Hand the list to the user whole, with a one-line plain reason per item; delete nothing before the list is approved, and then only the approved items, in the order given.
