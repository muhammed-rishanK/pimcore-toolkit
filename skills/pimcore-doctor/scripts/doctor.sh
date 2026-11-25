#!/usr/bin/env bash
# Read-only health audit of an existing Pimcore project. Changes nothing, starts nothing,
# never prints a secret value (only file names and key names).
# Usage: doctor.sh [<project-root>] [--format table|json] [--online]
#   --online   also run "composer audit --locked" (needs network and composer)
# Each check: id, area, result (pass | warn | fail | skip), evidence, fix.
# Exit code: 0 when no check failed, 1 when at least one failed, 2 on bad arguments.
set -u
ROOT="."; FORMAT="table"; ONLINE=0
while [ $# -gt 0 ]; do
  case "$1" in
    --format) FORMAT="${2:-}"; shift 2 ;;
    --online) ONLINE=1; shift ;;
    -h|--help) sed -n '2,7p' "$0"; exit 0 ;;
    -*) echo "unknown option: $1" >&2; exit 2 ;;
    *) ROOT="$1"; shift ;;
  esac
done
case "$FORMAT" in table|json) ;; *) echo "--format must be table or json" >&2; exit 2 ;; esac
HERE="$(cd "$(dirname "$0")" && pwd)"
TK="$(cd "$HERE/../../.." && pwd)"
cd "$ROOT" 2>/dev/null || { echo "project folder not found: $ROOT" >&2; exit 2; }
ROOT="$(pwd)"
have() { command -v "$1" >/dev/null 2>&1; }

IDS=(); AREAS=(); RES=(); EVI=(); FIX=()
add() { IDS+=("$1"); AREAS+=("$2"); RES+=("$3"); EVI+=("$4"); FIX+=("${5:-}"); }
jesc() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g' | tr -d '\r' | tr '\n' ' '; }
jget() { # jget <json> <key>: first string or literal value of a top-level key
  printf '%s' "$1" | grep -m1 "\"$2\":" | sed -E 's/^[^:]*:[[:space:]]*//; s/,[[:space:]]*$//; s/^"//; s/"$//'
}

# 1 project and versions
DET="$(bash "$TK/skills/pimcore/scripts/detect-project.sh" "$ROOT" 2>/dev/null)"
if [ "$(jget "$DET" isPimcore)" != "true" ]; then
  add project "project" fail "no pimcore/pimcore in composer.json or composer.lock" "run this in the project root, or use /pimcore-setup for a new project"
else
  PV="$(jget "$DET" pimcore)"; SV="$(jget "$DET" symfony)"
  add project "project" pass "pimcore ${PV:-unknown}, symfony ${SV:-unknown}" ""
  case "$PV" in
    v10.*|10.*) add version "versions" warn "Pimcore $PV is past its support period (see references/pimcore-versions.md)" "plan the upgrade: /pimcore plan an upgrade to Pimcore 11" ;;
    v11.*|11.*) add version "versions" warn "Pimcore $PV: the 11 line is supported through the 2024.4 LTS (see references/pimcore-versions.md)" "run the upgrade scan below and plan the move to 2025.4" ;;
    "") add version "versions" warn "no Pimcore version in composer.lock" "run composer install so composer.lock exists" ;;
    *) add version "versions" pass "Pimcore $PV" "" ;;
  esac
fi

# 2 composer files
if [ -f composer.lock ]; then add lockfile "composer" pass "composer.lock present" ""
else add lockfile "composer" fail "composer.lock missing" "run composer update once and commit composer.lock"; fi
if grep -q '"platform"' composer.json 2>/dev/null && grep -A3 '"platform"' composer.json | grep -q '"php"'; then
  add php-platform "composer" pass "config.platform.php is set" ""
elif [ -n "$(jget "$DET" phpRequire)" ] && [ "$(jget "$DET" phpRequire)" != "null" ]; then
  add php-platform "composer" pass "require.php is $(jget "$DET" phpRequire)" ""
else
  add php-platform "composer" warn "composer.json pins no PHP version, so composer may resolve packages for the wrong PHP" "set config.platform.php to the PHP the app runs on"
fi

