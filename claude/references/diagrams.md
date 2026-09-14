# Diagram grammar

Cited by `~/.claude/CLAUDE.md` § Draw it before you say it. Read when a reply, report, review comment, or doc describes how parts relate.

## Form, by the arrow of time

| the content has | draw |
|---|---|
| order and returns that matter (a request, a lifecycle, a call chain) | a sequence diagram: one lifeline per participant, solid arrow out, dashed arrow back |
| relations that hold regardless of order (ownership, dependency, deployment) | a box-and-arrow map |
| a branch | a fork with the condition in the gutter beside each arm |
| a current-vs-target or option-vs-option comparison | a hops × variants table: one row per hop, one column per variant, the cell holding what differs |

## Grammar

- The figure is titled with the one question it answers.
- An edge says what changes across it (`PENDING → FAILED`, `address → geocoded_address`), never a bare verb.
- A legend exists for any line style beyond a plain arrow.
- `file:line` and per-hop values sit in a table beside the figure, not inside boxes.
- A mechanism with returns is drawn with its returns, not as a one-way chain.

## Budget

- 80 columns and one screen; past that, split by concern into several figures.
- Plain ASCII where the text may reach a commit message or a diff.
