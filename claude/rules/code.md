---
paths:
  - "**/*.{py,ts,tsx,js,jsx,mjs,cjs,sh,bash,zsh,swift,go,rs,java,kt,rb,sql}"
  - "**/install"
  - "**/hooks/pre-commit"
  - "**/README.md"
---

# Code

Loads when a source file or a config repo's README is touched.

- **Delete dead weight, don't reorganize it.** Remove pass-throughs, identity transforms, guards on cases upstream already excludes, single-use helpers with no logic, seams no branch calls, and a private one-line function whose body is one expression over its arguments (`_value(s)` for `s.value`) — inline it, or fold it onto the model it reads; don't wrap or rename them. Skip: genuine mappers and substantial single-use helpers; real work at the wrong level moves upstream (global CLAUDE.md § A fix lands where the defect is). Falsifier: such a layer kept, wrapped, or renamed.
- **A guard on a fallible producer reports the bad value and leaves it.** Folding or capping it in place hides a contract violation and leaves the producer unfixed, so the next caller meets the same bug with the evidence gone. Skip: parsers and normalizers, whose job is the correction; an unparseable value, which fails at parse time. Falsifier: a value silently rewritten on a path whose contract forbade it.
- **It reads top-to-bottom as one flow.** A linear main path; extract only named substance. Skip: substantial logic stays extracted, never inlined into one giant function. Falsifier: the main path needs hops through trivial forwarding helpers.
- **Names carry domain meaning, not lineage.** Name what a thing is, not its position or origin; rename inherited names that lie, and only those. A read is verb-first with its return shape in the name (`get_last_dispatch_by_site`), never a bare noun or a filter word, and a name that reads like a lookup does not mint. Falsifier: `parent`, `copyOf`, `from_v1` where a domain term exists; a name asserting behavior the code no longer has; a reader named as the thing it returns.
- **No comments, no docstrings.** Code carries its meaning in names and structure, and the why goes in the commit. Prose inside code drifts from the code beside it with nothing to catch the divergence, so a comment a clearer name could carry is replaced by that name, and a diff into a comment-dense file leaves it thinner than it found it. The bar is self-evident code, never confusing code. Skip: machine-required text; a config repo's script headers. Falsifier: a diff keeping a comment a name or structure could carry, or leaving more comments than it found.
- **A script's header and its README each say the thing the other cannot.** The split is `~/dotfiles/README.md` § Script conventions; what it does not say is that the header is maintained rather than thinned, and that a mechanic told in both has no owner. Falsifier: a header line answerable by reading the code beside it; a README sentence restating a header, or restating a rule that already binds globally; a header asserting behavior the script no longer has.
