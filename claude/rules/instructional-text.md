---
paths:
  - "**/CLAUDE.md"
  - "**/AGENTS.md"
  - "**/.claude/**/*.md"
  - "**/claude/**/*.md"
---

# Instructional text

The measurements behind every rule here: `~/dotfiles/docs/claude/instructing-claude.md`. How a skill, pointer, or reference is shaped: the `writing-for-agents` skill.

- Rules live where they fire. A stage-specific rule sits inline in its stage; only a cross-stage invariant is centralized, because a one-stage rule in a shared preamble spends budget on every stage and sits far from its decision.
- A rule states the behaviour and its consequence. "Do X, because Y." The consequence is the best-evidenced lever (§ 5), and a requirement holds at depth where a prohibition decays, so the banned behaviour is named only when no positive form exists, and then beside its positive target. A carve-out (`Skip:`) stays inline only when something real is behind it. Skip: a simple fact or a one-line tool preference, which needs no consequence.
- **A falsifier lives in the reviewer, not in the text the writer acts on.** The observable that proves a rule was broken is applied to finished output by a context that did not write it (§ 7: a same-pass self-check misses about two thirds of its own errors), so it goes in the skill's `references/checks.md`, the gate that reviews the output, or the hook that decides it. The writer-facing text keeps the rule and its reason; each further clause there is one more tracked constraint against a ceiling of about six (§ 4).
- A mechanically decidable rule is a hook or a script check. When a shell command can tell the violation from the call (a path, a flag, a regex on the command line), the rule is enforcement in a PreToolUse hook or a validator in the companion script, and the prose is one line naming the reason, because a hook blocks where text only persuades (§ 2).
- A trim keeps the consequence and the carve-out, and emphasis is one line per file. Filler goes; a gotcha, an edge case and the reason stay. A `MUST`, `CRITICAL`, `MANDATORY` or caps imperative becomes a plain imperative that stays binding (a requirement trimmed to "consider" or "prefer" has been dropped), with its consequence, since aggressive framing over-triggers on current models (§ 5), and bold on many lines marks none. Branch-only content goes to a reference file behind a pointer that names the branch that reaches it.
- An agent definition is a roster, not a rule doc. A subagent holds its prompt and nothing else — no conversation, no prior turn, no shared premise — so a call the prompt never names is one it invents a form for. Name every call it makes and their order; give a command or a skill to load wherever a signal, check, or artifact is named; state the invocation form where a shell form looks plausible; say what the shell's whole job is, so logging and scratch files have no room to appear. Skip: a fork, which inherits the caller's context; a per-run dispatch, which ships identifiers and a verdict to an agent whose definition already holds the roster; a definition that is a model and effort pin alone, whose dispatch prompt is the whole roster (the skill that dispatches it owns which agents take that shape).
