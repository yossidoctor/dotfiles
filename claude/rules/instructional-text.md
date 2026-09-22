---
paths:
  - "**/CLAUDE.md"
  - "**/AGENTS.md"
  - "**/.claude/**/*.md"
  - "**/claude/**/*.md"
---

# Instructional text

Loads when a CLAUDE.md, skill, agent definition, output style, or rules file is touched.

- **Rules live where they fire.** A stage-specific rule sits inline in its stage; only cross-stage invariants are centralized. Falsifier: a one-stage rule in a shared preamble.
- **Every behavioral rule carries three roles, compressed without loss.** What to do; the carve-out (`Skip:`, what the rule deliberately doesn't cover); the falsifier (`Falsifier:`, the observable that proves the rule was broken, applied to finished text by a reader who did not write it). A role with nothing real behind it is omitted, never invented. In `CLAUDE.md` and an output style, both of which sit in the always-loaded prefix, the rule text carries the behaviour and its reason only: each further clause there is a tracked constraint against the measured ceiling (`~/dotfiles/docs/claude/instructing-claude.md` § 4), and a falsifier is a review tool for a reader who did not write the text, not a generation-time gate (§ 7); a rules file, loaded only on a matching touch, keeps all three inline. Trimming cuts filler, never a gotcha, edge case, carve-out, or falsifier, and never softens a MUST to a hedge; branch-only content goes to a reference file, not into an always-loaded one. A why-clause stays only when it names a consequence the reader cannot derive and would act on. Cite a source or state the content, never both. Skip: simple facts, one-line tool preferences. Falsifier: a rule missing a real role; a trim that dropped one or softened a MUST; an added sentence changing no behavior; a paraphrase beside its citation.
- **An agent definition is a roster, not a rule doc.** A subagent holds its prompt and nothing else — no conversation, no prior turn, no shared premise — so a call the prompt never names is one it invents a form for. Name every call it makes and their order; give a command or a skill to load wherever a signal, check, or artifact is named; state the invocation form where a shell form looks plausible; say what the shell's whole job is, so logging and scratch files have no room to appear. Skip: a fork, which inherits the caller's context; a per-run dispatch, which ships identifiers and a verdict to an agent whose definition already holds the roster. Falsifier: an agent reached for a tool, a shell form, or a scratch file its prompt never named; a definition named a check it gave no command and no skill to run it from.
