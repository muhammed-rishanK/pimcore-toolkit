# Changelog

## 1.0.0

Pimcore 12, the 2025.4 LTS and Pimcore Studio are now covered. Facts come from the official docs and are listed with sources in `references/pimcore-versions.md`. Where the docs say nothing (licence and product key changes, the mapping of 12.x to 2025 tags), the toolkit says "not stated".

- New modules: `studio-ui-development` (React, Rsbuild, entry-point provider), `studio-backend-extension` (controllers, OpenAPI, events, grid tags, metadata adapters) and `platform-2026-upgrade` (breaking-change table, eight phases, targeted migration commands, rollback). Development modules: 15 to 18.
- New reference `references/pimcore-versions.md`: version matrix for 10.x, 11.x, 12.x, 2025.4 LTS and 2026.x, with sources.
- `detect-project.sh` now reports `releaseLine`, `yearBased`, `studioPackages` and `adminUi`, and adds notes for both UIs installed, the 2025.4 LTS, the 2026 PHP, Symfony and `--install-profile` requirements, and a host PHP below 8.4.
- `/pimcore` routes Studio features and platform upgrades to the new modules. `admin-ui-development` and `upgrade-migration` now separate classic UI work from Studio work.
- `/pimcore-setup` notes the `--install-profile` requirement and the PHP 8.4 or 8.5 need for 2026 lines, and never prints a support date the docs do not state.
- Agents (developer, solution-architect, upgrade-specialist) read the Studio and platform modules when the project needs them.
- Tests: functional checks run `detect-project.sh` against classic, Studio-beside-classic and 2026 fixtures.
- Not verified: the Studio JavaScript plugin registration API (the module points to the official example bundle), and the Windows and macOS setup routes on real machines.

## 0.1.7

- `/pimcore-setup` for an existing project now runs a post-install list inside the PHP container: `composer install`, `cache:clear`, `pimcore:cache:clear`, `classes-rebuild -c -n`, `assets:install`. The `-d` flag (delete classes) is skipped and reported unless you approve it.
- Migrations are no longer run in bulk. The toolkit lists pending ones and prints a targeted `doctrine:migrations:execute '<class>' --up --no-interaction` for each, with the real class name read from the file. It runs one only on your yes.
- `/pimcore` agents report that targeted command for every migration they create, instead of `doctrine:migrations:migrate`.

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
