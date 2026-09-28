#!/bin/bash
# rule-audit-lib.sh — what rule-audit.sh and rule-audit-gate.sh share: which
# staged files are rule files, and the receipt key over their exact content.
# Sourced by both through their physical path (the deployed name is a symlink).
#
#   rule_audit_staged <root>            the staged rule files, one path per line:
#                                       CLAUDE.md, AGENTS.md, and every .md/.sh
#                                       under a skills/, agents/, rules/ or
#                                       output-styles/ dir. A skill's own scripts
#                                       count: a skill and the script it names
#                                       are one instruction.
#   rule_audit_key <root> <staged>      the receipt key: each file's blob hash in
#                                       path order, hashed together, so an edit
#                                       after auditing re-arms the gate.

rule_audit_staged() {
  git -C "$1" diff --cached --name-only --diff-filter=ACMR \
    | grep -E '(^|/)(CLAUDE\.md$|AGENTS\.md$)|(^|/)(skills|agents|rules|output-styles)/.*\.(md|sh)$' \
    || true
}

rule_audit_key() {
  printf '%s\n' "$2" | while IFS= read -r f; do
    [ -n "$f" ] || continue
    printf '%s %s\n' "$f" "$(git -C "$1" rev-parse ":$f" 2>/dev/null || echo missing)"
  done | shasum -a 256 | cut -d' ' -f1
}
