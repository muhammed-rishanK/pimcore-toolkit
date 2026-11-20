---
name: pimcore-engineering
description: "Shared Pimcore engineering standards and the index of the 18 development modules (requirements, planning, architecture, backend, data modelling, admin UI, Studio UI, Studio backend, object lifecycle, integrations, import/export, performance, security, testing, code review, upgrades, 2026 platform upgrade, deployment). Version-aware for Pimcore 10, 11, 12, the 2025.4 LTS and the 2026 releases with Pimcore Studio. Preloaded by every pimcore-toolkit development agent."
user-invocable: false
---

# Pimcore engineering standards

These rules apply to every Pimcore agent and to the `/pimcore` orchestrator. Project instructions (the project's `CLAUDE.md`, `AGENTS.md`, `.claude/` rules, CONTRIBUTING) come first: when they conflict with anything here, the project wins.

Modules folder (`MODULES`): `${CLAUDE_SKILL_DIR}/modules`. If that path does not resolve, the orchestrator gives you the absolute path in your prompt. Read only the modules your task needs, in full, before you start.

## 1. Know the version before you write a line
- Read the project context the orchestrator passed you (output of `detect-project.sh`). If you have none, run it: `bash <toolkit>/skills/pimcore/scripts/detect-project.sh <project-root>`.
- The installed code is the reference, not memory and not the latest docs. The Pimcore version is in `composer.lock` (`pimcore/pimcore`), PHP in `composer.json` `require.php` and `config.platform.php`, Symfony in `symfony/framework-bundle` in `composer.lock`.
- Before you use any Pimcore or Symfony class, method, event constant, config key or console option, confirm it exists in `vendor/` for this version (`grep -rn "function methodName" vendor/pimcore/pimcore/`, `bin/console list pimcore`, `bin/console <cmd> --help`). Never invent an API. If you cannot verify it, say so.
- Official docs: use the page for the installed major version (`https://pimcore.com/docs/platform/Pimcore/` plus the version selector, and the upgrade notes for that version). Do not copy examples from a newer major without checking them against `vendor/`.

### Version landmarks (verify against the installed code)
| Area | Pimcore 10.x | Pimcore 11.x | 12.x | 2025.4 (LTS) | 2026.x |
|---|---|---|---|---|---|
| Symfony / PHP | Symfony 5.4, PHP 8.0 to 8.1 | Symfony 6.2+ (6.4 in later 11.x), PHP 8.1 to 8.3 | read `composer.lock` | Symfony 7 supported beside 6.4; PHP: read the system requirements page | Symfony 7.x only (7.3+), PHP 8.4 or 8.5 |
| Admin UI | inside core (`Pimcore\Bundle\AdminBundle`) | separate `pimcore/admin-ui-classic-bundle` | classic UI | classic UI, Studio can run beside it; last release with the classic UI | Pimcore Studio only (`pimcore/studio-ui-bundle`, `pimcore/studio-backend-bundle`) |
| Optional features | in core | many moved to their own bundles that must be installed and enabled | check `config/bundles.php` | check `config/bundles.php` | several bundles removed or moved into Studio (see `platform-2026-upgrade.md`) |
| Class definitions | `var/classes/definition_*.php` | same, plus custom layouts under `var/config/object_custom_layouts` | check the project tree | check the project tree | check the project tree |
| Installer | `pimcore-install` | `pimcore-install` | `pimcore-install` | `pimcore-install` | needs `--install-profile`; read `--help` |
| Licence | not stated here | not stated here | not stated here | not stated in the release blog | not stated in the release notes; read the licence of the exact version |

Year-based versions are `YYYY.N.patch`. Support dates, the LTS rule and sources are in `${CLAUDE_SKILL_DIR}/../../references/pimcore-versions.md`; read it before any recommendation that depends on the release line. Never call a release LTS or give a support date that this file or the official docs do not state.

When you give a version-specific recommendation, label it, for example "(Pimcore 11, verified in vendor/pimcore/pimcore/lib/...)".

## 2. Understand before implementing
- Read the requirement, then the existing code around it: the class definitions, the services, the event listeners and subscribers, the workflows and the config that touch the same objects.
- Search for an existing implementation first. Reuse and extend; do not build a second one.
- Find every consumer of what you change: PHP usages, YAML service config, Twig, admin JS, workflow config, DataHub configs, import and export mappings, message handlers.
- State assumptions plainly and list open questions. Do not guess business rules.

## 3. Respect the existing architecture
- Change only what the task needs. Note unrelated problems as follow-ups instead of fixing them.
- Follow the project's patterns: where services live, how they are wired (autowire, tags, attributes or YAML), naming, logging, error handling.
- Prefer Pimcore and Symfony built-ins (events, Messenger, workflows, DataHub, the data importer, permissions, validation) over custom frameworks. No new composer dependency without saying why and getting the user's agreement.
- Pimcore-generated code is not edited by hand: `var/classes/DataObject/*` and generated `Listing` classes come from the definitions.

## 4. Code standards
- PSR-12 plus the project's fixer or sniffer config (`.php-cs-fixer*.php`, `phpcs.xml*`, `ecs.php`). Run it on changed files if it is installed.
- Use the PHP features the project's minimum PHP supports: typed properties, return types, constructor promotion, readonly, enums and attributes only when the version allows and the codebase already uses them.
- Constructor dependency injection. No `\Pimcore::getContainer()->get()` or static service lookups in new code unless the surrounding code has no other option (some static Pimcore callbacks), and then say why.
- Business logic in services; controllers, commands and message handlers stay thin.
- Handle failures on purpose: catch what you can handle, log with context (object id, path, class), rethrow or report the rest. Never swallow exceptions.
- Comments explain why, not what. Plain English, no filler.

## 5. Testing is mandatory
After any change:
1. `php -l` on every changed PHP file (inside the PHP container when the project runs in Docker).
2. The project's code style tool on changed files, if installed.
3. Static analysis (`phpstan`, `psalm`) on changed paths if the project has it configured.
4. The relevant unit tests, then integration or functional tests where the project has them (Codeception or PHPUnit; detect which).
5. For config, class or DI changes: `bin/console cache:clear` and `bin/console debug:container <service>` or `lint:yaml` / `lint:container` where available, run in the environment where the app runs.
6. Report every command with its result. Never say a check passed if it did not run; say what could not be run and why.

## 6. Git and change management
- Never commit, push, create branches or open PRs/MRs unless the user asked for it in this conversation.
- Never touch unrelated files. Show the changed file list at the end so the user can review the diff.
- The developer does not approve their own work: review is done by `pimcore-code-reviewer` on the real diff.

## 7. Production and data safety
- Never run destructive SQL, `doctrine:schema:update --force`, class deletions, `pimcore:deployment:classes-rebuild -d` (deletes classes missing from definitions), bulk deletes or data migrations against shared, staging or production data without explicit approval.
- Do not use production data for tests. Use fixtures, a local copy, or objects created for the test (and say how to remove them).
- Never print, log or commit credentials. Secrets come from environment variables or the project's secret store.
- Risky changes come with a rollback note: how to undo the code, the class definition and the data.

## 8. Module index (read the ones the task needs)
| Module | Read it for |
|---|---|
| `requirements-analysis.md` | tickets, acceptance criteria, edge cases, impact |
| `solution-planning.md` | task breakdown, dependencies, risks, estimates |
| `pimcore-architecture.md` | bundles, kernel, services, DI, events, config layout |
| `backend-development.md` | controllers, services, commands, subscribers, repositories |
| `data-modelling.md` | classes, inheritance, relations, field collections, bricks, classification store, localized fields |
| `admin-ui-development.md` | classic admin JS, admin events, custom layouts, Studio vs classic |
| `studio-ui-development.md` | Pimcore Studio frontend plugins: React, Rsbuild, entry point provider |
| `studio-backend-extension.md` | Studio Backend endpoints, events, grid columns, metadata adapters, OpenAPI |
| `object-lifecycle.md` | create, save, publish, versions, events, workflows, permissions |
| `integration-development.md` | REST, ERP, eCommerce, auth, webhooks, sync, retries |
| `data-import-export.md` | CSV, Excel, XML, JSON, batches, SFTP, data importer |
| `performance-optimization.md` | listings, queries, caching, memory, Messenger |
| `security-best-practices.md` | authN, authZ, workspaces, input validation, SQL, secrets |
| `testing-validation.md` | Codeception, PHPUnit, functional tests, test data |
| `code-review.md` | diff review, severity, regression and security checks |
| `upgrade-migration.md` | version compatibility, deprecations, migrations, rollback |
| `platform-2026-upgrade.md` | moving to 2025.4 LTS or the 2026 releases: breaking changes, Classic UI to Studio |
| `deployment-release.md` | deploy steps, migrations, cache, release checks |

## 9. Writing style
Plain, direct English. No em-dashes. No filler or marketing words; say what the code does. Short sentences, file references as `path:line`.
