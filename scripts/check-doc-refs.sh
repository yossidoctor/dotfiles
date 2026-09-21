#!/bin/bash
# check-doc-refs — do the things a config repo's docs point at exist?
#
# Usage:  check-doc-refs [--strict] [<root>]
#   <root>    a repository holding CLAUDE.md files, claude/**/skills trees, and an
#             install.conf.yaml (default: the repository containing the cwd)
#   default : file-ref, skill-path, references/ and link-source misses FAIL (exit 1);
#             § misses WARN
#   --strict: § misses also FAIL (§ citations are free-form prose, so strict is for
#             eyeballing, not a blocking gate)
#
# Checks, in order:
#   1  a `foo.sh` / `bar.md` cited in a skill exists somewhere in the root, the
#      deployed global skills (~/.claude/skills) or the deployed hooks (~/.claude/hooks)
#   1b a `skills/<dir>/<file>` path cited by live config resolves as a path under
#      some skill tree, so a moved file with a surviving basename still surfaces;
#      hook tests/ are excluded because their fixtures cite absent paths on
#      purpose, and dated session docs (`YYYY-MM-DD-*.md`) because they are
#      snapshots of the tree at their date and a path that moved since is history
#   1c a bare `references/<file>` cite resolves inside the citing skill; a line
#      naming a different skill on the roster is citing outward and is skipped
#   2  every install.conf.yaml `link:` source exists (scalar `~/dest: src`, mapped
#      `path: src`, `glob:` parent dir); `~`-prefixed and absolute sources resolve
#      as written
#   3  a `§ Section` cite prefix-matches a heading or a `- **Bold lead**` in the rule
#      text: the root's CLAUDE.mds, skills, agents, rules and output-styles, plus
#      the deployed ~/.claude/CLAUDE.md, skills, rules and output-styles
#
# The skill trees are every claude/*/skills and claude/skills directory under the
# root plus ~/.claude/skills, deduplicated by physical path, so the global layer's
# own repo counts its skills once. Both inventories are files rather than shell
# variables: a grep re-expanding a multi-thousand-line variable hundreds of times
# truncates its match under load, and the lookups are case statements over a
# newline-delimited list, whole-line anchored, spawning nothing per citation.
#
# A project layer wraps this with its own passes (cross-doc paths, knowledge-base
# anchors); this script knows no project.
#
# Exit: 0 = clean · 1 = a hard reference is broken · 2 = usage.

set -uo pipefail

strict=0
root=""
for arg in "$@"; do
  case "$arg" in
    --strict) strict=1 ;;
    -*) echo "usage: check-doc-refs [--strict] [<root>]" >&2; exit 2 ;;
    *) root="$arg" ;;
  esac
done
[ -n "$root" ] || root=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "check-doc-refs: no root given and cwd is not in a repository" >&2; exit 2; }
ROOT=$(cd "$root" && pwd -P) || exit 2

phys() { [ -e "$1" ] && (cd "$1" 2>/dev/null && pwd -P); }

SKILL_TREES=()
add_tree() { local t; t=$(phys "$1") || return 0; case " ${SKILL_TREES[*]:-} " in *" $t "*) ;; *) SKILL_TREES+=("$t") ;; esac; }
for d in "$ROOT"/claude/skills "$ROOT"/claude/*/skills "$HOME/.claude/skills"; do add_tree "$d"; done

RULE_TEXT=()
add_rule() { local t; t=$(readlink -f "$1" 2>/dev/null) || return 0; [ -e "$t" ] || return 0; case " ${RULE_TEXT[*]:-} " in *" $t "*) ;; *) RULE_TEXT+=("$t") ;; esac; }
while IFS= read -r f; do add_rule "$ROOT/$f"; done < <(git -C "$ROOT" ls-files -- 'CLAUDE.md' '*/CLAUDE.md' 2>/dev/null)
for d in "${SKILL_TREES[@]}" "$ROOT"/claude/agents "$ROOT"/claude/*/agents "$ROOT"/claude/rules "$ROOT"/claude/*/rules "$ROOT"/claude/output-styles "$ROOT"/claude/*/output-styles "$HOME/.claude/rules" "$HOME/.claude/output-styles" "$HOME/.claude/CLAUDE.md"; do add_rule "$d"; done

fail=0
warn=0

TMP=$(mktemp -d "${TMPDIR:-/tmp}/cdr.XXXXXX") || exit 2
trap 'rm -rf "$TMP"' EXIT

{ find "$ROOT" -name .git -prune -o -type f -print 2>/dev/null
  for t in "${SKILL_TREES[@]}"; do find "$t" -type f 2>/dev/null; done
  [ -d "$HOME/.claude/hooks" ] && find "$HOME/.claude/hooks" \( -type f -o -type l \) 2>/dev/null; } \
  | sed 's|.*/||' | sort -u > "$TMP/files"

