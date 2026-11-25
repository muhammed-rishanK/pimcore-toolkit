#!/usr/bin/env bash
# Lists what /pimcore-review should look at. Read-only.
# Usage: review-scope.sh [<project-root>] [--all | --staged | --base <ref>]
#   (default)     uncommitted changes: staged, unstaged and untracked code files
#   --staged      only staged changes
#   --base <ref>  everything that changed since <ref> (a branch, tag or commit), plus uncommitted work
#   --all         every first-party code file (vendor, var, node_modules, public/bundles and
#                 generated DataObject classes are skipped), grouped by top folder
# Output: one JSON object: mode, root, files [{path, status, added, removed}], groups (for --all), totals.
set -u
ROOT="."; MODE="changes"; BASE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --all) MODE="all"; shift ;;
    --staged) MODE="staged"; shift ;;
    --base) MODE="base"; BASE="${2:-}"; shift 2 ;;
    -h|--help) sed -n '2,10p' "$0"; exit 0 ;;
    -*) echo "unknown option: $1" >&2; exit 2 ;;
    *) ROOT="$1"; shift ;;
  esac
done
cd "$ROOT" 2>/dev/null || { echo "project folder not found: $ROOT" >&2; exit 2; }
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { printf '{"mode":"%s","error":"not a git repository"}\n' "$MODE"; exit 1; }
ROOT="$(git rev-parse --show-toplevel)"; cd "$ROOT"
[ "$MODE" = base ] && { git rev-parse --verify -q "$BASE^{commit}" >/dev/null || { echo "unknown ref: $BASE" >&2; exit 2; }; }

CODE='\.(php|twig|ya?ml|xml|js|jsx|ts|tsx|json|neon|sql|sh|ini|conf)$|(^|/)(Dockerfile[^/]*|\.env[^/]*)$'
SKIP='^(vendor|var/cache|var/log|var/tmp|var/classes/DataObject|node_modules|public/bundles|public/var|\.claude|\.git)/|(^|/)composer\.lock$|(^|/)package-lock\.json$|(^|/)yarn\.lock$'
keep() { grep -E "$CODE" | grep -v -E "$SKIP"; }
jesc() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'; }

LIST=""
case "$MODE" in
  changes)
    LIST="$( { git diff --numstat HEAD 2>/dev/null || git diff --numstat; } | awk -F'\t' '{print "M\t"$1"\t"$2"\t"$3}')"
    UN="$(git ls-files --others --exclude-standard | keep)"
    while IFS= read -r f; do [ -n "$f" ] && LIST="$LIST"$'\n'"A	$(wc -l <"$f" 2>/dev/null | tr -d ' ')	0	$f"; done <<<"$UN" ;;
  staged) LIST="$(git diff --cached --numstat | awk -F'\t' '{print "M\t"$1"\t"$2"\t"$3}')" ;;
  base)
    MB="$(git merge-base "$BASE" HEAD)"
    LIST="$(git diff --numstat "$MB" | awk -F'\t' '{print "M\t"$1"\t"$2"\t"$3}')"
    UN="$(git ls-files --others --exclude-standard | keep)"
    while IFS= read -r f; do [ -n "$f" ] && LIST="$LIST"$'\n'"A	$(wc -l <"$f" 2>/dev/null | tr -d ' ')	0	$f"; done <<<"$UN" ;;
  all) LIST="$(git ls-files | keep | awk '{print "T\t0\t0\t"$0}')" ;;
esac
# Keep only code files, mark deletions.
OUT=""; N=0; ADD=0; DEL=0
while IFS=$'\t' read -r st a r p; do
  [ -z "${p:-}" ] && continue
  printf '%s\n' "$p" | keep >/dev/null || continue
  [ "$st" = M ] && [ ! -e "$p" ] && st=D
  case "$a" in ''|-) a=0 ;; esac; case "$r" in ''|-) r=0 ;; esac
  N=$((N+1)); ADD=$((ADD+a)); DEL=$((DEL+r))
  OUT="$OUT${OUT:+,}{\"path\":\"$(jesc "$p")\",\"status\":\"$st\",\"added\":$a,\"removed\":$r}"
done <<<"$LIST"

GRPJSON=""
if [ "$MODE" = all ]; then
  GRPJSON="$(git ls-files | keep | awk -F/ '{print (NF>1 ? $1 : ".")}' | sort | uniq -c | sort -rn | awk '{printf "%s{\"folder\":\"%s\",\"files\":%d}", (NR>1?",":""), $2, $1}')"
fi
printf '{"mode":"%s","root":"%s","base":"%s","totals":{"files":%d,"added":%d,"removed":%d},"groups":[%s],"files":[%s]}\n' \
  "$MODE" "$(jesc "$ROOT")" "$(jesc "$BASE")" "$N" "$ADD" "$DEL" "$GRPJSON" "$OUT"
