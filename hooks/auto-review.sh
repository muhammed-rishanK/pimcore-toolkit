#!/usr/bin/env bash
# Automatic code review for Pimcore projects.
#   auto-review.sh baseline   (SessionStart) remember the current state of the working tree
#   auto-review.sh stop       (Stop) when code changed since the last review, ask Claude to run
#                             /pimcore-review on the changes before it finishes
# It only reads the repository and writes one small state file inside .git. It does nothing in
# folders that are not git repositories with pimcore/pimcore in composer.json.
# Turn it off: PIMCORE_AUTO_REVIEW=0 (everywhere) or "git config pimcore.autoReview false" (one project).
set -u
EVENT="${1:-stop}"
INPUT="$(cat 2>/dev/null || true)"
[ "${PIMCORE_AUTO_REVIEW:-1}" = 0 ] && exit 0

field() { printf '%s' "$INPUT" | grep -o "\"$1\"[[:space:]]*:[[:space:]]*\(\"[^\"]*\"\|true\|false\)" | head -1 | sed -E 's/^[^:]*:[[:space:]]*//; s/^"//; s/"$//'; }
CWD="$(field cwd)"; [ -n "$CWD" ] && cd "$CWD" 2>/dev/null
command -v git >/dev/null 2>&1 || exit 0
TOP="$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0
cd "$TOP" || exit 0
grep -q '"pimcore/pimcore"' composer.json 2>/dev/null || exit 0
[ "$(git config --get pimcore.autoReview 2>/dev/null)" = false ] && exit 0

STATE="$(git rev-parse --git-path pimcore-review-last 2>/dev/null)" || exit 0
case "$STATE" in /*) ;; *) STATE="$TOP/$STATE" ;; esac

CODE='\.(php|twig|ya?ml|xml|js|jsx|ts|tsx|neon|sql)$'
SKIP='^(vendor|var/cache|var/log|var/tmp|var/classes/DataObject|node_modules|public/bundles|public/var|\.claude)/'
# Fingerprint of the uncommitted code changes (tracked diff plus untracked code files).
fingerprint() {
  {
    git diff HEAD --no-color --no-ext-diff 2>/dev/null | head -c 5000000
    git ls-files --others --exclude-standard 2>/dev/null | grep -E "$CODE" | grep -v -E "$SKIP" | head -500 | while IFS= read -r f; do
      printf '%s\n' "$f"; head -c 200000 "$f" 2>/dev/null
    done
  } | { sha1sum 2>/dev/null || shasum; } | cut -c1-40
}
has_code_changes() {
  { git diff HEAD --name-only 2>/dev/null; git ls-files --others --exclude-standard 2>/dev/null; } \
    | grep -E "$CODE" | grep -v -E "$SKIP" | grep -q .
}

NOW="$(fingerprint)"
if [ "$EVENT" = baseline ]; then
  printf '%s\n' "$NOW" >"$STATE" 2>/dev/null
  exit 0
fi

LAST="$(cat "$STATE" 2>/dev/null)"
# Claude is already continuing because of this hook: count the fixes it made as reviewed, no loop.
if [ "$(field stop_hook_active)" = true ]; then
  printf '%s\n' "$NOW" >"$STATE" 2>/dev/null
  exit 0
fi
[ "$NOW" = "$LAST" ] && exit 0
has_code_changes || { printf '%s\n' "$NOW" >"$STATE" 2>/dev/null; exit 0; }
printf '%s\n' "$NOW" >"$STATE" 2>/dev/null

SKILL="$(cd "$(dirname "$0")/.." && pwd)/skills/pimcore-review/SKILL.md"
REASON="Pimcore auto-review: code in this project changed since the last review. Before you finish, review the uncommitted changes by following $SKILL with no arguments (changes mode): run the pimcore-toolkit:pimcore-code-reviewer agent on the diff and its callers, then report each finding with severity, file:line, the lines of code that cause it, why it is a problem, the fix and a test plan. Do not change any code during the review. If every change is trivial (comments, formatting), say so in one line instead. To turn this off: PIMCORE_AUTO_REVIEW=0, or git config pimcore.autoReview false in this project."
printf '{"decision":"block","reason":"%s"}\n' "$(printf '%s' "$REASON" | sed 's/\\/\\\\/g; s/"/\\"/g')"
exit 0