# 3 git hygiene: secrets and generated folders
if have git && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  TRACKED=""
  for f in .env.local .env.prod.local config/local/database.yaml .pimcore-setup/secrets.env docker-compose.override.yaml; do
    git ls-files --error-unmatch "$f" >/dev/null 2>&1 && TRACKED="$TRACKED $f"
  done
  if [ -n "$TRACKED" ]; then
    add secrets-tracked "security" fail "tracked in git:$TRACKED" "git rm --cached <file>, add it to .gitignore, and rotate any password it held"
  else
    add secrets-tracked "security" pass "no local secret files are tracked" ""
  fi
  # Passwords written straight into tracked config (key names only, never the value).
  HITS="$(git grep -n -I -E '^[[:space:]]*(password|DATABASE_PASSWORD|MYSQL_ROOT_PASSWORD|MYSQL_PASSWORD)[[:space:]]*[:=][[:space:]]*[^[:space:]%$!{]' -- 'config/*.yaml' 'config/**/*.yaml' '.env' 'docker-compose*.y*ml' 2>/dev/null | grep -v -E "(env\(|%env|\\$\\{)" | cut -d: -f1,2 | head -5 | tr '\n' ' ')"
  if [ -n "$HITS" ]; then add plain-passwords "security" warn "a password value is written in tracked config at: $HITS" "move it to an environment variable or .env.local"
  else add plain-passwords "security" pass "no plain password values in tracked config" ""; fi
  MISS=""
  for p in vendor var/cache var/log public/var; do
    [ -e "$p" ] || continue
    git check-ignore -q "$p/x" 2>/dev/null || MISS="$MISS $p"
  done
  if [ -n "$MISS" ]; then add gitignore "git" warn "not ignored:$MISS" "add them to .gitignore"
  else add gitignore "git" pass "vendor, var/cache, var/log and public/var are ignored (where present)" ""; fi
  if [ -d var/classes ]; then
    if git ls-files var/classes | grep -q 'definition_'; then add class-defs "data model" pass "$(ls var/classes/definition_*.php 2>/dev/null | wc -l | tr -d ' ') class definitions, tracked in git" ""
    else add class-defs "data model" warn "var/classes/definition_*.php are not tracked, so class changes cannot be deployed or reviewed" "commit var/classes (definitions only, not DataObject/)"; fi
  fi
  DIRTY="$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')"
  if [ "$DIRTY" = 0 ]; then add worktree "git" pass "working tree clean" ""
  else add worktree "git" warn "$DIRTY uncommitted changes" "review them with /pimcore-review before you commit"; fi
else
  add git "git" skip "not a git repository" "git init, so changes can be reviewed and rolled back"
fi

# 4 runtime settings
if [ -f .env ] && grep -qE '^APP_ENV=prod' .env && grep -qE '^APP_DEBUG=(1|true)' .env; then
  add debug "runtime" fail "APP_ENV=prod with APP_DEBUG on in .env" "set APP_DEBUG=0 for prod"
elif [ -f .env ]; then add debug "runtime" pass "no prod-with-debug setting in .env" ""
else add debug "runtime" skip "no .env file" ""; fi
if grep -q '"symfony/messenger"' composer.lock 2>/dev/null; then
  W="$(grep -rlE 'messenger:consume' --include='*.conf' --include='*.ini' --include='*.y*ml' --include='Dockerfile*' --include='*.sh' . 2>/dev/null | grep -v -E '^\./(vendor|var|node_modules|\.claude|\.git)/' | head -3 | tr '\n' ' ')"
  if [ -n "$W" ]; then add workers "runtime" pass "messenger:consume is configured in: $W" ""
  else add workers "runtime" warn "symfony/messenger is installed but no worker config runs messenger:consume" "add a supervisor or compose service for messenger:consume pimcore_core pimcore_maintenance (and your own transports)"; fi
fi

# 5 quality tooling
T=""
for f in phpstan.neon phpstan.neon.dist phpstan.dist.neon .php-cs-fixer.php .php-cs-fixer.dist.php phpcs.xml phpcs.xml.dist ecs.php codeception.yml codeception.dist.yml phpunit.xml phpunit.xml.dist; do [ -f "$f" ] && T="$T $f"; done
if [ -n "$T" ]; then add tooling "quality" pass "found:$T" ""
else add tooling "quality" warn "no static analysis, code style or test config found" "add phpstan and a test suite; see testing-validation.md"; fi
if [ -d .github/workflows ] || [ -f .gitlab-ci.yml ] || [ -f bitbucket-pipelines.yml ]; then add ci "quality" pass "CI config present" ""
else add ci "quality" warn "no CI config" "run lint, static analysis and tests on every push"; fi

# 6 upgrade impact (read-only scan)
SCAN="$(bash "$TK/skills/pimcore/scripts/scan-platform-impact.sh" "$ROOT" --format json 2>/dev/null)"
if [ -n "$SCAN" ]; then
  TM="$(printf '%s' "$SCAN" | grep -m1 -o '"totalMatches":[[:space:]]*[0-9]*' | grep -o '[0-9]*$')"
  FA="$(printf '%s' "$SCAN" | grep -m1 -o '"filesAffected":[[:space:]]*[0-9]*' | grep -o '[0-9]*$')"
  if [ "${TM:-0}" = 0 ]; then add upgrade-scan "upgrades" pass "no known breaking-change patterns found" ""
  else add upgrade-scan "upgrades" warn "${TM} matches in ${FA:-?} files for the next platform step" "run: bash $TK/skills/pimcore/scripts/scan-platform-impact.sh . for the file:line list"; fi
else
  add upgrade-scan "upgrades" skip "scan did not run" ""
fi

# 7 dependency advisories (optional, network)
if [ "$ONLINE" = 1 ]; then
  if have composer; then
    if composer audit --locked --no-interaction --format=summary >/dev/null 2>&1; then add advisories "security" pass "composer audit found no advisories" ""
    else add advisories "security" warn "composer audit reported advisories or could not run" "run composer audit --locked and update the listed packages"; fi
  else add advisories "security" skip "composer not on PATH (run it in the PHP container)" ""; fi
fi

# 8 toolkit auto-update (reads the user's Claude Code settings, changes nothing)
AU="$(bash "$TK/skills/pimcore/scripts/enable-auto-update.sh" --check 2>/dev/null)"
AUS="$(printf '%s' "$AU" | grep -o '"status": *"[a-z]*"' | grep -o '"[a-z]*"$' | tr -d '"')"
AUN="$(printf '%s' "$AU" | grep -o '"note": *"[^"]*"' | sed -E 's/^"note": *"//; s/"$//')"
case "$AUS" in
  on) add auto-update "toolkit" pass "pimcore-toolkit updates itself when a new version is released" "" ;;
  blocked) add auto-update "toolkit" warn "$AUN" "unset that variable, or set FORCE_AUTOUPDATE_PLUGINS=1" ;;
  off) add auto-update "toolkit" warn "auto-update is off for the pimcore-toolkit marketplace, so new releases are not installed" "bash $TK/skills/pimcore/scripts/enable-auto-update.sh (or /plugin, Marketplaces, pimcore-toolkit, enable auto-update)" ;;
  *) add auto-update "toolkit" skip "could not read the Claude Code settings" "" ;;
