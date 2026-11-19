#!/usr/bin/env bash
# Read-only environment detection for /pimcore-setup.
# Prints JSON: OS, arch, resources, Docker, PHP, Composer, DB client, Git, Node,
# port usage and the target folder state. Changes nothing.
# Usage: detect-env.sh [--dir <target>]
# Works on Linux, macOS, WSL2 and Git Bash on Windows.

TARGET="."
while [ $# -gt 0 ]; do
  case "$1" in
    --dir) TARGET="$2"; shift 2 ;;
    -h|--help) sed -n '2,6p' "$0"; exit 0 ;;
    *) shift ;;
  esac
done

have() { command -v "$1" >/dev/null 2>&1; }
jstr() { if [ -z "$1" ]; then printf 'null'; else printf '"%s"' "$(printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g' | tr -d '\r\n')"; fi; }
jbool() { if [ "$1" = 1 ]; then printf true; else printf false; fi; }

WARN=()
UNAME_S=$(uname -s 2>/dev/null)
ARCH=$(uname -m 2>/dev/null)
OS="unknown"; OSD=""
case "$UNAME_S" in
  Linux)
    if grep -qi microsoft /proc/version 2>/dev/null; then OS="wsl2"; else OS="linux"; fi
    [ -r /etc/os-release ] && OSD=$(. /etc/os-release; echo "$PRETTY_NAME") ;;
  Darwin) OS="macos"; OSD="macOS $(sw_vers -productVersion 2>/dev/null)" ;;
  MINGW*|MSYS*|CYGWIN*) OS="windows-gitbash"; OSD=$(powershell.exe -NoProfile -Command "(Get-CimInstance Win32_OperatingSystem).Caption" 2>/dev/null | tr -d '\r') ;;
esac

# CPU and memory
CPUS=""; MEMGB=""
case "$OS" in
  linux|wsl2)
    CPUS=$(nproc 2>/dev/null)
    MEMGB=$(awk '/MemTotal/ {printf "%.1f", $2/1048576}' /proc/meminfo 2>/dev/null) ;;
  macos)
    CPUS=$(sysctl -n hw.ncpu 2>/dev/null)
    MEMGB=$(sysctl -n hw.memsize 2>/dev/null | awk '{printf "%.1f", $1/1073741824}') ;;
  windows-gitbash)
    CPUS=$(powershell.exe -NoProfile -Command "[Environment]::ProcessorCount" 2>/dev/null | tr -d '\r')
    MEMGB=$(powershell.exe -NoProfile -Command "[math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory/1GB,1)" 2>/dev/null | tr -d '\r') ;;
esac

# Disk free at the target (or its parent)
CHK="$TARGET"; while [ ! -d "$CHK" ] && [ "$CHK" != "/" ] && [ "$CHK" != "." ]; do CHK=$(dirname "$CHK"); done
DISK=$(df -Pk "$CHK" 2>/dev/null | awk 'NR==2 {printf "%.1f", $4/1048576}')

# Docker
D_INST=0; D_VER=""; D_RUN=0; C_VER=""; C_V1=0
if have docker; then
  D_INST=1
  D_VER=$(docker version --format '{{.Client.Version}}' 2>/dev/null)
  docker info >/dev/null 2>&1 && D_RUN=1
  C_VER=$(docker compose version --short 2>/dev/null)
fi
have docker-compose && C_V1=1
[ "$D_INST" = 1 ] && [ "$D_RUN" = 0 ] && WARN+=("docker installed but daemon not reachable")
[ "$D_INST" = 1 ] && [ -z "$C_VER" ] && WARN+=("docker compose v2 plugin missing")

# PHP
P_VER=""; P_EXT=""
if have php; then
  P_VER=$(php -r 'echo PHP_VERSION;' 2>/dev/null)
  P_EXT=$(php -m 2>/dev/null | grep -v '^\[' | grep -v '^$' | tr 'A-Z' 'a-z' | sort -u | tr '\n' ',' | sed 's/,$//')
