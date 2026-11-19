#!/usr/bin/env bash
# Read-only five-level health check for a Pimcore project.
#   1 installation completed  2 database initialized  3 application healthy
#   4 admin accessible        5 optional services
# Never prints secrets; output lines containing a value from
# .pimcore-setup/secrets.env are masked. Exit 0 only if checks 1-4 pass.
# Usage: health-check.sh --dir <project> [--runtime docker|native] [--url http://localhost:8080] [--php-service php] [--json]

DIR="."; RUNTIME=""; URL=""; PHPSVC="php"; JSON=0
while [ $# -gt 0 ]; do
  case "$1" in
    --dir) DIR="$2"; shift 2 ;;
    --runtime) RUNTIME="$2"; shift 2 ;;
    --url) URL="${2%/}"; shift 2 ;;
    --php-service) PHPSVC="$2"; shift 2 ;;
    --json) JSON=1; shift ;;
    -h|--help) sed -n '2,7p' "$0"; exit 0 ;;
    *) shift ;;
  esac
done
cd "$DIR" 2>/dev/null || { echo "project folder not found: $DIR" >&2; exit 2; }
have() { command -v "$1" >/dev/null 2>&1; }

COMPOSE_FILE=""
for f in docker-compose.yaml docker-compose.yml compose.yaml compose.yml; do [ -f "$f" ] && { COMPOSE_FILE="$f"; break; }; done
if [ -z "$RUNTIME" ]; then
  if [ -n "$COMPOSE_FILE" ] && have docker && docker compose ps -q "$PHPSVC" 2>/dev/null | grep -q .; then RUNTIME=docker; else RUNTIME=native; fi
fi

# Secret masking
MASKS=()
if [ -r .pimcore-setup/secrets.env ]; then
  while IFS='=' read -r k v; do
    case "$k" in *PASSWORD*) [ -n "$v" ] && MASKS+=("$v") ;; esac
  done < .pimcore-setup/secrets.env
fi
mask() { local s="$1" m; for m in "${MASKS[@]}"; do s="${s//"$m"/****}"; done; printf '%s' "$s"; }

run_console() { # run bin/console in the right runtime, quietly
  if [ "$RUNTIME" = docker ]; then docker compose exec -T "$PHPSVC" php bin/console "$@" 2>&1
  else php bin/console "$@" 2>&1; fi
}

R=(); E=()
set_r() { R[$1]="$2"; E[$1]="$(mask "$3" | tr -d '\r' | tr '\n' ' ' | cut -c1-160)"; }

# 1 Installation completed
if [ ! -f composer.json ]; then set_r 1 fail "no composer.json"
elif [ ! -d vendor ] && [ "$RUNTIME" = native ]; then set_r 1 fail "vendor/ missing (run composer install)"
else
  out=$(run_console --version --no-ansi)
  if [ $? -eq 0 ] && printf '%s' "$out" | grep -qi 'pimcore\|symfony'; then
    ver=$(grep -A3 '"name": "pimcore/pimcore"' composer.lock 2>/dev/null | grep -Eo '"version": "[^"]+"' | head -1 | cut -d'"' -f4)
    if [ -f config/local/database.yaml ] || [ -n "$(run_console dbal:run-sql 'SELECT 1' --no-ansi 2>/dev/null | grep -c 1)" ]; then
      set_r 1 pass "console runs; pimcore ${ver:-unknown}"
    else set_r 1 fail "console runs but no database config (installer not run?)"; fi
  else set_r 1 fail "bin/console failed: $(printf '%s' "$out" | tail -1)"; fi
fi

# 2 Database initialized
if [ "${R[1]}" != pass ]; then set_r 2 skipped "depends on #1"
else
  # number on its own line (table cell); empty if the query failed
  num() { printf '%s\n' "$1" | sed -n 's/^[[:space:]|]*\([0-9][0-9]*\)[[:space:]|]*$/\1/p' | tail -1; }
  t=$(run_console dbal:run-sql "SELECT COUNT(*) AS c FROM information_schema.tables WHERE table_schema = DATABASE()" --no-ansi 2>&1); tst=$?
  u=$(run_console dbal:run-sql "SELECT COUNT(*) AS c FROM users WHERE type = 'user' AND admin = 1" --no-ansi 2>&1); ust=$?
  tables=""; admins=""
  [ $tst -eq 0 ] && tables=$(num "$t")
  [ $ust -eq 0 ] && admins=$(num "$u")
  if [ -z "$tables" ]; then set_r 2 fail "query failed: $(printf '%s' "$t" | grep -v '^[[:space:]]*$' | tail -1)"
  elif [ "$tables" -gt 20 ] && [ -n "$admins" ] && [ "$admins" -ge 1 ]; then set_r 2 pass "$tables tables, $admins admin user(s)"
  else set_r 2 fail "$tables tables, admin users: ${admins:-unknown}"; fi