esac

FAILN=0; WARNN=0; PASSN=0
for r in "${RES[@]}"; do case "$r" in fail) FAILN=$((FAILN+1));; warn) WARNN=$((WARNN+1));; pass) PASSN=$((PASSN+1));; esac; done
if [ "$FORMAT" = json ]; then
  printf '{"root":"%s","readOnly":true,"summary":{"pass":%d,"warn":%d,"fail":%d},"checks":[' "$(jesc "$ROOT")" "$PASSN" "$WARNN" "$FAILN"
  for i in "${!IDS[@]}"; do
    [ "$i" -gt 0 ] && printf ','
    printf '{"id":"%s","area":"%s","result":"%s","evidence":"%s","fix":"%s"}' "${IDS[$i]}" "${AREAS[$i]}" "${RES[$i]}" "$(jesc "${EVI[$i]}")" "$(jesc "${FIX[$i]}")"
  done
  printf ']}\n'
else
  printf 'Pimcore doctor: %s (read-only)\n\n' "$ROOT"
  for i in "${!IDS[@]}"; do
    printf '%-5s %-11s %-16s %s\n' "$(printf '%s' "${RES[$i]}" | tr a-z A-Z)" "${AREAS[$i]}" "${IDS[$i]}" "${EVI[$i]}"
    [ -n "${FIX[$i]}" ] && [ "${RES[$i]}" != pass ] && printf '%34s fix: %s\n' "" "${FIX[$i]}"
  done
  printf '\n%d pass, %d warn, %d fail\n' "$PASSN" "$WARNN" "$FAILN"
fi
[ "$FAILN" = 0 ]