for t in "${SKILL_TREES[@]}"; do find "$t" -type f 2>/dev/null | sed "s|^$t/|skills/|"; done | sort -u > "$TMP/paths"

{
  grep -rhoE '^#{1,6} .+' "${RULE_TEXT[@]}" 2>/dev/null | sed -E 's/^#+[[:space:]]+//'
  grep -rhoE '^- \*\*[^*]+\*\*' "${RULE_TEXT[@]}" 2>/dev/null | sed -E 's/^- \*\*//; s/\*\*$//; s/[.,][[:space:]]*$//'
} > "$TMP/headings"

FILES_LIST=$'\n'$(cat "$TMP/files")$'\n'
PATHS_LIST=$'\n'$(cat "$TMP/paths")$'\n'
file_exists() { case "$FILES_LIST" in *$'\n'"$1"$'\n'*) return 0 ;; *) return 1 ;; esac; }
path_exists() { case "$PATHS_LIST" in *$'\n'"$1"$'\n'*) return 0 ;; *) return 1 ;; esac; }

echo "== file references (.sh / .md cited in skills) =="
grep -rnoE '`[a-z0-9_-]+\.(sh|md)`' "${SKILL_TREES[@]}" 2>/dev/null \
  | sed -E 's/^(.*):`([a-z0-9_-]+\.(sh|md))`$/\1\t\2/' \
  | while IFS=$'\t' read -r loc ref; do
      case "$ref" in
        script.sh|example.sh|foo.sh|bar.sh|name.sh|"<name>".sh) continue ;;
        notes.md|CONTEXT.md) continue ;;
      esac
      file_exists "$ref" || echo "  BROKEN  $loc  ->  $ref  (no such file in tree)"
    done > "$TMP/rep_files"
if [ -s "$TMP/rep_files" ]; then cat "$TMP/rep_files"; fail=1; else echo "  ok — all file refs resolve"; fi

echo "== skill paths (directory-aware) =="
{ printf '%s\n' "$ROOT"/claude "$ROOT"/scripts "$ROOT"/docs; git -C "$ROOT" ls-files -- 'CLAUDE.md' '*/CLAUDE.md' 2>/dev/null | sed "s|^|$ROOT/|"; } \
  | while IFS= read -r p; do [ -e "$p" ] && printf '%s\n' "$p"; done \
  | xargs grep -rhoE --exclude-dir=tests --exclude='20[0-9][0-9]-[0-9][0-9]-[0-9][0-9]-*.md' 'skills/[a-z0-9_-]+/[A-Za-z0-9_/.-]+\.(sh|md)' 2>/dev/null \
  | sed -E 's|.*(skills/)|\1|' | sort -u \
  | while IFS= read -r p; do
      path_exists "$p" || echo "  BROKEN  $p  (no such path under any skills tree)"
    done > "$TMP/rep_paths"
if [ -s "$TMP/rep_paths" ]; then cat "$TMP/rep_paths"; fail=1; else echo "  ok — all skill paths resolve"; fi

