# Changelog

## 0.1.6

- macOS now installs Colima (free) through Homebrew instead of Docker Desktop. A Docker Desktop you already have is started, never installed.
- Removed leftover Docker Desktop mentions from the docs; troubleshooting now lists the start command per OS.
- macOS route is untested on a real Mac; reports welcome.

## 0.1.5

- Windows is now free: `install-prereqs.ps1` no longer installs Docker Desktop (paid licence at larger companies). It uses a Docker that already works, otherwise it installs WSL2 + Ubuntu and Docker Engine inside it. No licence or cost question is asked.
- Windows administrator prompt appears only when WSL itself must be enabled.
- Still untested on a real Windows machine; reports welcome.

## 0.1.4

- `install-prereqs.sh` no longer treats an installed but stopped Docker as missing: it reports and starts it instead of reinstalling.

## 0.1.3

- Windows: missing WSL2 and Docker Desktop are now installed from one administrator-level script, so Windows shows a single administrator prompt instead of two.

## 0.1.2

- `/pimcore-setup` now installs missing prerequisites itself instead of printing commands: WSL2 and Docker Desktop on Windows (winget), Docker Engine on Linux (passwordless sudo), Docker Desktop on macOS (Homebrew). New scripts `install-prereqs.sh` and `install-prereqs.ps1`.
- The operating system's own consent steps (Windows administrator prompt, `sudo` password, restart) are still the user's: the plugin triggers them but never types, reads or bypasses them. After a Windows restart, run the same command again.
- New flag `--no-install` skips installing and lists the commands instead.
- Windows scripts are untested on a real Windows machine; please report problems as issues.

## 0.1.1

- `/pimcore-setup` now builds a local developer setup by default: admin login `admin` / `admin`, random database passwords, and every published port bound to `127.0.0.1`. If a port cannot bind to localhost, it falls back to a random login. Use `--secure-admin` for a random admin name and password. Never use the dev login on a server or shared host.
- `gen-secrets.sh` and `gen-secrets.ps1` gained `--dev-login` / `-DevLogin`.
- Autonomous mode is the default: the command decides with the recommended option and lists each choice under "Decisions made". `--ask` restores the prompts.
- `--plan` prints the installable Pimcore versions (PHP needed, product key, notes) and what happens in each situation, then stops.
- Product-key handling: a version that may need a key is never registered for and never bypassed; the row shows `unknown` unless confirmed.
- `detect-project.sh` falls back to the `pimcore/pimcore` PHP range when the skeleton has none.
- Agent handbacks must list "Commands run".

## 0.1.0

- First release: `/pimcore` and `/pimcore-setup`, 9 agents, 15 development modules, 8 setup modules.
