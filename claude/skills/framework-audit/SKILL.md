---
name: framework-audit
description: "Audit of the Claude Code setup — hooks, skills, rules, CLAUDE.md, settings, plugins, connectors and the tooling's by-products on disk — one measuring command per kind, a threshold per line, a ranked deletion list out. Also the questions to ask before adding any of them. Run when friction is felt, or every `cleanupPeriodDays` days, since its transcript counts see no further back."
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
                   A plugin skill's listing cannot be hidden one at a time (`skillOverrides`
                   skips plugin skills); a `Skill(<plugin>:<name>)` deny rule only blocks the call.
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
SINCE=$(jq -r 'select((.display|type)=="string") | select(.display|startswith("/framework-audit")) | .timestamp/1000 | strftime("%Y-%m-%d")' ~/.claude/history.jsonl | sort -u | grep -vx "$(date -u +%F)" | tail -1)   # the last day before today this audit was typed
grep -rhE '"content":"PreToolUse:[A-Za-z|]+ hook error: ' ~/.claude/projects | jq -rR --arg since "$SINCE" 'fromjson? | select((.timestamp // "") >= $since) | .message.content[]? | select(.type == "tool_result" and (.content | type == "string") and (.content | startswith("PreToolUse:"))) | [.tool_use_id, .content[:400]] | @tsv' | sort -u -t$'\t' -k1,1 | cut -f2 | sed -E 's#[~/][^ ":]*/[^ ":]*#<path>#g' | cut -c1-90 | sort | uniq -c | sort -rn | head
```

The `"content":"` anchor keeps the count to tool results: transcripts also quote hook text (an audit session, a `cat` of a hook, each request's recorded system prompt), which an unanchored grep counts. The `sed` masks each path, since a denial that opens with the denied file's path otherwise fills the line with it and hides which hook spoke. `jq` keeps one row per tool-call id and drops rows older than `SINCE` by each denial's own `timestamp`: a resumed session repeats its old denials in a new file, so a count of lines, or a cut by file mtime, reads them as new. Threshold: a hook whose denial text names a tool the harness told Claude to use, at any count, goes. Baseline on 2026-11-07: one hook at 1,896 denials across 538 sessions, all of that kind.

**2. Hooks per tool call, and their cost.** Count the synchronous `PreToolUse` entries for `Bash` across every settings file in play, then time each registered one twice: with `ls -la`, which every hook drops at its opening `case` (the cost every call pays), and with a command that `case` lets through (the cost of a call it parses).

```bash
jq '[.hooks.PreToolUse[] | select(.matcher=="Bash") | .hooks[] | select(.async!=true)] | length' ~/.claude/settings.json <project>/.claude/settings.json
jq -r '.hooks.PreToolUse[] | select(.matcher=="Bash") | .hooks[] | select(.async!=true) | "\(.command)\t\(.if // "every call")"' ~/.claude/settings.json <project>/.claude/settings.json
CMD=$(cat <<'EOF'
ls -la
EOF
)   # then a command past the hook's opening case; a heredoc, since the hooks under test read this call too and treat a heredoc body as data
P=$(mktemp); T=$(ls -t ~/.claude/projects/*/*.jsonl | head -1)
jq -cn --arg c "$CMD" --arg d "$PWD" --arg t "$T" '{session_id:"x",cwd:$d,transcript_path:$t,hook_event_name:"PreToolUse",tool_name:"Bash",tool_input:{command:$c}}' > "$P"
time (for i in 1 2 3 4 5 6 7 8 9 10; do <hook path> < "$P" >/dev/null; done)
```

Only a registered hook is run: the hooks directory also holds a sourced library and SessionStart and PostToolUse scripts, and a SessionStart script run by hand does its work (regenerating an index). Threshold: a hook that runs on every call but only cares about one command gets an `if:` filter; a pre-check that passes every `&&` chain is no pre-check. Baseline on 2026-11-15: 7 registered, 2 started by a plain call (3 on the 30% of calls holding `$VAR` or `$(`, which run an `if:` hook anyway), 4 ms each over a bare process start at the opening `case`, 17–26 ms past it.

**3. Skill invocations, over the transcript retention window** (`cleanupPeriodDays`). A skill nobody has called costs its description on every request.

```bash
D=$(mktemp -d)
grep -rhoE '"id":"toolu_[A-Za-z0-9]+","name":"Skill","input":\{"skill":"[^"]+"' ~/.claude/projects | sort -u | sed -E 's/.*"skill":"//; s/"$//' | sort | uniq -c > "$D/calls"
grep -roE --exclude-dir=subagents '"(text|content)":"<command-message>[^<]+</command-message>' ~/.claude/projects | sed -E 's/^([^:]+):.*<command-message>([^<]+)<.*/\2 \1/' | sort -u | cut -d' ' -f1 | sort | uniq -c > "$D/typed"
for s in $(ls ~/.claude/skills; ls <project>/.claude/skills); do printf '%-28s %s %s\n' "$s" "$(awk -v s="$s" '$2==s{n=$1} END{print n+0}' "$D/calls")" "$(awk -v s="$s" '$2==s{n=$1} END{print n+0}' "$D/typed")"; done | sort -k2 -n
```

