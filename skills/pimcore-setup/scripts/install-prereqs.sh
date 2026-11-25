#!/usr/bin/env bash
# Installs Docker Engine + the compose plugin on Linux, or reports what to run elsewhere.
# Usage: install-prereqs.sh [--check]
#   --check   report what is missing; change nothing
# Linux uses the distribution package manager through "sudo -n" (passwordless sudo only).
# If sudo needs a password, nothing is changed and the exact command is printed, because
# the system password is never read or bypassed. The orchestrator can open a terminal tab
# with that command so the user only types the password there. macOS uses Colima (free, no
# Docker Desktop licence) through Homebrew; a Docker Desktop the user already has is started,
# never installed.
# Output: one JSON object.
#   status: ready | needs_password | unsupported | failed | check
#   dockerCmd: how to call docker in this session without logging out:
#     "docker"                 the current user can reach the daemon
#     "sg docker -c"           user is in the docker group, but this shell started before that
#                              (wrap each command: sg docker -c "docker compose up -d")
#     "sudo -n docker"         passwordless sudo only
set -u
CHECK=0; [ "${1:-}" = "--check" ] && CHECK=1
have() { command -v "$1" >/dev/null 2>&1; }
dock_ok() { have docker && docker info >/dev/null 2>&1; }
# The docker group is read at login, so a shell started before "usermod -aG docker" cannot use
# it. "sg docker" starts the command with that group, without a password and without a logout.
sg_ok() { have sg && id -nG "${USER:-$(id -un)}" 2>/dev/null | grep -qw docker && sg docker -c "docker info" >/dev/null 2>&1; }
sudo_ok() { [ "$(id -u)" != 0 ] && sudo -n docker info >/dev/null 2>&1; }
docker_cmd() {
  if dock_ok; then echo "docker"
  elif sg_ok; then echo "sg docker -c"
  elif sudo_ok; then echo "sudo -n docker"
  else echo ""; fi
}
js() { printf '{"status":"%s","note":"%s","command":"%s","dockerCmd":"%s"}\n' "$1" "$2" "$3" "${4:-}"; }
compose_ok() { docker compose version >/dev/null 2>&1; }
ready_now() { local c; c="$(docker_cmd)"; [ -n "$c" ] && { js ready "$1" "" "$c"; exit 0; }; return 0; }

have docker && compose_ok && ready_now ""
OS="$(uname -s)"
ME="${USER:-$(id -un)}"
# Daemon runs but this user may not use it: add the user to the docker group (no reinstall).
if have docker && docker info 2>&1 | grep -qi "permission denied"; then
  GRP="usermod -aG docker $ME"
  [ "$CHECK" = 1 ] && { js check "Docker runs but $ME is not in the docker group" "sudo $GRP"; exit 0; }
  if [ "$(id -u)" != 0 ] && sudo -n true 2>/dev/null; then
    sudo -n $GRP >/dev/null 2>&1
    ready_now "$ME was added to the docker group; use dockerCmd, no logout needed"
    js failed "added $ME to the docker group, but docker still refuses the connection" "sudo $GRP"; exit 1
  fi
  js needs_password "Docker runs but $ME is not in the docker group; sudo needs a password, which the plugin never reads" "sudo $GRP"; exit 2
fi
# Installed but the daemon is stopped: start it, never reinstall.
if have docker && compose_ok; then
  if [ "$OS" = Darwin ]; then if have colima; then START="colima start"; else START="open -a Docker"; fi; else START="systemctl enable --now docker"; fi
  [ "$CHECK" = 1 ] && { js check "Docker is installed but not running" "$START"; exit 0; }
  if [ "$OS" = Darwin ]; then $START >/dev/null 2>&1
  elif [ "$(id -u)" = 0 ]; then systemctl enable --now docker >/dev/null 2>&1
  elif sudo -n true 2>/dev/null; then sudo -n systemctl enable --now docker >/dev/null 2>&1
  else js needs_password "Docker is installed but stopped; sudo needs a password, which the plugin never reads" "sudo $START"; exit 2; fi
  for _ in $(seq 1 24); do ready_now "Docker was started"; sleep 5; done
  js failed "Docker did not become ready" "$START"; exit 1
fi
if [ "$OS" = Darwin ]; then
  [ "$CHECK" = 1 ] && { js check "Docker missing (free route: Colima)" "brew install colima docker docker-compose && colima start"; exit 0; }
  if have brew; then
    brew install colima docker docker-compose >/dev/null 2>&1
    # The compose formula must be linked as a docker CLI plugin to give "docker compose".
    mkdir -p "$HOME/.docker/cli-plugins"
    ln -sfn "$(brew --prefix)/opt/docker-compose/bin/docker-compose" "$HOME/.docker/cli-plugins/docker-compose"
    colima start >/dev/null 2>&1
    for _ in $(seq 1 24); do compose_ok && ready_now "Docker runs through Colima"; sleep 5; done
    js failed "Colima did not become ready" "colima start"; exit 1
  fi
  js unsupported "Homebrew not found" "install Homebrew, then: brew install colima docker docker-compose && colima start"; exit 1
fi
# Linux
if have apt-get; then CMD="apt-get update && apt-get install -y docker.io docker-compose-v2"
elif have dnf; then CMD="dnf install -y docker docker-compose-plugin"
elif have pacman; then CMD="pacman -S --noconfirm docker docker-compose"
else js unsupported "no supported package manager" "see https://docs.docker.com/engine/install/"; exit 1; fi
# One line the user can paste (or the orchestrator can open in a terminal tab): install,
# start, and add the user to the docker group. The password is typed by the user only.
FULL="sudo sh -c '$CMD && systemctl enable --now docker && usermod -aG docker $ME'"
[ "$CHECK" = 1 ] && { js check "Docker missing" "$FULL"; exit 0; }
if [ "$(id -u)" = 0 ] || sudo -n true 2>/dev/null; then
  S=""; [ "$(id -u)" = 0 ] || S="sudo -n"
  $S sh -c "$CMD" >/dev/null 2>&1 && $S systemctl enable --now docker >/dev/null 2>&1
  [ "$(id -u)" = 0 ] || $S usermod -aG docker "$ME" >/dev/null 2>&1
  for _ in $(seq 1 12); do ready_now "Docker is installed; use dockerCmd for every docker call in this session, no logout needed"; sleep 5; done
  js failed "install ran but Docker is not responding" "$S docker info"; exit 1
fi
js needs_password "sudo needs a password, which the plugin never reads. Run the command in a terminal tab, then run this script again" "$FULL"; exit 2
