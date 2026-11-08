# Instructing Claude — Knowledge Base

*Standing reference for how a written instruction reaches Claude and whether it changes behaviour. Every claim here traces to a primary source — Anthropic's own documentation, or a measured study, cited inline. Researched 2026-09-17 across six parallel investigations; every citation re-checked against its source on 2026-11-07. Read this before authoring or rewriting any rule file, skill, hook, or agent definition, and before concluding that a rule was ignored.*

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

Joint compliance with a set of simultaneous constraints collapses multiplicatively as the set grows, even though each individual rule still reads fine; on synthetic format constraints the half-life is **six or seven** rules, and simple inclusion rules hold far longer. Emphasis does not raise that ceiling and, on current models, overtriggers. A `CLAUDE.md` file is delivered as context in the conversation, not in the system prompt, and is documented as advisory, not enforced. A model cannot reliably find errors in its own output in the same pass that produced it (a **64.5%** blind spot in non-reasoning open models; detection, not correction, is what fails), and a reviewer with no authorship history is the documented remedy. Therefore: cut the rule count, state rules as the behaviour that must happen, move anything mechanically decidable into a hook, and put the judgment-bearing check in a separate pass with no authorship history.

---

## 2. The channels, and what each buys

Instructions reach the model through several channels that look interchangeable and are not. Ranked by binding force, strongest first:

```
CHANNEL                   DELIVERY                            BINDING
-----------------------   ---------------------------------   ------------------------
PreToolUse hook (deny)    blocks the call outright            enforcement, not text
Hook additionalContext    system-reminder, at the action      fires at the decision
--append-system-prompt    system prompt, every request        the only text in that layer
Output style              system-reminder, every request      same delivery as CLAUDE.md
CLAUDE.md                 system-reminder, session start      advisory, no guarantee
Skill body                one message, on invocation          stays in context afterwards
```

**The documented facts behind that table:**