The two numbers are model calls (unique tool-call ids, since a resumed session repeats its calls in a new file) and sessions where the user typed the command (`--exclude-dir=subagents` leaves out the copies an agent definition's `skills:` field preloads into its subagents). Each grep reads the transcripts once and counts every skill from that pass, since one pass over 2 GB takes about 20 seconds. Both patterns anchor on unescaped JSON quotes, which only a real call has: a transcript that quotes a skill name (a `cat` of a skill, an audit session) holds it escaped. Threshold: zero on both and no citation from another skill, a `references/` file or a hook → `disable-model-invocation: true`, or delete. A plugin skill is counted the same way with `<plugin>:<name>` as `$s`, and a plugin whose own hook reads a skill's file is using that skill; baseline on 2026-11-08: 16 of 27 in one plugin never called, 13 of them already hidden.

**4. Trigger collisions.** Two descriptions claiming one phrase means routing by chance.

```bash
D=$(mktemp -d)
skill_files() { ls ~/.claude/skills/*/SKILL.md <project>/.claude/skills/*/SKILL.md; jq -r '.plugins[][0].installPath' ~/.claude/plugins/installed_plugins.json | while read -r p; do jq -r --arg p "$p" '.skills // empty | .[] | "\($p)/\(.)/SKILL.md"' "$p/.claude-plugin/plugin.json" | grep . || ls "$p"/skills/*/SKILL.md; done; }
skill_files | xargs awk 'FNR==1{if(d)print "";d=0} /^description:/{d=1;printf "%s\t",FILENAME} d&&!/^(description:|[ \t])/{print "";d=0} d{printf "%s ",$0} END{if(d)print ""}' > "$D/desc"
for w in review debug 'pr body' 'port.forward' deploy; do printf '%s: %s\n' "$w" "$(grep -icE -- "$w" "$D/desc")"; grep -iE -- "$w" "$D/desc" | cut -f1 | sed 's/^/  /'; done
```

`skill_files` lists the skills that load: a plugin's are the ones its manifest names, or its `skills/` folder when the manifest names none. Threshold: a word two descriptions claim where neither hands it to the other by name (`Not: … (other-skill)`).

**5. Settings against their defaults.** Every key is read against its section of the settings reference; a key equal to its default is deleted, and so is one the section says has no effect beside another value these settings hold (telemetry off, a model that ignores the key). The page is the only source, and the command prints the key's whole section, since the `Default` line sits up to 16 lines under the heading:

```bash
curl -s https://code.claude.com/docs/en/settings-reference.md | awk -v k='<key>' 'index($0, "### `" k "`") == 1 {p=1; print; next} p && /^#{2,3} / {exit} p'
```

**6. Standing text per request.** Bytes, and bold sentences outside tables, of what loads every time; a span that ends a sentence or runs three words is a rule lead, a bolded term or label is not.

```bash
wc -c ~/.claude/CLAUDE.md <project>/CLAUDE.md ~/.claude/output-styles/*.md
for f in ~/.claude/CLAUDE.md <project>/CLAUDE.md ~/.claude/output-styles/*.md; do printf '%s %s\n' "$(grep -v '^|' "$f" | grep -oE '\*\*[^*]+\*\*' | grep -cE '[.!?]\*\*$|( [^ ]+){2}')" "$f"; done
```

Threshold: the docs' 200 lines per file; bold on one line per file, the number `~/.claude/rules/instructional-text.md` sets. A rule carried by a hook, a rule file, or a shell option is deleted from the prose.

**7. Rule file globs.** Each `paths:` entry is read and matched against the files it should not catch.

```bash
awk 'FNR==1{p=0} /^paths:/{p=1} p&&/^---/{p=0} p{print FILENAME": "$0}' ~/.claude/rules/*.md <project>/.claude/rules/*.md
```

**8. Connectors.** One line per server, then real calls per server over the transcript window. A "Connected" server loads every tool it has into each session, called or not, and a "Needs authentication" one still loads its sign-in tools; a "Disabled" one loads nothing. Threshold: a loaded server at zero calls is switched off for the project in `/mcp`, or disconnected.

```bash
claude mcp list
grep -rhoE '"type":"tool_use","id":"toolu_[A-Za-z0-9]+","name":"mcp__[A-Za-z0-9_-]+__' ~/.claude/projects | sort -u | sed -E 's/.*"name":"mcp__//; s/__$//' | sort | uniq -c | sort -rn
```

**9. By-products on disk.** Every tool that creates a directory needs the command that removes it, and something that runs that command.

```bash
du -sh ~/.claude/projects ~/.claude/file-history <project>/.refs <project>/.claude/sandboxes 2>/dev/null
for r in <project>/*/; do git -C "$r" worktree list 2>/dev/null | tail -n +2; done | awk '{print ($1 ~ /\/\.worktrees\//) ? "sandbox" : ($1 ~ /\/\.refs\//) ? "ref tree" : "other: " $1}' | sort | uniq -c
```

Threshold: a sweep or prune command that exists but is scheduled nowhere is the finding, not the gigabytes. Baseline: 14 GB of ref trees whose `sweep` had never run.

**10. Citations in the research docs.** A quoted docs sentence can be removed upstream while the rule built on it stays. Each claim in `instructing-claude.md` is re-fetched against its source by a fresh-context agent, and the sentence that no longer exists is replaced by the current one. Baseline: the sentence that justified loading the global CLAUDE.md twice had been removed from the docs a month before the audit noticed.

**11. Harness drift.** The CLI ships several versions a week, and every hook, rule, setting and CLAUDE.md line was written against one of them. Every changelog entry since check 1's `$SINCE` (30 days when it is empty) lands in one bucket:

```
BUCKET      THE ENTRY IS                                                THEN
---------   ---------------------------------------------------------   ------------------------------------------
redundant   a capability a hook, rule or CLAUDE.md line hand-rolls      delete the line, cite the entry
conflict    a default or harness text a rule now contradicts            reconcile; the binary's side wins unless the
                                                                        rule states its reason
broken      a tool, setting, flag, env var or hook field renamed,       grep the framework for the old name
            removed or re-scoped
new         a capability nothing in the framework points at             note it; a pointer waits for a task that
                                                                        hand-rolled it
none        everything else                                             —
```

The changelog carries no dates; the npm registry does, so the window is cut by publish date and the changelog is sliced at the oldest version in it.

```bash
claude --version
curl -s https://registry.npmjs.org/@anthropic-ai/claude-code | jq -r --arg since "${SINCE:-$(date -v-30d +%Y-%m-%d)}" '.time | to_entries[] | select(.key|test("^[0-9]")) | select(.value >= $since) | "\(.value[:10]) \(.key)"' | sort
OLDEST=<first version printed>
curl -sL https://raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md | awk -v oldest="$OLDEST" 'BEGIN{split(oldest,o,".")} /^## /{split($2,v,"."); if (v[1]+0<o[1]+0 || (v[1]==o[1] && (v[2]+0<o[2]+0 || (v[2]==o[2] && v[3]+0<o[3]+0)))) exit} {print}'
grep -RnF -- '<name>' ~/.claude/settings.json <project>/.claude/settings.json <project>/.claude/settings.local.json ~/.claude/hooks <project>/.claude/hooks ~/.claude/skills <project>/.claude/skills ~/.claude/rules <project>/.claude/rules <project>/.claude/agents ~/.claude/output-styles ~/.claude/statusline-command.sh ~/.claude/CLAUDE.md <project>/CLAUDE.md
```

Threshold: done when every entry carries a bucket, and every redundant / conflict / broken entry carries the `file:line` its grep found or "no reference". A redundant or conflict entry with a `file:line` is a finding. Baseline on 2026-11-08: 1,359 entries over 20 versions (`2.1.296`–`2.1.319`).

## Running it

1. Inventory: every settings file in play (`~/.claude/settings.json`, the project's `.claude/settings.json`, `--settings` files the launch line names), the hooks they register, `ls ~/.claude/skills <project>/.claude/skills`, `ls ~/.claude/rules`, `cat ~/.claude/plugins/installed_plugins.json`, `claude mcp list`, `claude --version`, and check 1's `SINCE` line, run once so every agent of step 2 is handed its value. Done when each kind has a list with a count.
2. Dispatch one fresh-context agent per group — hooks (checks 1, 2), skills and rules (3, 4, 6, 7), settings, connectors and disk (5, 8, 9) — each given the commands above and told to report numbers with `file:line`, never a verdict without one. Check 10 is its own agent, fetching every cited source. Check 11 is its own agent per ~700 changelog entries, each given the sliced changelog and the step-1 inventory. Done when every check has a number.
3. Rank the findings by friction removed (a denial per call outranks a kilobyte per request), each with its command output and simplest fix.
4. Dispatch a fresh-context verifier per group, checks 10 and 11 included, with every finding as a claim to confirm or refute by re-running its command, never by reading the first pass's output, since the first pass carries claims that do not survive (the 2026-11-07 pass had three overturned; the 2026-11-08 pass dropped ten claims, among them a `.worktrees` over-match that was the place code is written). Done when every finding is marked TRUE / PARTLY / FALSE with the command and output that decided it.
5. Hand the user the TRUE findings and the verified part of each PARTLY, whole, each with its evidence and a one-line plain reason; a FALSE or unverified claim is listed as dropped, with what refuted it. Delete nothing before the list is approved, and then only the approved items, in the order given.
