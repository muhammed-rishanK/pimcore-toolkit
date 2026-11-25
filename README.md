# Pimcore Engineering Toolkit

A Claude Code plugin for Pimcore projects. It is version-aware and has no ties to any one project. It gives you four commands:

- **`/pimcore <request>`**: the development entry point. It takes a request in plain language, detects the project's Pimcore, PHP and Symfony versions, reads the project's `CLAUDE.md`, starts only the specialist agents the task needs, validates the work and reports.
- **`/pimcore-setup [name] [flags]`**: sets up a Pimcore development environment on Linux, macOS, WSL2 or Windows. Docker is the default and native is optional. Credentials are generated and never printed, and it finishes with five health checks.
- **`/pimcore-review [--all | --staged | --base <branch>]`**: code review of your changes and everything they affect, or of the whole codebase with `--all`. Each finding shows the file and line, the lines of code that cause it, why it is a problem, the fix and a test plan. It also runs on its own after Claude changes code (see "Automatic review").
- **`/pimcore-doctor [<folder>] [--online]`**: a read-only health and best-practice audit of an existing project, with pass, warn or fail per check and the fix for each.

## Install

In Claude Code:

```text
/plugin marketplace add muhammed-rishanK/pimcore-toolkit
/plugin install pimcore-toolkit@pimcore-toolkit
```

Or from a terminal:

```bash
claude plugin marketplace add muhammed-rishanK/pimcore-toolkit
claude plugin install pimcore-toolkit@pimcore-toolkit
```

To try a local copy for one session: `claude --plugin-dir /path/to/pimcore-toolkit`.

Update to the latest version:

```bash
claude plugin marketplace update pimcore-toolkit
claude plugin update pimcore-toolkit@pimcore-toolkit
```

Then run `/reload-plugins`. See `CHANGELOG.md` for what changed.

### Automatic updates

Claude Code can update the plugin by itself whenever a new version is published. For plugins outside the official marketplace this is off by default and only you can turn it on (the author cannot do it for you). Turn it on once, either way:

- In Claude Code: `/plugin`, then Marketplaces, `pimcore-toolkit`, Enable auto-update.
- From a terminal, with the helper shipped in the plugin:

```bash
bash ~/.claude/plugins/marketplaces/pimcore-toolkit/skills/pimcore/scripts/enable-auto-update.sh          # turn on
bash ~/.claude/plugins/marketplaces/pimcore-toolkit/skills/pimcore/scripts/enable-auto-update.sh --check  # show the status
bash ~/.claude/plugins/marketplaces/pimcore-toolkit/skills/pimcore/scripts/enable-auto-update.sh --off    # turn off
```

The helper sets `extraKnownMarketplaces.pimcore-toolkit.autoUpdate` to `true` in `~/.claude/settings.json` and keeps a backup of the old file next to it. Claude Code then checks for a new version at startup and applies it after `/reload-plugins` or the next start.

If `DISABLE_AUTOUPDATER`, `DISABLE_UPDATES` or `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC` is set in your environment (some desktop and managed setups set one), updates are blocked. Set `FORCE_AUTOUPDATE_PLUGINS=1` to keep plugin updates on anyway. `--check` reports when one of them is set. `/pimcore-doctor` also reports the status.

Every release raises the version in `.claude-plugin/plugin.json`, which is what Claude Code compares.

Type `/pimcore` or `/pimcore-setup` to check that the commands are available.

## Quick start

Your first command depends on where you start.

**You have no Pimcore project yet.** Open an empty folder in Claude Code and run:

```text
/pimcore-setup my-shop
```

It detects your OS and installed tools, shows a plan and asks before anything risky. It then creates the project, generates secrets (never printed), starts the services, installs Pimcore and runs five health checks. The final report lists the URLs, the admin username and the command that reads the password.

**You already have a Pimcore project.** Run this inside the project. It changes nothing and reports what is healthy and what is broken:

```text
/pimcore-setup --check
```

If something is broken, `/pimcore-setup --repair` diagnoses it and applies each fix only after you approve it.

**Once the environment is healthy**, develop with `/pimcore`:

```text
/pimcore explain how Product objects get their prices
```

For Pimcore 12 use `--version 2025.4` (the skeleton has no `12` tag; 2025.4 installs `pimcore/pimcore ^12.3` with the Classic UI, and `--version 2026` installs Studio only).

Run `/pimcore-setup --plan` to see which versions can be installed (with PHP needs and whether a product key is required) and what happens in each situation, without building anything. A normal run prints the same table, installs the recommended row and records the choice.

