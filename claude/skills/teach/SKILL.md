---
name: teach
description: Lesson course — teach a codebase, feature, or domain as leveled lessons, each closed by a Feynman check. Fires when the user wants to learn something ("teach me X") or says they don't understand it ("I don't understand this code"). For understanding that needs several lessons; a question one reply covers is answered directly.
---

# teach

A course cures the gap that reading cannot: the user owns dense material (docs, tickets, code) but lacks the layer underneath it, usually the domain. Reference documents describe; a *lesson* teaches one chunk in plain words and checks that it stuck.

A *load-bearing* rule is one whose misreading breaks what the user does next. Questions, slogans and drills aim at load-bearing rules, since a check on trivia passes a user who has missed the point.

## 1 · Diagnose the gap

Find the lowest missing rung, not the one the user names: a user lost in "scenario 3's code" is usually missing the domain two levels down. Ask one question if unclear. Done when you can name the level the course must start at.

## 2 · Gather sources

Read the real tickets, ADRs, design docs and review records the lessons will stand on, before lesson one; a lesson states only what these sources say. Done when every ticket, ADR and doc the curriculum's levels will cite is read to its last line, and each contradiction between them is listed with both sources.

## 3 · Pick the anchor

Choose one running example, a real entity from the user's own data (one order, one request, one document family) rich enough to show most of the shapes the course covers. Every new concept lands on the anchor, because a concept met on a familiar case is remembered where an abstract one is not. Introduce it in lesson one with a name and a story ("Dana's checkout request…", "one deed recorded for one house"). Done when one anchor is named and checked against real data.

## 4 · Build the curriculum

A ladder of levels: domain → data model → design ideas → per-feature concepts → code walks. Concepts come before code, since code read before its concept is read as syntax; code walks are their own levels. Name each level's load-bearing rules, and pick the course's top load-bearing rule: the one whose misreading would cost the user most. Create one task per level (TaskCreate), chained in order, each naming its level's load-bearing rules, so the position stays visible across compaction. Ask the user where to start and how deep on code before locking it. Done when the tasks exist, the top rule is named in its level's task, and the user has confirmed the start point.

## 5 · Run the lesson loop (per level)

Mark the level's task in_progress, then teach, grade, drill and advance.

### Teach

One lesson, ~15–20 minutes of reading, written into these slots in order:

1. Position — "Lesson N of M", and what is already done.
2. Concept on the anchor — the idea shown on the anchor, plain words first, each term glossed beside its first use ("idempotent — plain meaning: running it twice does what running it once does").
3. Why — for each load-bearing rule, the reason it exists: the incident behind it, the error asymmetry, the trade-off.
4. Slogan — a short phrase per load-bearing rule ("a misread is not a mismatch", "a cache is a copy, not a source").
5. Check — the Feynman check: 2–4 questions the user answers in their own words, each aimed at a load-bearing rule.

Inside the slots, a list stops at 5 items and a contrast goes in a table, because a longer list is skimmed and a contrast in prose hides which side differs.

### Grade

Per answer: correct / half / wrong, stated plainly with the reason, and calibrated: half credit names the missing half. Affirm exactly what held. When your own question hid an untaught boundary, own it and teach the boundary instead of grading the user down.

### Drill the gaps

Re-teach only what missed, small: build a toy example (a 3-row table beats prose) and run a micro-retry on just the gap. The course's top load-bearing rule (step 4) earns extra drilling: walk its logic step by step until the user derives the verdict rather than recalls it.

### Advance

**The level closes only when the user's final restatement of its load-bearing rules is correct in their own words.** Mark the task completed, the next in_progress, and open the next lesson with the updated position. Done when every level's task is completed.

## 6 · Welcome derailments

A mid-course challenge ("is that claim actually true?") or side question is first-class work: verify it against the sources or live code, then resume. Done when the correction is folded into the lesson it affects and the user is told where the lessons stand.

## 7 · Close the course

When the last level completes: one summary of what the user can now do, the slogans coined, and where the durable knowledge lives (which docs to reach for later). Ask before updating the project's knowledge base with anything the course surfaced or corrected: it is shared, tracked text the user owns. Done when the summary is delivered and the user has answered the knowledge-base question.
