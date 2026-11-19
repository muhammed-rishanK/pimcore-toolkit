#!/usr/bin/env bash
# Installs Docker Engine + the compose plugin on Linux, or reports what to run elsewhere.
# Usage: install-prereqs.sh [--check]
#   --check   report what is missing; change nothing
# Linux uses the distribution package manager through "sudo -n" (passwordless sudo only).
# If sudo needs a password, nothing is changed and the exact command is printed, because
# the system password is never read or bypassed. macOS needs Docker Desktop (brew cask).
# Output: one JSON object. status: ready | needs_password | unsupported | failed | check.
set -u
CHECK=0; [ "${1:-}" = "--check" ] && CHECK=1
have() { command -v "$1" >/dev/null 2>&1; }
dock_ok() { have docker && docker info >/dev/null 2>&1; }
js() { printf '{"status":"%s","note":"%s","command":"%s"}\n' "$1" "$2" "$3"; }

if dock_ok && docker compose version >/dev/null 2>&1; then js ready "" ""; exit 0; fi
OS="$(uname -s)"
if [ "$OS" = Darwin ]; then
  [ "$CHECK" = 1 ] && { js check "Docker Desktop missing" "brew install --cask docker"; exit 0; }
  if have brew; then
    brew install --cask docker >/dev/null 2>&1 && open -a Docker >/dev/null 2>&1
    for _ in $(seq 1 60); do dock_ok && { js ready "" ""; exit 0; }; sleep 5; done
    js failed "Docker Desktop did not become ready; open it once to accept its terms" "open -a Docker"; exit 1
  fi
  js unsupported "Homebrew not found" "install Homebrew, then: brew install --cask docker"; exit 1
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
