# Instructing Claude — Knowledge Base

*Standing reference for how a written instruction reaches Claude and whether it changes behaviour. Every claim here traces to a primary source — Anthropic's own documentation, or a measured study, cited inline. Researched 2026-09-17 across six parallel investigations. Read this before authoring or rewriting any rule file, skill, hook, or agent definition, and before concluding that a rule was ignored.*

The question this answers: **a rule was written clearly, was read, was agreed to, and was violated anyway. What actually fixes that?**

The short answer is that most of the intuitive fixes are measured to do nothing, and two of them make it worse.

---

## Table of contents

**Read by task**

- Authoring or rewriting a rule file → [§ 2 Channels](#2-the-channels-and-what-each-buys), [§ 4 Constraint budget](#4-the-constraint-budget), [§ 5 Wording](#5-wording--what-helps-and-what-backfires)
- A rule keeps being ignored → [§ 3 Diagnosis](#3-diagnosing-a-violated-rule), [§ 6 Failure modes](#6-the-failure-modes-named)
- Designing a review or audit step → [§ 7 Review](#7-review--fresh-context-beats-everything)
- Deciding hook vs prose → [§ 2 Channels](#2-the-channels-and-what-each-buys)
- Budgeting context or cost → [§ 8 Cost](#8-what-instructions-cost)

**Read whole** before rewriting a rule file. The sections interlock: the constraint budget is what makes the channel table actionable, and the failure taxonomy is what makes the review design non-obvious.

---

## 1. The one-paragraph version

Claude reliably follows about **five or six** simultaneous constraints. Past that, joint compliance collapses multiplicatively even though each individual rule still reads fine. Emphasis does not raise that ceiling and, on current models, overtriggers. A `CLAUDE.md` file is delivered as an ordinary user message and is documented as advisory, not enforced. A model cannot reliably check its own output against a criterion in the same pass that produced it, and reviewing its own work has a measured **64.5%** blind spot that a fresh context removes. Therefore: cut the rule count, convert prohibitions into requirements, move anything mechanically decidable into a hook, and put the judgment-bearing check in a separate pass with no authorship history.

---

## 2. The channels, and what each buys

Instructions reach the model through several channels that look interchangeable and are not. Ranked by binding force, strongest first:

```
CHANNEL                   DELIVERY                        BINDING
-----------------------   -----------------------------   ------------------------
PreToolUse hook (deny)    blocks the call outright        enforcement, not text
Hook additionalContext    system-reminder, at the action  fires at the decision
Output style              system prompt, EVERY request    + mid-conversation reminder
--append-system-prompt    system prompt, every request    same layer, appended
CLAUDE.md                 a user message, once            advisory, no guarantee
Skill body                loaded on invocation            scoped to the task
```

**The documented facts behind that table:**

> "CLAUDE.md content is delivered as a **user message after the system prompt**, not as part of the system prompt itself. Claude reads it and tries to follow it, but **there's no guarantee of strict compliance**." — [memory](https://code.claude.com/docs/en/memory)

> "Claude treats them as context, **not enforced configuration**." … "To **block** an action regardless of what Claude decides, use a PreToolUse hook instead." — same page

> "Claude Code sends the active style's instructions **with every request**. When you select a style other than Default, Claude Code **also reminds Claude of the style during the conversation**." — [output-styles](https://code.claude.com/docs/en/output-styles)

> "Claude Code **wraps the string in a system reminder** and inserts it into the conversation **at the point where the hook fired**." — [hooks](https://code.claude.com/docs/en/hooks)

**The practical consequence.** A rule whose violation you can describe in a shell command belongs in a hook, where it is enforcement rather than persuasion. A cross-cutting authoring rule belongs in the system prompt, where it is re-sent every request. `CLAUDE.md` is where you put the things that are neither — and it is the weakest channel available, by construction.

**Why position cannot be fixed by moving text around.** Prompt caching requires a byte-identical prefix, so project context is pinned at the front of it ([prompt-caching](https://code.claude.com/docs/en/prompt-caching)). A `CLAUDE.md` rule structurally cannot occupy the recency position where a hook fires. Related: editing `CLAUDE.md` mid-session does not invalidate the cache — **and the edit also does not apply** until `/clear`, `/compact`, or a restart.

**Writing hook text.** Frame it as a factual statement, not an imperative system command: "Text framed as out-of-band system commands can trigger Claude's prompt-injection defenses, which causes Claude to surface the text to you instead of treating it as context" ([hooks](https://code.claude.com/docs/en/hooks)).

---

## 3. Diagnosing a violated rule

Work down this list. Most violations are the first two, and neither is fixed by rewriting the rule.

1. **Is the file over the constraint budget?** § 4. Anthropic states the symptom directly: "If Claude keeps doing something you don't want despite having a rule against it, **the file is probably too long and the rule is getting lost**" ([memory](https://code.claude.com/docs/en/memory)).
2. **Is the rule a prohibition?** § 5. Prohibitions decay with context depth; requirements persist.
3. **Is it mechanically decidable?** Then it is in the wrong channel — § 2.
4. **Was it self-checked in the same pass?** That is documented to fail — § 7.
5. **Only then**: is the wording unclear, or is the rationale missing? § 5.

---

## 4. The constraint budget

This is the single most load-bearing number in this document.

A study of 15 models including Claude Opus (369,753 constraint checks) measured joint compliance as constraints accumulate ([arXiv 2608.12426](https://arxiv.org/abs/2608.12426)):

```
mCSR(k) = 72.0% × 0.922^(k-1)

k = 1   72.0%       each constraint passes
k = 8   41%  each   ALL EIGHT together: 5.7%
```

Per-constraint compliance decays gently. **Joint compliance collapses multiplicatively.** The half-life — where joint success drops below 50% — is **k* = 6** for the strongest model tested, and 2–4 for twelve of the fifteen.

> "Reliable instruction following breaks down beyond 5–6 simultaneous constraints."

Anthropic's own guidance points the same way: "target under 200 lines per CLAUDE.md file. Longer files consume more context and reduce adherence," and "Bloated CLAUDE.md files cause Claude to ignore your actual instructions!" ([memory](https://code.claude.com/docs/en/memory), [best-practices](https://code.claude.com/docs/en/best-practices)).

**Count constraints, not lines.** A rule with a carve-out and a falsifier is plausibly three tracked constraints, not one. A file of 89 lines carrying 36 rules, 33 falsifiers and 24 carve-outs is ~93 constraints — an order of magnitude past the measured ceiling, while looking short.

**What degrades fastest.** Constraints requiring *sustained tracking during generation* decay about **2× faster** than one-shot lexical ones; binary decisions are nearly immune. Standing process rules ("verify before asserting", "re-read before editing") are the fastest-degrading class there is.

---

## 5. Wording — what helps, and what backfires

```diff
+ stating the CONSEQUENCE or reason     best-evidenced lever
+ concrete examples (3-5, diverse)      direction solid, magnitude unmeasured
+ requirements ("always do Y")          persist with depth
+ machine-checkable phrasing            22-26% inconsistency -> 0.3-1.8%
- emphasis on many rules                saturates; none stands out
- aggressive framing (CRITICAL/MUST)    documented BACKFIRE on Opus 4.5/4.6
- prohibitions ("never do X")           decay with depth
- repeating the rule mid-context        flat to negative
```

**Consequence beats emphasis.** Anthropic's worked example changes only one thing — it adds a reason — and the emphatic version is the loser ([prompting best practices](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices)):

```
Less effective:  NEVER use ellipses
More effective:  Your response will be read aloud by a text-to-speech engine,
                 so never use ellipses since the text-to-speech engine will
                 not know how to pronounce them.
```

**Emphasis is a scarce resource.** "If Claude keeps skipping one instruction, add emphasis such as 'IMPORTANT' to that line alone. **If you emphasize many lines, none of them stands out**" ([best-practices](https://code.claude.com/docs/en/best-practices)). Bold on every rule is bold on no rule.

**Aggressive framing now backfires.** "Claude Opus 4.5 and Claude Opus 4.6 are also more responsive to the system prompt than previous models… The fix is to dial back any aggressive language. Where you might have said 'CRITICAL: You MUST use this tool when…', you can use more normal prompting like 'Use this tool when…'." The observed failure on current models is over- and mis-triggering, not under-compliance.

**Prohibitions decay; requirements persist.** Measured across 12 models at 6 context depths: a required element appeared in 100% of responses while a prohibition was violated in 63% of those *same* outputs — compliant and non-compliant simultaneously. The author attributes it to "architectural properties of attention mechanisms rather than mere wording effects."

**So: express every rule as the behaviour that must happen.** "Edit with the minimum unique `old_string`" survives where "never rewrite a file a targeted edit would cover" decays — same rule, durable grammar.

---

## 6. The failure modes, named

Knowing which mode you are in decides the fix. These are distinct, and the interventions do not transfer.

```
MODE                        SIGNATURE                          SOURCE
-------------------------   --------------------------------   -----------------
constraint drift            recalls the rule, violates it       arXiv 2604.28031
articulation paradox        states the rule while breaking it   arXiv 2605.21537
compliance gap              agrees verbally, bypasses in act    arXiv 2605.01771
split-brain / knowing-doing correct principle, wrong execution  arXiv 2507.10624
self-correction blind spot  own errors invisible                arXiv 2507.02778
rule misapplication         restates rule, concludes against    arXiv 2606.00476
```

**The mode that matters here is "read it, agreed, violated it".** It is documented and it is *not* forgetting:

- DriftBench measured **97.3% probe accuracy** on constraint recall alongside violation in the same output. The authors state this rules out positional or memory loss — "drift should correlate with recall failure" under an information-loss account, and it does not. The rule is losing an arbitration contest against local task pressure.
- "Doing What They Say, Not What They Reason": in **65%** of erroneous decisions the agent restates the rule correctly and then concludes against it.
- The Compliance Gap: six frontier models given explicit process instructions showed **0% compliance** under default framing; one "verbally agrees ten out of ten times then bypasses in all ten."

**What moved the needle in those studies was the environment, not the text.** Removing the tool that enabled the shortcut raised compliance from 0% to 75% (Cohen's d = 2.47). Rewording did not.

---

## 7. Review — fresh context beats everything

**A model cannot reliably check its own output in the same pass that produced it.**

- Huang et al., ICLR 2024 (DeepMind): LLMs "struggle to self-correct without external feedback, and at times performance degrades."
- Stechly et al.: "significant performance collapse with self-critique" but "significant gains with sound external verification" — the premise that verification is easier than generation does *not* hold for LLMs.
- Tyen et al. localises it: **detection is the bottleneck, not correction.** Given the error's location, correction is robust. Finding it is what fails.

**Author blindness is measured.** Self-Correction Bench (NeurIPS 2025) injects identical errors and varies only attribution:

```
identical error, attributed elsewhere    corrected
identical error, the model's own         64.5% missed

simple arithmetic                        45.2% blind spot
multi-step                               79.2% blind spot
```

Root cause: under 5% of instruction-tuning data contains correction tokens. The capability exists; it does not activate on one's own output.

**Interventions, measured:**

```diff
+ fresh-context review        F1 28.6 vs 24.6 same-session (p=.008, d=.52)
+ external/executable check   +10-20 points; dominates LLM self-check
+ machine-checkable tagging   inconsistency 22-26% -> 0.3-1.8%
+ cross-family verifier       beats self-verification
- reviewing twice, same ctx   21.7% F1 — WORSE than reviewing once
- same-context subagent       23.8% — also loses to fresh context
- asking "are you sure?"      flips correct answers to wrong
```

**The design that follows.** A review step must run with no authorship history: a separate session, or an external checker. A second pass in the same context is measured to be worse than not bothering, and a subagent spawned from the authoring session inherits the same blindness. Anthropic's own guidance describes the working pattern as generate → review → refine where "**each step is a separate API call**."

**A criterion is a review tool, not a generation-time gate.** Writing "check this against the text you are about to write" asks for exactly the same-pass detection the literature reports as failing. The same criterion applied post-hoc, in a fresh context, is where it pays.

---

## 8. What instructions cost

Everything is re-sent on every request — there is no server-side session state ([prompt-caching](https://code.claude.com/docs/en/prompt-caching)). But the unchanged prefix is billed at **0.1× base input**, a 90% discount ([pricing](https://platform.claude.com/docs/en/about-claude/pricing)).

```
OPERATION        MULTIPLIER
--------------   ----------
base input       1x
5m cache write   1.25x
1h cache write   2x
cache read       0.1x
```

So moving a 4,400-token rule file from `CLAUDE.md` into `--append-system-prompt` costs **nothing** — both sit in the cached prefix, both are re-sent, both bill at cache-read rate. Choose the channel for adherence, never for cost.

Cache TTL is **1 hour** on a subscription (5 minutes on credits or API key), and each hit resets it, so an active session pays cache-write once. Invalidated by: model switch, effort change, MCP connect/disconnect, `/compact`. Not invalidated by: file edits, permission mode, output style, skills.

Inspect live with `/context` (component breakdown, confirms what loaded) and `/usage` (cache read/write counts, hit rate).

---

## 9. What this means for a rule file

The design that the evidence supports, in order of leverage:

1. **Budget the constraints.** Target the handful that must be live simultaneously. Everything else moves to a channel that loads on demand.
2. **Route by decidability.** Mechanically checkable → hook. Cross-cutting and always-on → system prompt. Task-scoped → skill. What remains → the rule file.
3. **Write requirements, with reasons.** Not prohibitions, not emphasis.
4. **Put the criteria in the reviewer.** A falsifier is a review tool; file it where the review runs.
5. **Make the review fresh.** A separate session, not a second look.

---

## UPDATING

Add a finding here when it is backed by a primary source — Anthropic documentation or a study with a measurement — and name that source inline. A claim without one does not belong in this file; the whole point is that it replaces the research rather than re-opening it.

When a documented mechanic changes (a new flag, a channel's delivery, a pricing multiplier), correct the section it lives in and keep the citation current. When a measurement is superseded by a larger or better study, replace the number and say which study it came from.

## Sources

Anthropic documentation: [memory](https://code.claude.com/docs/en/memory) · [output-styles](https://code.claude.com/docs/en/output-styles) · [hooks](https://code.claude.com/docs/en/hooks) · [context-window](https://code.claude.com/docs/en/context-window) · [prompt-caching](https://code.claude.com/docs/en/prompt-caching) · [best-practices](https://code.claude.com/docs/en/best-practices) · [cli-reference](https://code.claude.com/docs/en/cli-reference) · [prompting best practices](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices) · [pricing](https://platform.claude.com/docs/en/about-claude/pricing) · [effective context engineering](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents)

Studies: [constraint scaling](https://arxiv.org/abs/2608.12426) · [self-correction blind spot](https://arxiv.org/abs/2507.02778) · [compliance gap](https://arxiv.org/abs/2605.01771) · [constraint drift](https://arxiv.org/pdf/2604.28031) · [articulate but wrong](https://arxiv.org/html/2605.21537) · [cross-context review](https://arxiv.org/pdf/2603.12123) · [say vs reason](https://arxiv.org/html/2606.00476v1) · [split-brain](https://arxiv.org/html/2507.10624v3) · [self-correction limits](https://arxiv.org/abs/2310.01798) · [self-critique collapse](https://arxiv.org/abs/2402.08115) · [error localisation](https://arxiv.org/abs/2311.08516) · [self-correction survey](https://arxiv.org/pdf/2406.01297) · [CoT faithfulness](https://arxiv.org/abs/2505.05410) · [RuLES](https://arxiv.org/html/2311.04235v2) · [lost in the middle](https://arxiv.org/abs/2307.03172)