Useful `/pimcore-setup` options: `--plan`, `--ask`, `--secure-admin`, `--no-install`, `--runtime docker|native`, `--profile skeleton|demo`, `--version 11` or `--version 2025.4`, `--dir <path>`, `--check`, `--repair`.

## Usage examples

```text
/pimcore explain how Product objects get their prices
/pimcore JIRA-12: add a read-only lastSyncedAt date on the Product edit page
/pimcore design a Supplier class with contacts, addresses and a relation to Product
/pimcore saving a Product fails with "Integrity constraint violation"
/pimcore integrate the ERP price REST API into Product objects
/pimcore review my current changes
/pimcore write PHPUnit tests for ProductPriceCalculator
/pimcore plan an upgrade from Pimcore 10.6 to 11
/pimcore --route <request>          # show the routing decision only, change nothing

/pimcore-setup acme-pim                         # Docker, skeleton profile, newest stable
/pimcore-setup acme-demo --profile demo
/pimcore-setup acme-pim --runtime native --version 11
/pimcore-setup --dir ./existing-project         # existing profile is picked automatically
/pimcore-setup --check --dir ./acme-pim         # health checks only
/pimcore-setup --repair --dir ./acme-pim        # diagnose and fix a broken environment

/pimcore-review                                 # uncommitted changes and what they affect
/pimcore-review --base production               # everything since the branch left production
/pimcore-review --all --focus security          # whole codebase, security first
/pimcore-doctor                                 # audit the current project, change nothing
/pimcore-doctor ./acme-pim --online             # also check composer advisories
```

## Automatic review

After Claude changes code in a Pimcore project (a git repository with `pimcore/pimcore` in `composer.json`), the plugin's Stop hook asks Claude to run `/pimcore-review` on the changes before it finishes. It only reacts to code files (PHP, Twig, YAML, XML, JS, TS, SQL), runs once per new set of changes and never loops. The review reads the code and changes nothing; you decide what to fix.

Turn it off everywhere with `PIMCORE_AUTO_REVIEW=0` in your environment, or for one project:

```bash
git config pimcore.autoReview false
```

The hook writes one small state file inside `.git` and nothing else. Outside Pimcore projects it does nothing.

## Agents

| Agent | Model | Writes code | Role |
|---|---|---|---|
| `pimcore-solution-architect` | opus | no | design, impact, phases, test plan |
| `pimcore-developer` | sonnet | yes | implementation and tier 1 checks |
| `pimcore-data-modeler` | opus | no | classes, field collections, bricks, classification store, data migration plans |
| `pimcore-debugger` | opus | no | reproduce, root cause, smallest safe fix |
| `pimcore-integration-specialist` | opus | no | ERP, eCommerce, REST, queues, DataHub, import and export design |
| `pimcore-code-reviewer` | opus | no | independent review of the real diff against the request |
| `pimcore-qa-engineer` | sonnet | tests only | PHPUnit and Codeception tests, acceptance and regression checks |
| `pimcore-upgrade-specialist` | opus | no | version analysis, breaking changes, upgrade plan |
| `pimcore-environment-setup` | sonnet | yes (new environment only) | runs the build steps of `/pimcore-setup` |

## Supported Pimcore lines

| Line | Admin UI | Notes (from the official docs, see `references/pimcore-versions.md`) |
|---|---|---|
| 10.x | classic, inside core | Symfony 5.4 |
| 11.x | classic, separate bundle | Symfony 6.2+, many features moved to bundles |
| 12.x | classic, Studio can run beside it | last numbered line; installed with skeleton `2025.x` (2025.4 requires `pimcore/pimcore ^12.3`) |
| 2025.4 (LTS) | classic, Studio compatible | three years from the 2025-12-09 release, platform only; last release with the classic UI |
| 2026.x | Studio only | PHP 8.4 or 8.5, Symfony 7.x, `pimcore-install --install-profile` |

`detect-project.sh` reports `releaseLine`, `yearBased` and `adminUi` (core, both, studio, classic or unknown), so agents pick the right modules without guessing. For a move to 2025.4 or 2026 the `platform-2026-upgrade` module gives a phased plan with targeted migration commands and a rollback.

## Upgrade impact scan

For an upgrade plan (for example 2024 to 2026) the upgrade specialist starts from a repeatable, read-only scan instead of ad-hoc grepping:

```bash
bash skills/pimcore/scripts/scan-platform-impact.sh <project-root> --to 2026          # table
bash skills/pimcore/scripts/scan-platform-impact.sh <project-root> --to 12 --format json
```

