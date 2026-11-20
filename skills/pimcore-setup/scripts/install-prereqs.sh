#!/usr/bin/env bash
# Installs Docker Engine + the compose plugin on Linux, or reports what to run elsewhere.
# Usage: install-prereqs.sh [--check]
#   --check   report what is missing; change nothing
# Linux uses the distribution package manager through "sudo -n" (passwordless sudo only).
# If sudo needs a password, nothing is changed and the exact command is printed, because
# the system password is never read or bypassed. macOS uses Colima (free, no Docker Desktop
# licence) through Homebrew; a Docker Desktop the user already has is started, never installed.
# Output: one JSON object. status: ready | needs_password | unsupported | failed | check.
set -u
CHECK=0; [ "${1:-}" = "--check" ] && CHECK=1
have() { command -v "$1" >/dev/null 2>&1; }
dock_ok() { have docker && docker info >/dev/null 2>&1; }
js() { printf '{"status":"%s","note":"%s","command":"%s"}\n' "$1" "$2" "$3"; }

if dock_ok && docker compose version >/dev/null 2>&1; then js ready "" ""; exit 0; fi
OS="$(uname -s)"
# Installed but the daemon is stopped: start it, never reinstall.
if have docker && docker compose version >/dev/null 2>&1; then
  if [ "$OS" = Darwin ]; then if have colima; then START="colima start"; else START="open -a Docker"; fi; else START="systemctl enable --now docker"; fi
  [ "$CHECK" = 1 ] && { js check "Docker is installed but not running" "$START"; exit 0; }
  if [ "$OS" = Darwin ]; then $START >/dev/null 2>&1
  elif [ "$(id -u)" = 0 ]; then systemctl enable --now docker >/dev/null 2>&1
  elif sudo -n true 2>/dev/null; then sudo -n systemctl enable --now docker >/dev/null 2>&1
  else js needs_password "Docker is installed but stopped; sudo needs a password, which the plugin never reads" "sudo $START"; exit 2; fi
  for _ in $(seq 1 24); do { dock_ok || sudo -n docker info >/dev/null 2>&1; } && { js ready "Docker was started" ""; exit 0; }; sleep 5; done
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
    for _ in $(seq 1 24); do dock_ok && docker compose version >/dev/null 2>&1 && { js ready "Docker runs through Colima" ""; exit 0; }; sleep 5; done
    js failed "Colima did not become ready" "colima start"; exit 1
  fi
  js unsupported "Homebrew not found" "install Homebrew, then: brew install colima docker docker-compose && colima start"; exit 1
fi
# Linux
if have apt-get; then CMD="apt-get update && apt-get install -y docker.io docker-compose-v2"
elif have dnf; then CMD="dnf install -y docker docker-compose-plugin"
elif have pacman; then CMD="pacman -S --noconfirm docker docker-compose"
else js unsupported "no supported package manager" "see https://docs.docker.com/engine/install/"; exit 1; fi
[ "$CHECK" = 1 ] && { js check "Docker missing" "sudo sh -c '$CMD'"; exit 0; }
if [ "$(id -u)" = 0 ] || sudo -n true 2>/dev/null; then
  S=""; [ "$(id -u)" = 0 ] || S="sudo -n"
  $S sh -c "$CMD" >/dev/null 2>&1 && $S systemctl enable --now docker >/dev/null 2>&1
  [ "$(id -u)" = 0 ] || $S usermod -aG docker "$USER" >/dev/null 2>&1
  if dock_ok || $S docker info >/dev/null 2>&1; then js ready "If docker needs sudo, log out and in once for the docker group" ""; exit 0; fi
  js failed "install ran but Docker is not responding" "$S docker info"; exit 1
fi
js needs_password "sudo needs a password, which the plugin never reads" "sudo sh -c '$CMD'"; exit 2