fi
CMP=""; have composer && CMP=$(composer --version --no-ansi 2>/dev/null | awk '{print $3}')
DBC=""
if have mariadb; then DBC="mariadb $(mariadb --version 2>/dev/null | awk '{print $3,$5}')"
elif have mysql; then DBC="mysql $(mysql --version 2>/dev/null | awk '{print $3}')"; fi
GIT=""; have git && GIT=$(git --version 2>/dev/null | awk '{print $3}')
NODE=""; have node && NODE=$(node --version 2>/dev/null)
SYMF=""; have symfony && SYMF=$(symfony version --no-ansi 2>/dev/null | head -1)

# Ports: report in use or free, without connecting to anything outside localhost
port_used() {
  local p="$1"
  if have ss; then ss -ltnH 2>/dev/null | awk '{print $4}' | grep -Eq "[:.]$p\$" && return 0; return 1; fi
  if have lsof; then lsof -nP -iTCP:"$p" -sTCP:LISTEN >/dev/null 2>&1 && return 0; return 1; fi
  if have netstat; then netstat -an 2>/dev/null | grep -Ei 'listen' | grep -Eq "[:.]$p[[:space:]]" && return 0; return 1; fi
  (exec 3<>"/dev/tcp/127.0.0.1/$p") 2>/dev/null && { exec 3>&- 3<&-; return 0; }
  return 1
}
PORTS=""
for p in 80 443 3306 6379 8080 8025; do
  if port_used "$p"; then s="in use"; else s="free"; fi
  PORTS="$PORTS\"$p\":\"$s\","
done
PORTS="{${PORTS%,}}"

# Target folder
T_EX=0; T_EMPTY=0; T_PIM=0; T_WIN=0
if [ -d "$TARGET" ]; then
  T_EX=1
  [ -z "$(ls -A "$TARGET" 2>/dev/null)" ] && T_EMPTY=1
  if [ -f "$TARGET/composer.json" ] && grep -q '"pimcore/pimcore"\|"pimcore/skeleton"\|"pimcore/demo"' "$TARGET/composer.json" 2>/dev/null; then T_PIM=1; fi
  if [ -f "$TARGET/composer.lock" ] && grep -q '"name": "pimcore/pimcore"' "$TARGET/composer.lock" 2>/dev/null; then T_PIM=1; fi
fi
ABS=$(cd "$(dirname "$TARGET")" 2>/dev/null && printf '%s/%s' "$PWD" "$(basename "$TARGET")")
case "$ABS" in /mnt/[a-z]/*) [ "$OS" = wsl2 ] && { T_WIN=1; WARN+=("target is on a Windows mount; use the Linux filesystem (for example ~/projects)"); } ;; esac
case "$ABS" in *" "*) WARN+=("target path contains spaces") ;; esac
case "$ARCH" in arm64|aarch64) WARN+=("ARM CPU: confirm the Docker image tags support arm64") ;; esac

W=""; for w in "${WARN[@]}"; do W="$W$(jstr "$w"),"; done; W="[${W%,}]"

cat <<EOF
{
  "os": $(jstr "$OS"),
  "osDetail": $(jstr "$OSD"),
  "arch": $(jstr "$ARCH"),
  "cpus": $(jstr "$CPUS"),
  "memGB": $(jstr "$MEMGB"),
  "diskFreeGB": $(jstr "$DISK"),
  "docker": {"installed": $(jbool $D_INST), "version": $(jstr "$D_VER"), "daemonRunning": $(jbool $D_RUN), "composeV2": $(jstr "$C_VER"), "composeV1Present": $(jbool $C_V1)},
  "php": {"version": $(jstr "$P_VER"), "extensions": $(jstr "$P_EXT")},
  "composer": $(jstr "$CMP"),
  "mysqlClient": $(jstr "$DBC"),
  "symfonyCli": $(jstr "$SYMF"),
  "git": $(jstr "$GIT"),
  "node": $(jstr "$NODE"),
  "ports": $PORTS,
  "target": {"path": $(jstr "$ABS"), "exists": $(jbool $T_EX), "empty": $(jbool $T_EMPTY), "isPimcore": $(jbool $T_PIM), "onWindowsMount": $(jbool $T_WIN)},
  "warnings": $W
}
EOF