`--to` picks how far the plan goes: `2024` (deprecations in 11.5 and 2024.x), `2025` or `12` (Pimcore 12 and 2025.x, `12` is an alias), `2026` (2026.x, default). Steps are cumulative, so `--to 2026` also runs the earlier rules.

For each documented breaking-change item the scan lists every matching `file:line`, says whether the rule is `documented` or `heuristic`, links the official page and names the rules that did not match. There are 59 rules: 7 for the 2024 step, 35 for the 2025 step and 17 for the 2026 step. It skips `vendor/`, `var/`, `node_modules/` and `.git/`, and it changes nothing. The rules are data in `skills/pimcore/scripts/platform-impact-rules.json`, so a new breaking change is a new entry.

It does not replace a PHP deprecation report. Add PHPStan deprecation rules or the Symfony deprecation log for deprecated calls the rules do not list.

## Skills and modules

Claude Code discovers skills only one level deep (`skills/<name>/SKILL.md`). The 26 skills are therefore module files inside two hidden skills, and each loads only when needed. All modules share one template: Purpose and scope (use when / do not use when), Inspect, Workflow, Best practices, Common mistakes, Version notes, Example, Validation checklist, Expected output.

**`pimcore-engineering`** (18 development modules): requirements-analysis, solution-planning, pimcore-architecture, backend-development, data-modelling, admin-ui-development, studio-ui-development, studio-backend-extension, object-lifecycle, integration-development, data-import-export, performance-optimization, security-best-practices, testing-validation, code-review, upgrade-migration, platform-2026-upgrade, deployment-release.

**`pimcore-environment`** (8 setup modules): environment-detection, docker-environment, native-environment, pimcore-installation, database-provisioning, environment-security, setup-validation, environment-troubleshooting.

### Agent to module mapping

| Agent | Preloaded skill | Main modules |
|---|---|---|
| solution-architect | pimcore-engineering | solution-planning, pimcore-architecture, requirements-analysis, studio modules and platform-2026-upgrade when relevant |
| developer | pimcore-engineering | backend-development, admin-ui-development, studio-ui-development, studio-backend-extension, object-lifecycle, security-best-practices |
| data-modeler | pimcore-engineering | data-modelling, object-lifecycle, data-import-export |
| debugger | pimcore-engineering | object-lifecycle, performance-optimization, pimcore-architecture |
| integration-specialist | pimcore-engineering | integration-development, data-import-export, security-best-practices |
| code-reviewer | pimcore-engineering | code-review, security-best-practices, performance-optimization |
| qa-engineer | pimcore-engineering | testing-validation |
| upgrade-specialist | pimcore-engineering | upgrade-migration, platform-2026-upgrade, deployment-release |
| environment-setup | pimcore-environment | all 8 setup modules |

## How orchestration works

