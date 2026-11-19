# Pimcore Engineering Toolkit

A Claude Code plugin for Pimcore projects. It is version-aware and has no ties to any one project. It gives you two commands:

- **`/pimcore <request>`**: the development entry point. It takes a request in plain language, detects the project's Pimcore, PHP and Symfony versions, reads the project's `CLAUDE.md`, starts only the specialist agents the task needs, validates the work and reports.
- **`/pimcore-setup [name] [flags]`**: sets up a Pimcore development environment on Linux, macOS, WSL2 or Windows. Docker is the default and native is optional. Credentials are generated and never printed, and it finishes with five health checks.

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

Run `/pimcore-setup --plan` to see which versions can be installed (with PHP needs and whether a product key is required) and what happens in each situation, without building anything. A normal run prints the same table, installs the recommended row and records the choice.

Useful `/pimcore-setup` options: `--plan`, `--ask`, `--secure-admin`, `--no-install`, `--runtime docker|native`, `--profile skeleton|demo`, `--version 11`, `--dir <path>`, `--check`, `--repair`.

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
```

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

## Skills and modules

Claude Code discovers skills only one level deep (`skills/<name>/SKILL.md`). The 23 skills are therefore module files inside two hidden skills, and each loads only when needed. All modules share one template: Purpose and scope (use when / do not use when), Inspect, Workflow, Best practices, Common mistakes, Version notes, Example, Validation checklist, Expected output.

**`pimcore-engineering`** (15 development modules): requirements-analysis, solution-planning, pimcore-architecture, backend-development, data-modelling, admin-ui-development, object-lifecycle, integration-development, data-import-export, performance-optimization, security-best-practices, testing-validation, code-review, upgrade-migration, deployment-release.

**`pimcore-environment`** (8 setup modules): environment-detection, docker-environment, native-environment, pimcore-installation, database-provisioning, environment-security, setup-validation, environment-troubleshooting.

### Agent to module mapping

| Agent | Preloaded skill | Main modules |
|---|---|---|
| solution-architect | pimcore-engineering | solution-planning, pimcore-architecture, requirements-analysis |
| developer | pimcore-engineering | backend-development, admin-ui-development, object-lifecycle, security-best-practices |
| data-modeler | pimcore-engineering | data-modelling, object-lifecycle, data-import-export |
| debugger | pimcore-engineering | object-lifecycle, performance-optimization, pimcore-architecture |
| integration-specialist | pimcore-engineering | integration-development, data-import-export, security-best-practices |
| code-reviewer | pimcore-engineering | code-review, security-best-practices, performance-optimization |
| qa-engineer | pimcore-engineering | testing-validation |
| upgrade-specialist | pimcore-engineering | upgrade-migration, deployment-release |
| environment-setup | pimcore-environment | all 8 setup modules |

## How orchestration works

1. `/pimcore` runs `detect-project.sh`. The script is read-only and reports the Pimcore, PHP and Symfony versions from `composer.lock`, plus Docker, the test tools and the project instruction files. The command then reads the project's `CLAUDE.md`, whose rules override the toolkit's.
2. It classifies the request with the routing table in `references/orchestration.md`. Questions are answered directly. Other requests get a workflow: A feature, B bug or performance, C data model, D integration, E review (E' tests only), F upgrade, G release.
3. The command coordinates the agents itself, because subagents cannot start other agents. It starts only the agents the task needs, in order, and passes each one the request, the version JSON, the module path and what earlier agents found.
4. Before any code changes, a checkpoint asks you first about class changes on existing data, destructive steps, new dependencies or open business questions. In other cases it shows a short plan and continues.
5. An independent reviewer checks code written in the run against the real `git diff`. Critical and high findings get at most two fix rounds.
6. Validation runs: tier 1 checks, tests, and container or route checks for configuration changes. The report lists every command and its result. Nothing is committed or pushed.

`/pimcore-setup` works the same way. It runs `detect-env` and plans, and decides on its own. It installs missing prerequisites itself (WSL2 and Docker Desktop through winget on Windows, Docker Engine on Linux with passwordless sudo, Docker Desktop through Homebrew on macOS). The only things it cannot do for you are the operating system's own consent steps: the Windows administrator prompt (one click for everything), a `sudo` password and a restart. Use `--no-install` to skip installing. The `pimcore-environment-setup` agent builds the environment. The command then runs `health-check` itself and reports.

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
  skills/pimcore/              /pimcore entry + scripts/detect-project.sh
  skills/pimcore-setup/        /pimcore-setup entry + scripts/{detect-env,gen-secrets,health-check}.{sh,ps1}
  skills/pimcore-engineering/  hidden, 15 modules
  skills/pimcore-environment/  hidden, 8 modules
  tests/test_structure.py      structure and style checks (python3, no dependencies)
  tests/scenarios.md           8 routing scenarios
```

## Tests

```bash
python3 tests/test_structure.py                 # frontmatter, mapping, modules, scripts, style
claude plugin validate /path/to/pimcore-toolkit # manifest
```

For the routing scenarios, see `tests/scenarios.md`.

## Limitations

- The 23 skills are modules inside two hidden skills, not 23 separate skills. Claude Code does not discover nested skills.
- The PowerShell scripts (`*.ps1`) have not been run on Windows yet. The bash scripts have been tested on Linux.
- The version notes in the modules cover Pimcore 10 and 11 in detail. Releases after 11 (Studio, licence changes) are flagged to be checked against the official documentation rather than written from memory.
- The quality of the agents depends on the project. A project with no tests or static analysis gets weaker validation, and the report says so.
- Future work: **`/pimcore-doctor`**, a read-only health and best-practice audit of an existing project. It would cover configuration, class definitions, workers, caches, indexes, security headers and deprecated API use, and would reuse `health-check` and the code-review module.

## Feedback and issues

- **Bug or problem:** open an issue at https://github.com/muhammed-rishanK/pimcore-toolkit/issues. Include the plugin version (see `CHANGELOG.md`), your OS, the Pimcore and PHP versions, the command you ran and what happened. Remove passwords, tokens and private project names first.
- **Idea or question:** open an issue and say it is a suggestion or a question.
- **Liked it?** A star on the repository helps others find it.

The plugin sends no usage data. This repository is the only place to reach the author.

## License

MIT, see `LICENSE`.
