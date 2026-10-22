---
paths:
  - "**/*.{py,ts,tsx,js,jsx,mjs,cjs,sh,bash,zsh,swift,go,rs,java,kt,rb,sql}"
  - "**/install"
  - "**/*files/README.md"  # the two config repos' READMEs; the base names no layer, so this rides the *files naming
---

# Code

- Delete dead weight. A layer that adds nothing is inlined, or folded onto the model it reads, because every forwarding layer is a hop a reader takes and a place a fix lands wrongly. Examples: a pass-through, an identity transform, a single-use helper with no logic, a seam no branch calls, a private one-line function whose body is one expression over its arguments (`_value(s)` for `s.value`). Skip: genuine mappers and substantial single-use helpers; real work at the wrong level moves upstream (global CLAUDE.md § A fix lands where the defect is).
- A guard on a fallible producer reports the bad value and leaves it. A guard exists where the type or the producer's schema admits the bad value; a value the contract already excludes is read unguarded, since the contract is the guard, and a value the type admits (a blank `str`, an empty list) is handled as behaviour. Folding or capping a bad value in place hides a contract violation and leaves the producer unfixed, so the next caller meets the same bug with the evidence gone. Skip: parsers and normalizers, whose job is the correction; an unparseable value, which fails at parse time.
- It reads top-to-bottom as one flow. A linear main path that extracts only named substance, and substantial logic stays in a named function, because each trivial forwarding helper is a hop off the main path.
- Names carry domain meaning, not lineage. Name what a thing is, not its position or origin (`parent`, `copyOf`, `from_v1` name lineage); rename inherited names that lie, and only those. A read is verb-first with its return shape in the name (`get_last_dispatch_by_site`), and a read-shaped name creates nothing, because callers assume a read is idempotent and call it twice.
- **Code carries its meaning in names and structure; the why goes in the commit message.** Prose inside code drifts from the code beside it with nothing to catch the divergence, so a comment or docstring on a line this change edits is replaced by the name or structure that carries it. The bar is self-evident code, never confusing code. Skip: machine-required text; a config repo's script headers; a `shortcut:` marker the ponytail plugin requires.
- A script's header and its README each say the thing the other cannot. The split is `~/dotfiles/README.md` § Script conventions; what it does not say is that the header is maintained rather than thinned, and that a mechanic told in both has no owner.

A diff is reviewed against these rules by `pr-panel` and `/code-review`, in a context that did not write it.
