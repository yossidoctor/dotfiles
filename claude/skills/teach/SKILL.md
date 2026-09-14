---
name: teach
description: Build and run a leveled lesson course on a codebase, feature, or domain the user wants to deeply understand — fires on "teach me X", "I don't understand this project / domain / code", "walk me through it step by step", "help me learn this". Turns dense docs, tickets, ADRs, and code into interactive lessons with a Feynman loop. NOT for a one-off question a single reply answers.
---

# teach

A **course** cures the gap that reading cannot: the user owns dense material (docs, tickets, code) but lacks the layer underneath it — usually the domain. Reference documents describe; a **lesson** teaches: one chunk, plain words, a check that it stuck.

## 1 · Diagnose the gap

Find the lowest missing rung, not the one the user names. A user lost in "scenario 3's code" is usually missing the domain two levels down. Ask one question if unclear. Completion: you can name the foundation level the course must start at.

## 2 · Gather sources

Read the real tickets, ADRs, design docs, and review records the lessons will stand on — before lesson one. Every claim in a lesson traces to a source you read this session. Completion: sources read, contradictions between them noted.

## 3 · Pick the anchor

Choose ONE running example — a real entity from the user's own data (one order, one request, one document family) rich enough to exhibit most of the shapes the course covers. Every new concept lands on the anchor. Introduce it in lesson one with a name and a story ("Ricky buys a condo…"). Completion: one anchor named, checked against real data, reused in every lesson.

## 4 · Build the curriculum

A ladder of levels: domain → data model → design ideas → per-feature concepts → code walks. Concepts always before code; code walks are their own levels, and they read the live tree at walk time, never remembered state. Create one task per level (TaskCreate), chained in order. Ask the user where to start and how deep on code before locking it. Completion: tasks created, start point confirmed by the user.

## 5 · Run the lesson loop (per level)

Mark the level's task in_progress. Then:

**Teach.** One lesson, ~15–20 minutes of reading:

- Open by restating position: "Lesson N of M", what is already done.
- Plain words first; introduce jargon with its plain meaning beside it ("instrument — fancy word, plain meaning: one recorded paper").
- Every rule ships with its WHY — the incident behind it, the error asymmetry, the trade-off.
- Coin a **slogan** for each load-bearing rule ("a misread is not a mismatch").
- Lists cap at 5 items; contrasts go in tables; anchor examples carry the abstractions.

**Check (Feynman).** End every lesson with 2–4 questions the user answers in their own words. Aim the questions at the load-bearing distinctions, not trivia.

**Grade.** Per answer: correct / half / wrong, stated plainly with the reason — calibrated, never inflated. Affirm exactly what held. When your own question hid an untaught boundary, own it and teach the boundary instead of grading the user down.

**Drill the gaps.** Re-teach only what missed, small: construct a toy example (a 3-row mini-order beats prose) and run a micro-retry on just the gap. THE critical rule of the course earns extra drilling — walk its logic step by step until the user derives the verdict, not recalls it.

**Advance gate.** The level closes only when the core sticks. Completion: user's final restatement of the level's core is correct in their own words.

Mark the task completed, the next in_progress, and open the next lesson with the updated position.

## 6 · Welcome derailments

A mid-course challenge ("is that claim actually true?") or side question is first-class work: verify it against the sources or live code, fold the correction into the course, then restate where the lessons stand and resume.

## 7 · Close the course

When the last level completes: one summary of what the user can now do, the slogans coined, and where the durable knowledge lives (which docs to reach for later). Offer — never assume — an update to the project's knowledge base with anything the course surfaced or corrected.