fi

# Base URL
if [ -z "$URL" ] && [ "$RUNTIME" = docker ] && [ -n "$COMPOSE_FILE" ]; then
  hp=$(docker compose port nginx 80 2>/dev/null | head -1 | awk -F: '{print $NF}')
  [ -n "$hp" ] && URL="http://localhost:$hp"
fi
TMPB=$(mktemp 2>/dev/null || echo "${TMPDIR:-/tmp}/.pchk.$$")
http() { curl -s -o "$TMPB" -w '%{http_code} %{time_total}' --max-time 20 "$1" 2>/dev/null; }

# 3 Application healthy
if [ "${R[1]}" != pass ]; then set_r 3 skipped "depends on #1"
elif [ -z "$URL" ]; then set_r 3 skipped "no URL known (pass --url)"
elif ! have curl; then set_r 3 skipped "curl not found"
else
  read -r code tt <<<"$(http "$URL/")"
  if printf '%s' "$code" | grep -Eq '^(200|301|302|303|404)$' && ! grep -qi 'fatal error\|stack trace' "$TMPB" 2>/dev/null; then
    set_r 3 pass "GET / $code in ${tt}s"
  else set_r 3 fail "GET / ${code:-no answer}"; fi
fi

# 4 Admin accessible
if [ "${R[3]}" != pass ]; then set_r 4 skipped "depends on #3"
else
  read -r code tt <<<"$(http "$URL/admin/login")"
  if [ "$code" = 200 ] && grep -qi 'password' "$TMPB" 2>/dev/null; then set_r 4 pass "GET /admin/login 200, login form found"
  else set_r 4 fail "GET /admin/login $code"; fi
fi
rm -f "$TMPB"

# 5 Optional services
opt=""; ofail=0
if [ "$RUNTIME" = docker ]; then
  for s in $(docker compose config --services 2>/dev/null); do
    st=$(docker compose ps --format '{{.State}}' "$s" 2>/dev/null | head -1)
    opt="$opt$s:${st:-not running} "
    case "$s" in redis|supervisord|opensearch|elasticsearch|mailpit|mailhog) [ "$st" = running ] || ofail=1 ;; esac
  done
else
  if have redis-cli; then r=$(redis-cli ping 2>/dev/null); opt="redis:${r:-no answer} "; fi
  # count only consumers started from this project folder
  w=0; here=$(pwd -P)
  for pid in $(pgrep -f 'messenger:consume' 2>/dev/null); do
    cwd=$(readlink "/proc/$pid/cwd" 2>/dev/null || lsof -a -p "$pid" -d cwd -Fn 2>/dev/null | sed -n 's/^n//p')
    [ "$cwd" = "$here" ] && w=1
  done
  if [ "$w" = 1 ]; then opt="${opt}workers:running"; else opt="${opt}workers:not running"; ofail=1; fi
fi
if [ -z "$opt" ]; then set_r 5 skipped "nothing to check"
elif [ "$ofail" = 1 ]; then set_r 5 fail "$opt"
else set_r 5 pass "$opt"; fi

names=("" "Installation completed" "Database initialized" "Application healthy" "Admin accessible" "Optional services")
if [ "$JSON" = 1 ]; then
  printf '{"runtime":"%s","url":"%s","checks":[' "$RUNTIME" "$URL"
  for i in 1 2 3 4 5; do printf '{"id":%d,"name":"%s","result":"%s","evidence":"%s"}' "$i" "${names[$i]}" "${R[$i]}" "$(printf '%s' "${E[$i]}" | sed 's/"/\\"/g')"; [ $i -lt 5 ] && printf ','; done
  printf ']}\n'
else
  echo "runtime: $RUNTIME   url: ${URL:-unknown}"
  printf '%-2s %-24s %-8s %s\n' "#" "Check" "Result" "Evidence"
  for i in 1 2 3 4 5; do printf '%-2s %-24s %-8s %s\n' "$i" "${names[$i]}" "${R[$i]}" "${E[$i]}"; done
fi
for i in 1 2 3 4; do [ "${R[$i]}" = pass ] || exit 1; done
exit 0