echo "== relative references/ citations =="
for t in "${SKILL_TREES[@]}"; do ls "$t"; done 2>/dev/null | sort -u > "$TMP/skillnames"
grep -rnoE --exclude-dir=tests '[A-Za-z0-9_/-]*references/[A-Za-z0-9_.-]+\.md' "${SKILL_TREES[@]}" 2>/dev/null \
  | while IFS= read -r hit; do
      file=${hit%%:*}
      rest=${hit#*:}; lineno=${rest%%:*}
      ref=${hit##*:}
      case "$ref" in */references/*) continue ;; esac
      after=${file#*/skills/}
      skilldir=${file%/skills/*}/skills/${after%%/*}
      own=${skilldir##*/}
      if awk -v ln="$lineno" -v own="$own" -v roster="$TMP/skillnames" '
           BEGIN { while ((getline s < roster) > 0) if (s != "") known[s] = 1 }
           NR != ln { next }
           {
             n = 0
             line = $0
             while (match(line, /`[a-z0-9-]+`/)) {
               w = substr(line, RSTART + 1, RLENGTH - 2)
               line = substr(line, RSTART + RLENGTH)
               if (w != own && (w in known)) n++
             }
             line = $0
             while (match(line, /[a-z0-9-]+ skill/)) {
               w = substr(line, RSTART, RLENGTH - 6)
               line = substr(line, RSTART + RLENGTH)
               if (w != own && (w in known)) n++
             }
             found = (n > 0)
             exit
           }
           END { exit (found ? 0 : 1) }
         ' "$file" 2>/dev/null; then
        continue
      fi
      [ -f "$skilldir/$ref" ] || echo "  BROKEN  ${file#$ROOT/}:$lineno  ->  $ref"
    done | sort -u > "$TMP/rep_rel"
if [ -s "$TMP/rep_rel" ]; then cat "$TMP/rep_rel"; fail=1; else echo "  ok — all relative references/ citations resolve"; fi

echo "== install.conf.yaml link sources =="
if [ -f "$ROOT/install.conf.yaml" ]; then
  awk '
    /^- link:/            { inlink=1; next }
    /^- (create|shell|defaults):/ { inlink=0; next }
    inlink==0             { next }
    /^[[:space:]]+glob:[[:space:]]*true/ { print "GLOB " last_path; next }
    /^[[:space:]]+path:[[:space:]]*[^[:space:]]/ {
      s=$0; sub(/^[[:space:]]+path:[[:space:]]*/,"",s); gsub(/"/,"",s); last_path=s; print "PATH " s; next
    }
    /^[[:space:]]+[^[:space:]].*:[[:space:]]+[^[:space:]]/ {
      s=$0; sub(/^[[:space:]]+[^:]+:[[:space:]]+/,"",s); gsub(/"/,"",s); print "PATH " s
    }
  ' "$ROOT/install.conf.yaml" \
    | while IFS= read -r kind src; do
        case "$src" in "~/"*) target="$HOME/${src#\~/}" ;; /*) target="$src" ;; *) target="$ROOT/$src" ;; esac
        case "$kind" in
          GLOB)
            [ -d "${target%/*}" ] || echo "  BROKEN  install.conf.yaml  ->  $src  (glob parent dir absent)" ;;
          PATH)
            case "$src" in ""|relink:*|force:*|if:*|glob:*|description:*) continue ;; esac
            [ -e "$target" ] || echo "  BROKEN  install.conf.yaml  ->  $src  (link source absent)" ;;
        esac
      done > "$TMP/rep_links"
  if [ -s "$TMP/rep_links" ]; then cat "$TMP/rep_links"; fail=1; else echo "  ok — all link sources present"; fi
else
  echo "  skip — no install.conf.yaml at $ROOT"
fi

echo "== section (§) citations =="
grep -rhoE --exclude-dir=tests '§ [A-Za-z][^.,;:)`*]*' "${RULE_TEXT[@]}" 2>/dev/null \
  | sed -E 's/^§ //; s/[[:space:]]+$//' | sort -u \
  | awk -v pool="$TMP/headings" '
      BEGIN { while ((getline h < pool) > 0) if (h != "") heads[++hn] = tolower(h) }
      function hit(needle,   i) {
        if (needle == "") return 0
        needle = tolower(needle)
        for (i = 1; i <= hn; i++) if (index(heads[i], needle)) return 1
        return 0
      }
      $0 == "" { next }
      {
        probe = $0; gsub(/`/, "", probe)
        first = $0; sub(/ .*$/, "", first)
        if (!hit(probe) && !hit(first))
          print "  WARN  § " $0 "  (no heading prefix-matches — verify or reword)"
      }
    ' > "$TMP/rep_secs"
if [ -s "$TMP/rep_secs" ]; then
  cat "$TMP/rep_secs"
  warn=$(wc -l < "$TMP/rep_secs" | tr -d ' ')
  [ "$strict" = 1 ] && fail=1
else echo "  ok — all § citations prefix-match a heading"; fi

echo "---"
if [ "$fail" = 1 ]; then
  suffix=""; [ "$strict" = 1 ] && suffix=" / § in strict"
  echo "check-doc-refs: FAIL (broken hard references above$suffix)"
  exit 1
fi
[ "$warn" -gt 0 ] && echo "check-doc-refs: ok ($warn § warnings)" || echo "check-doc-refs: ok"
exit 0
