---
name: mechanism-diagrams
description: Draw a multi-hop mechanism — a data flow, call chain, lifecycle, or failure path — as a fenced terminal diagram with a node table. Use before explaining how something works across more than one place.
---

# mechanism-diagrams

The reader sees the **shape** first; detail hangs on it.

## Form

Pick by the **arrow of time**.

- **Sequence** — the mechanism has order, returns, or retries (a call chain, a failure path with a reply). Lifelines as columns, solid arrow out, dashed arrow back, the payload as the arrow's label. A one-way chain here hides the round trips.
- **Static map** — the relations hold regardless of order (who publishes to which topic, what stores what). Boxes and labelled arrows.
- **Branch** — one node forks on a condition. The condition sits in the gutter beside its edge.
- **Matrix** — the same hops under two variants (current vs target, env A vs env B). One table, hops as rows, variants as columns, cells under 12 characters.

## Grammar

- **Title**: the one question the diagram answers, as its first line.
- **Nodes** are places: service, handler, schema, stream topic. A queue is its topics, never one broker box swallowing the edges.
- **Edges** carry what changes across them (`address → geocoded_address`, `issues=[]`). A bare verb (`uses`, `calls`) is an unlabelled edge. Adjacent edges repeating one label share it once; a repeated run is elided `--/--`.
- **Legend** beneath the figure for any line style beyond a plain arrow: `───` vs `- - -`, `═══`, `||` active lifeline, glyph markers.
- **Node table** beside the figure: node · kind · `file:line` · value at that hop. Paths live here, never in a box.
- **Prose** after both: the verdict, the anomaly, the ask, the why. The diagram indexes it; numbered steps refer to numbered nodes.

## Budget

- Every line within **80 columns** including fence indent; the whole figure within **one screen**. A diagram cannot wrap: over-wide is redrawn or split.
- Split by **concern**, one question per figure at one level of abstraction — the skeleton, the fork, the matrix — not by node count. An irreducibly wide fan-out is drawn wide.
- Plain ASCII (`+ - | > ^ v`) when the text may reach a commit, diff, or comment; Unicode box-drawing (`─│┌┐└┘├┤┬┴┼ ▶`) for a known terminal.

Done when: every node is a table row with a `file:line`; every edge carries a label or shares one; the figure fits one screen at 80 columns; the prose adds nothing a box or row could hold.

## Shapes

Static map, title first, values on the edges:

```
Which stream does a fatal batch ride?
  route ──not_supported──▶ response stream ──▶ next collector / on_candidates_batch
        ──other fatal────▶ error stream ─────▶ on_failed_collect_candidates
```

Branch, condition in the gutter:

```
        +------------------+
        |  request record  |
        +------------------+
           ^            ^
           | cache hit  | miss, refill
           v            v
     +----------+   +-------------+
     | fast set |   | collector   |
     +----------+   +-------------+
```

Sequence, solid out, dashed back:

```
  investigator      forensics        analyzer
       |  search/start  |                |
       |--------------->|  analyze/start |
       |                |--------------->|
       |                |<- - record - - |
       |<- - summary - -|                |
```

Node table:

| # | node | kind | file:line | value |
|---|---|---|---|---|
| 1 | validate | function | `response_validator_new.py:38` | `153 FATAL, message=None` |

Matrix:

| hop | current | target |
|---|---|---|
| intake | sync HTTP | Hatchet dispatch |