1. `/pimcore` runs `detect-project.sh`. The script is read-only and reports the Pimcore, PHP and Symfony versions from `composer.lock`, plus Docker, the test tools and the project instruction files. The command then reads the project's `CLAUDE.md`, whose rules override the toolkit's.
2. It classifies the request with the routing table in `references/orchestration.md`. Questions are answered directly. Other requests get a workflow: A feature, B bug or performance, C data model, D integration, E review (E' tests only), F upgrade, G release.
3. The command coordinates the agents itself, because subagents cannot start other agents. It starts only the agents the task needs, in order, and passes each one the request, the version JSON, the module path and what earlier agents found.
4. Before any code changes, a checkpoint asks you first about class changes on existing data, destructive steps, new dependencies or open business questions. In other cases it shows a short plan and continues.
5. An independent reviewer checks code written in the run against the real `git diff`. Critical and high findings get at most two fix rounds.
6. Validation runs: tier 1 checks, tests, and container or route checks for configuration changes. The report lists every command and its result. Nothing is committed or pushed.

`/pimcore-setup` works the same way. It runs `detect-env` and plans, and decides on its own. It installs missing prerequisites itself (WSL2 with Docker Engine inside it on Windows, Docker Engine on Linux with passwordless sudo, and Colima on macOS; all free, Docker Desktop is never installed). The only things it cannot do for you are the operating system's own consent steps: the Windows administrator prompt (only when WSL must be enabled), a `sudo` password and a restart. For the `sudo` password it opens the command in a terminal tab where you type it, then carries on. After Docker is installed it runs Docker through `sg docker`, so no logout is needed. On Windows it runs the scripts inside WSL itself. Use `--no-install` to skip installing. The `pimcore-environment-setup` agent builds the environment. The command then runs `health-check` itself and reports.

### Setup security

- By default `/pimcore-setup` builds a local developer setup: the admin login is `admin` / `admin`, the database passwords are random, and every published port is bound to `127.0.0.1` so nothing is reachable from the network. Use `--secure-admin` for a random admin name and password, and never use the dev login on a server or shared host. Otherwise `gen-secrets` creates random credentials with a random admin suffix. They are written to `.pimcore-setup/secrets.env` with mode 600, and the compose credentials go to `docker-compose.override.yaml` with mode 600. Both files are git-ignored, and existing files are never overwritten.
- The installer reads the secrets from stdin, so they never appear in command lines, logs or the report. You read the admin login yourself with `grep ADMIN .pimcore-setup/secrets.env`.
- The five health checks: installation completed, database initialised (tables and an admin user), application healthy, admin login reachable, optional services (workers, Redis, search).

## Directory tree

```text
pimcore-toolkit/
  .claude-plugin/plugin.json, marketplace.json
  agents/                      9 agents
  references/orchestration.md  routing table, workflows, validation rules
  references/output-formats.md report formats (routing, feature, bug, review, plan, setup)
  references/pimcore-versions.md version matrix 10 to 2026, LTS, Studio, sources
  hooks/hooks.json, auto-review.sh  automatic review after code changes
  skills/pimcore/              /pimcore entry + scripts/{detect-project,scan-platform-impact,enable-auto-update}.sh + platform-impact-rules.json
  skills/pimcore-setup/        /pimcore-setup entry + scripts/{detect-env,gen-secrets,health-check,install-prereqs}.{sh,ps1}
  skills/pimcore-review/       /pimcore-review entry + scripts/review-scope.sh
  skills/pimcore-doctor/       /pimcore-doctor entry + scripts/doctor.sh
  skills/pimcore-engineering/  hidden, 18 modules
  skills/pimcore-environment/  hidden, 8 modules
  tests/test_structure.py      structure and style checks (python3, no dependencies)
  tests/scenarios.md           8 routing scenarios
  GUIDE.md                     step-by-step user guide
```

## Tests

```bash
python3 tests/test_structure.py                 # frontmatter, mapping, modules, scripts, style
claude plugin validate /path/to/pimcore-toolkit # manifest
```

For the routing scenarios, see `tests/scenarios.md`.

## Limitations

- The 26 skills are modules inside two hidden skills, not 26 separate skills. Claude Code does not discover nested skills.
- The PowerShell scripts (`*.ps1`) have not been run on Windows yet. The bash scripts have been tested on Linux.
- Version coverage: Pimcore 10, 11, 12.x, the 2025.4 LTS and the 2026 releases, taken from the official docs and listed with sources in `references/pimcore-versions.md`. Anything the docs do not state (licence and product key changes) is written as "not stated", and the toolkit tells you to read `composer.lock` and the official page.
- Studio support: the Studio UI and Studio Backend modules cover what the official docs describe (React, Rsbuild, entry-point provider, backend controllers, events, grid tags). The JavaScript plugin registration API was not in the pages the modules are based on, so the module tells you to copy the official example bundle and read the installed package.
- The upgrade impact scan only checks the items in its rules file, and `heuristic` matches (for example bundles matched by namespace because their Packagist name could not be confirmed) are leads, not proof. The 2024.x, 2025.x and 11 to 12 items were read from fetched summaries of the official upgrade notes, so check identifiers against `vendor/` or the linked page. The per-bundle upgrade notes (Data Importer, Data Hub, Generic Data Index and others) were not read.
- The quality of the agents depends on the project. A project with no tests or static analysis gets weaker validation, and the report says so.
- `/pimcore-doctor` checks what can be read from files and git. It does not open the admin, measure performance or check security headers on a running site.
- The automatic review needs `git`. Changes outside a git repository are not reviewed automatically; run `/pimcore-review` by hand.

## Feedback and issues

- **Bug or problem:** open an issue at https://github.com/muhammed-rishanK/pimcore-toolkit/issues. Include the plugin version (see `CHANGELOG.md`), your OS, the Pimcore and PHP versions, the command you ran and what happened. Remove passwords, tokens and private project names first.
- **Idea or question:** open an issue and say it is a suggestion or a question.
- **Liked it?** A star on the repository helps others find it.

The plugin sends no usage data. This repository is the only place to reach the author.

## License

MIT, see `LICENSE`.