> "CLAUDE.md content is delivered as a **user message after the system prompt**, not as part of the system prompt itself. Claude reads it and tries to follow it, but **there's no guarantee of strict compliance**, especially for vague or conflicting instructions." — [memory](https://code.claude.com/docs/en/memory)

> "Claude treats them as context, **not enforced configuration**." … "To **block** an action regardless of what Claude decides, use a PreToolUse hook instead." — same page

> "Your CLAUDE.md files and the instructions of your output style **aren't part of the system prompt**. Claude Code delivers them in the conversation as system reminders." — [glossary](https://code.claude.com/docs/en/glossary). The output-styles page says only that the style's instructions are sent "with every request"; the earlier sentence about a mid-conversation reminder was removed from the docs in October 2026.

> "Claude Code **wraps the string in a system reminder** and inserts it into the conversation **at the point where the hook fired**." — [hooks](https://code.claude.com/docs/en/hooks)

**The practical consequence.** A rule whose violation you can describe in a shell command belongs in a hook, where it is enforcement rather than persuasion. The documented split is between what is enforced (a hook, a deny rule, a managed setting) and what is text; among the text channels, CLAUDE.md and the output style arrive the same way, and `--append-system-prompt` alone sits in the system prompt. No documented basis ranks one text channel above another for adherence.

**Why position cannot be fixed by moving text around.** Prompt caching matches on the request prefix, so project context is pinned at the front of it ([prompt-caching](https://code.claude.com/docs/en/prompt-caching)). A `CLAUDE.md` rule structurally cannot occupy the recency position where a hook fires. Related: editing `CLAUDE.md` mid-session does not invalidate the cache — **and the edit also does not apply** until `/clear`, `/compact`, or a restart.

**Writing hook text.** Frame it as a factual statement, not an imperative system command: "Text framed as out-of-band system commands can trigger Claude's prompt-injection defenses, which causes Claude to surface the text to you instead of treating it as context" ([hooks](https://code.claude.com/docs/en/hooks)).

---

## 3. Diagnosing a violated rule

Work down this list. Most violations are the first two, and neither is fixed by rewriting the rule.

1. **Is the file over the constraint budget?** § 4. Anthropic states the symptom directly: a line Claude keeps missing means "the file has grown long enough that the line gets lost", and "adding IMPORTANT probably won't fix it" ([best-practices](https://code.claude.com/docs/en/best-practices)).
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

Per-constraint compliance decays gently. **Joint compliance collapses multiplicatively.** The half-life — where joint success drops below 50% — is **k* = 7** for the strongest model tested (GPT-5.5), 6 for Claude 4.7 Opus, 3 for Claude 4.6 Opus, and ≤3 for twelve of the fifteen.

> "Reliable instruction following breaks down beyond 5–6 simultaneous constraints."

The constraints measured are synthetic lexical and format checks (word counts, forbidden words, JSON shape), so the number is a property of that task family, not of prose rules in general: on simple keyword-inclusion rules Claude Opus 4 held 100% at 50 rules and 94.6% at 100 ([IFScale](https://arxiv.org/abs/2507.11538)), while [ManyIFEval](https://arxiv.org/abs/2509.21051) found that instruction count alone predicts performance to within about 10%. The direction — fewer simultaneous rules — holds across every study; the exact ceiling depends on the rule type.

Anthropic's own guidance points the same way: "target under 200 lines per CLAUDE.md file. Longer files consume more context and reduce adherence" ([memory](https://code.claude.com/docs/en/memory)), and "every line in it takes a little of Claude's attention on every task, whether it's relevant or not" ([best-practices](https://code.claude.com/docs/en/best-practices)).

**Count constraints, not lines.** A rule with a carve-out and a falsifier is plausibly three tracked constraints, not one. A file of 89 lines carrying 36 rules, 33 falsifiers and 24 carve-outs is ~93 constraints — an order of magnitude past the measured ceiling, while looking short.

**What degrades fastest.** Structural constraints lose **2.0×** more capability per added constraint than lexical ones (95% CI 1.9–2.3), and the predictor of a constraint's decay rate is whether it needs *sustained tracking during generation*; binary decisions are nearly immune. A forbidden-word constraint was among the most robust types (89% retention at k ≥ 8). Standing process rules ("verify before asserting", "re-read before editing") are the fastest-degrading class there is.

---

## 5. Wording — what helps, and what backfires

```diff
+ stating the CONSEQUENCE or reason     best-evidenced lever
+ concrete examples (3-5, diverse)      direction solid, magnitude unmeasured
+ requirements ("always do Y")          Anthropic: "tell Claude what to do instead of what not to do"
+ re-injecting a rule before it decays  restores compliance (arXiv 2604.20911)
- emphasis on many rules                over-applies the rule; none stands out
- aggressive framing (CRITICAL/MUST)    documented BACKFIRE on Opus 4.5/4.6
- prohibitions ("never do X")           decay with depth on some models, not all
```

**Consequence beats emphasis.** Anthropic's worked example changes two things — it drops the capitals and adds a reason — and the emphatic version is the loser ([prompting best practices](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices) § Add context to improve performance):

```
Less effective:  NEVER use ellipses
More effective:  Your response will be read aloud by a text-to-speech engine,
                 so never use ellipses since the text-to-speech engine will
                 not know how to pronounce them.
```

**Emphasis is a scarce resource, and now a liability.** "Older models sometimes needed the emphasis. Current ones follow a plainly worded line, and **piling on emphasis mostly makes Claude over-apply the rule**" ([best-practices](https://code.claude.com/docs/en/best-practices)). Bold on every rule is bold on no rule.

**Aggressive framing now backfires.** "Claude Opus 4.5 and Claude Opus 4.6 are also more responsive to the system prompt than previous models… The fix is to soften any aggressive language. Where you might have said 'CRITICAL: You MUST use this tool when…,' you can use more normal prompting such as 'Use this tool when…'." The observed failure on current models is over- and mis-triggering, not under-compliance.

**Prohibitions decay on some models; requirements persist.** [arXiv 2604.20911](https://arxiv.org/abs/2604.20911) measured 12 models at 6 context depths: the asymmetry (an omission constraint violated while a commission constraint in the same output holds) was significant in 3 of the 4 models with per-constraint data and absent in one; the headline case — a required element in 100% of responses, the prohibition violated in 63% of the same outputs — is one model (Mistral Large 3) at one depth. Claude Sonnet 4's violation rates were 14–40% with little gap between arms. The same paper found that re-injecting the constraint before its decay depth restores compliance. Anthropic's own guidance is the durable form: "Tell Claude what to do instead of what not to do" ([prompting best practices](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices)).

**So: express every rule as the behaviour that must happen.** "Edit with the minimum unique `old_string`" is the same rule as "never rewrite a file a targeted edit would cover", in the grammar the guidance prefers.

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

- DriftBench measured **97.3% probe accuracy** on constraint recall alongside violation in the same output. The authors state this rules out positional or memory loss — "drift should correlate with recall failure" under an information-loss account, and it does not. They make no mechanistic claim; "the rule loses to local task pressure" is this document's reading.
- "Doing What They Say, Not What They Reason": in its first version, **65%** of erroneous decisions restated the rule correctly and then concluded against it; the revised paper splits the errors roughly evenly between bad inputs, borderline cases and rule misapplication (about a third for Haiku, 8% for DeepSeek), and finds that telling the agent to apply the rule mechanically halves the misapplication rate.
- The Compliance Gap: six frontier models given explicit process instructions showed **0% compliance** under default framing; one "verbally agrees ten out of ten times then bypasses in all ten."

**What moved the needle most was the environment.** Removing the tool that enabled the shortcut raised compliance from 0% to 75% (Cohen's d = 2.47). Wording moved it too, in the same study: an override framing ("do NOT batch read") and an urgency framing each took Claude Sonnet 4 to 100%, an authority framing to 31%; only a neutral-vs-efficiency description ablation showed no effect. The ranking is: remove the shortcut first, then word the rule as a direct instruction with its reason.

---

## 7. Review — fresh context beats everything

**A model cannot reliably check its own output in the same pass that produced it.**

- Huang et al., ICLR 2024 (DeepMind): LLMs "struggle to self-correct their responses without external feedback, and at times, their performance even degrades after self-correction."
- Stechly et al.: "significant performance collapse with self-critique" but "significant performance gains with sound external verification" — the premise that verification is easier than generation does *not* hold for LLMs.
- Tyen et al. localises it: **detection is the bottleneck, not correction.** Given the error's location, correction is robust. Finding it is what fails.

**Author blindness is measured.** Self-Correction Bench ([arXiv 2507.02778](https://arxiv.org/abs/2507.02778), COLM 2026) injects identical errors and varies only attribution:

```
identical error, attributed elsewhere    corrected
identical error, the model's own         64.5% missed  (14 open non-reasoning models)
reasoning models                         small or negative blind spot
```

Root cause: supervised fine-tuning data contains near-zero correction sequences (5–10% in the first version's count). The capability exists; it does not activate on one's own output. Related: LLM evaluators recognise and favour their own outputs ([arXiv 2404.13076](https://arxiv.org/abs/2404.13076)).

**Interventions, measured:**

```diff
+ fresh-context review        F1 28.6% vs 21.7% for a second same-session review (p=.004)
+ external/executable check   self-correction works where reliable external feedback exists
+ a different reviewer        Anthropic: "a fresh reviewer does help, because it hasn't seen your reasoning"
- reviewing twice, same ctx   21.7% F1 — the fresh reviewer beats it robustly
- asking "are you sure?"      flips answers 46% of the time, accuracy down 17% (arXiv 2311.08596)
```

The cross-context review paper's revised version finds the fresh reviewer's edge over a *single* same-session review (27.1%) and over a subagent handed the generation prompt (23.8%) not significant; what holds is that a second look in the same context is the worst option.

**The design that follows.** A review step must run with no authorship history: a separate session, a subagent that starts without the conversation (a Claude Code subagent "doesn't see your conversation history"; only a fork inherits it — [sub-agents](https://code.claude.com/docs/en/sub-agents)), or an external checker. Anthropic's own guidance: "A second session is also the easiest independent reviewer you can get" ([best-practices](https://code.claude.com/docs/en/best-practices)), and the platform pattern is generate → review → refine where "**each step is a separate API call**."

**A criterion is a review tool, not a generation-time gate.** Writing "check this against the text you are about to write" asks for exactly the same-pass detection the literature reports as failing. The same criterion applied post-hoc, in a fresh context, is where it pays.

---

## 8. What instructions cost

Everything is re-sent on every request — there is no server-side session state ([prompt-caching](https://code.claude.com/docs/en/prompt-caching)). But the unchanged prefix is billed at a fraction of base input ([pricing](https://platform.claude.com/docs/en/about-claude/pricing)).

```
OPERATION        MULTIPLIER
--------------   -------------------------------------------------
base input       1x
5m cache write   1.25x
1h cache write   2x
cache read       0.1x (0.05x on Opus/Sonnet 5.5, 0.025x on Fable/Mythos 5.1)
```

So moving a 4,400-token rule file from `CLAUDE.md` into `--append-system-prompt` costs **nothing** — both sit in the cached prefix, both are re-sent, both bill at cache-read rate. Choose the channel for what it enforces, never for cost.

Cache TTL is **1 hour** for the main conversation on a subscription (5 minutes on credits, an API key, or a cloud provider; subagents and compaction get 5 minutes either way), and each hit resets it, so an active session pays cache-write once. Invalidated by: model switch, `/compact`, an effort change (kept on the 5.5 models and Fable 5.1 under an API key or a subscription), an MCP connect/disconnect when tool search is off. Not invalidated by: file edits (a `CLAUDE.md` edit keeps the cache and also does not apply), permission mode, output style, skills.

Inspect live with `/context` (component breakdown, confirms what loaded) and `/usage` (cache read/write counts, hit rate).

---

## 9. What this means for a rule file

The design that the evidence supports, in order of leverage:

1. **Budget the constraints.** Target the handful that must be live simultaneously. Everything else moves to a channel that loads on demand.
2. **Route by decidability.** Mechanically checkable → hook or deny rule ("if you have hooks for things that are only preferences, delete them and let Claude decide" — [best-practices](https://code.claude.com/docs/en/best-practices)). Task-scoped → skill. What remains → the rule file, once.
3. **Write requirements, with reasons.** Not prohibitions, not emphasis.
4. **Put the criteria in the reviewer.** A falsifier is a review tool; file it where the review runs.
5. **Make the review fresh.** A separate session, not a second look.

---

## UPDATING

Add a finding here when it is backed by a primary source — Anthropic documentation or a study with a measurement — and name that source inline. A claim without one does not belong in this file; the whole point is that it replaces the research rather than re-opening it.

When a documented mechanic changes (a new flag, a channel's delivery, a pricing multiplier), correct the section it lives in and keep the citation current. When a measurement is superseded by a larger or better study, replace the number and say which study it came from.

## Sources

Anthropic documentation: [memory](https://code.claude.com/docs/en/memory) · [glossary](https://code.claude.com/docs/en/glossary) · [output-styles](https://code.claude.com/docs/en/output-styles) · [hooks](https://code.claude.com/docs/en/hooks) · [sub-agents](https://code.claude.com/docs/en/sub-agents) · [context-window](https://code.claude.com/docs/en/context-window) · [prompt-caching](https://code.claude.com/docs/en/prompt-caching) · [best-practices](https://code.claude.com/docs/en/best-practices) · [cli-reference](https://code.claude.com/docs/en/cli-reference) · [prompting best practices](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices) · [pricing](https://platform.claude.com/docs/en/about-claude/pricing) · [effective context engineering](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents)

Studies: [constraint scaling](https://arxiv.org/abs/2608.12426) · [IFScale](https://arxiv.org/abs/2507.11538) · [ManyIFEval](https://arxiv.org/abs/2509.21051) · [omission vs commission decay](https://arxiv.org/abs/2604.20911) · [self-correction blind spot](https://arxiv.org/abs/2507.02778) · [self-preference](https://arxiv.org/abs/2404.13076) · [compliance gap](https://arxiv.org/abs/2605.01771) · [constraint drift](https://arxiv.org/abs/2604.28031) · [articulate but wrong](https://arxiv.org/abs/2605.21537) · [cross-context review](https://arxiv.org/abs/2603.12123) · [say vs reason](https://arxiv.org/abs/2606.00476) · [split-brain](https://arxiv.org/abs/2507.10624) · [self-correction limits](https://arxiv.org/abs/2310.01798) · [self-critique collapse](https://arxiv.org/abs/2402.08115) · [error localisation](https://arxiv.org/abs/2311.08516) · [sycophancy flips](https://arxiv.org/abs/2311.08596) · [self-correction survey](https://arxiv.org/abs/2406.01297) · [CoT faithfulness](https://arxiv.org/abs/2505.05410) · [RuLES](https://arxiv.org/abs/2311.04235) · [lost in the middle](https://arxiv.org/abs/2307.03172)
