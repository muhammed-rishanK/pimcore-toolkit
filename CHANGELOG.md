# Changelog

## 1.1.2

Found by running the scan on a real project (a Pimcore 11 PIM with six git worktrees):

- Fixed: the scan now skips `.claude/worktrees/`. Git worktrees hold full copies of the project, so each match was counted once per copy. On that project the totals fell from 2324 matches in 494 files to 390 in 121, and the 200-match cap per rule is no longer filled with duplicates.
- Fixed: `ecommerce-tracking` is now `heuristic`, not `documented`. It matches the generic name `formatPrice(`, which a project's own code can define.
- Test: a fixture file under `.claude/worktrees/` must not be matched.
- Still true: matches marked `heuristic` are leads. The scan reports no deprecated PHP calls.

## 1.1.1

- Added `package.json` and a GitHub Actions workflow (`.github/workflows/publish-package.yml`) that publishes the plugin files to GitHub Packages as `@muhammed-rishank/pimcore-toolkit` when a release is published. The workflow uses the built-in `GITHUB_TOKEN`, checks that the release tag matches the `package.json` version, and runs the structure tests first.
- The Claude Code install is unchanged: install from the marketplace as before. The package is an extra download of the same files.

## 1.1.0

- New read-only impact scan, `skills/pimcore/scripts/scan-platform-impact.sh <project> [--to 12|2024|2025|2026] [--format table|json]`. For each documented breaking-change item it lists every matching `file:line` in the project, marks each rule `documented` or `heuristic`, links the official source, and names the rules that did not match. It skips `vendor/`, `var/`, `node_modules/` and `.git/` and never changes anything.
- The rules are data in `skills/pimcore/scripts/platform-impact-rules.json`, so a new breaking change is a new entry, not a script edit. 59 rules in three cumulative steps: `2024` (7, deprecations in 11.5 and 2024.x), `2025` (35, Pimcore 12 and 2025.x, including the licence and bundle-split items) and `2026` (17, Studio-only platform). `--to 12` is an alias for `2025`.
- Bundle rules use Packagist names that were checked (admin-ui-classic-bundle, advanced-object-search, newsletter-bundle, web-to-print-bundle, studio-ui-bundle and others). Bundles whose name could not be confirmed are matched by namespace and marked `heuristic`.
- `references/pimcore-versions.md` now records the platform to core mapping (2024.4 = 11.5.x, 2025.1 to 2025.4 = 12.0 to 12.3) and the 2024.4 LTS date (December 2026). Sources: Packagist conflict ranges and the docs Platform Versions, Upgrade Notes and "Version 11 to Version 12" pages, checked 2026-11-20.
- Fixed: running the scanner with a relative script path failed with "platform-impact-rules.json missing". The script directory is now resolved before changing into the project.
- The upgrade specialist, `platform-2026-upgrade.md` and Workflow F in `references/orchestration.md` now start from the scan instead of ad-hoc grepping.
- Limits, stated in the script output: only items in the rules file are checked, and the scan is not a PHP deprecation report (use PHPStan deprecation rules or the Symfony deprecation log for deprecated calls). The 2024.x, 2025.x and 11 to 12 items were read from fetched summaries of the official pages, and the per-bundle upgrade notes were not read, so confirm identifiers against `vendor/` or the linked page.
- Tests: rules file validation and fixture projects (matching, clean, bad argument, `vendor/` skipped).

## 1.0.1

- Fixed the Pimcore 12 install command. `pimcore/skeleton` has no `12` tag, so `--version 12` finds nothing. Pimcore 12 is installed with `--version 2025.4` (skeleton 2025.4 requires `pimcore/pimcore ^12.3` and the Classic UI); `--version 2026` installs Studio only. Source: Packagist metadata, checked 2026-11-20.
- `references/pimcore-versions.md` now records the 12.x to 2025.x mapping and the PHP range (8.3 or 8.4) for 12.x and 2025.4.
- `/pimcore-setup` shows the `pimcore/pimcore` line each skeleton release requires, and stops with the list of real skeleton lines when `--version` matches none, instead of guessing.

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
