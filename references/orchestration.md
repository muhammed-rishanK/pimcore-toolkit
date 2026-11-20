# Orchestration rules for /pimcore

## 1. Principles
- **Least delegation.** Use an agent only when it adds something: a fresh context for a large read, a specialist method (debugging, data modelling, upgrade analysis), or an independent check (review). Answer questions and explain code yourself.
- **Agents cannot start agents.** You run the sequence. When an agent says it needs another specialist (for example the environment agent needs a version decision from the upgrade specialist), you start that specialist and pass the result back.
- **Independent review.** Code written in this run is reviewed by `pimcore-code-reviewer`, which reads the real `git diff` against the original request. The developer never signs off its own work.
- **One writer per file set.** Never run two writing agents on the same files at the same time. Read-only agents may run in parallel.
- **Context for every agent.** Each prompt carries: the user's request verbatim, the `detect-project.sh` JSON, the absolute `MODULES` path, the modules to read, the project instruction files to respect, what earlier agents produced (summarised, with file references), and what to return.
- **Pipelines in the project win.** If the project's instruction files describe a delivery pipeline of their own and the request is to deliver a whole ticket to a merge request, tell the user in one line that the project pipeline exists and let them choose. Do not start it yourself.

## 2. Routing table
| Request looks like | Type | Workflow | Modules | Agents (in order, skip what is not needed) |
|---|---|---|---|---|
| "explain how X works", "where is Y", a quick API question | Explain | none | `pimcore-architecture` + the area module | none, answer directly |
| "analyse this ticket", acceptance criteria, impact | Analysis | A (stops after analysis) | `requirements-analysis`, `solution-planning` | none for a small ticket; `pimcore-solution-architect` when it spans several areas |
| "design", "architecture", "how should we build" | Architecture | A (stops after design) | `pimcore-architecture`, `solution-planning` + area | `pimcore-solution-architect` (+ `pimcore-data-modeler` if classes change) |
| new feature, "implement", "create a service/command/endpoint" | Feature | A | `requirements-analysis`, `backend-development` + area | architect (only if M or larger), `pimcore-developer`, `pimcore-qa-engineer`, `pimcore-code-reviewer` |
| new or changed class, field collection, brick, classification store, relations | Data model | C | `data-modelling`, `object-lifecycle` | `pimcore-data-modeler`, architect if cross-cutting, developer, QA, reviewer |
| error, exception, "not saving", "slow", regression, production issue | Bug | B | `object-lifecycle` + area, `performance-optimization` if slow | `pimcore-debugger`, architect only for design-level causes, developer, QA, reviewer |
| ERP, eCommerce, REST, webhook, queue, SFTP, DataHub, import/export pipeline | Integration | D | `integration-development`, `data-import-export`, `security-best-practices` | `pimcore-integration-specialist`, architect if a new pattern, developer, QA, reviewer |
| "optimise", memory, timeouts, large exports | Performance | B (measure first) | `performance-optimization` + area | `pimcore-debugger` (measures and finds the cause), developer, QA, reviewer |
| "review my changes", "review this diff/PR" | Review | E | `code-review`, `security-best-practices` | `pimcore-code-reviewer`, QA only if the reviewer asks for runtime proof |
| "write tests", "test this" | Testing | E' | `testing-validation` | `pimcore-qa-engineer` |
| "upgrade", "compatibility", "deprecations" | Upgrade | F | `upgrade-migration`, `deployment-release` | `pimcore-upgrade-specialist`, architect for the plan, then developer, QA, reviewer only if the user asks to execute |
| "upgrade to 2025.4", "LTS", "2026", "Pimcore 12", "move to Studio", "remove the classic UI" | Platform upgrade | F | `platform-2026-upgrade`, `upgrade-migration`, `studio-ui-development`, `studio-backend-extension` | `pimcore-upgrade-specialist` (reads `references/pimcore-versions.md`), architect for the phases and the Classic UI rewrite list, then developer, QA, reviewer only if the user asks to execute |
| Studio plugin, Studio panel, Studio grid column, Studio API endpoint (project `adminUi` is `studio` or `both`) | Studio feature | A | `studio-ui-development`, `studio-backend-extension`, `backend-development` | architect (only if M or larger), `pimcore-developer`, `pimcore-qa-engineer`, `pimcore-code-reviewer` |
| "prepare release", "deployment checklist" | Release | G | `deployment-release` | none, or `pimcore-code-reviewer` for a final diff check |
| environment, install, Docker, "set up Pimcore" | Setup | none | none | tell the user to run `/pimcore-setup`; for a broken existing project, run `/pimcore-setup --repair` |

Sizing: S = one or two files in one area, no class or config change. M = several files or one class/config change. L = several areas, new integration, or data migration. S work skips the architect. L work always gets the architect.

## 3. Workflows
Agent names are `pimcore-toolkit:<agent>`.

**A. New feature.** (1) Requirement analysis: do it yourself with `requirements-analysis`; list ambiguities. (2) `pimcore-solution-architect` for M/L: design, affected files, phases, test plan. (3) Checkpoint (below). (4) `pimcore-developer` implements and runs tier 1 checks. (5) `pimcore-qa-engineer` writes and runs tests for the acceptance criteria and regressions. (6) `pimcore-code-reviewer` reviews the diff against the request. (7) Fix round: findings marked critical or high go back to the developer, then QA and review run again on the changed part. At most two rounds, then report what is left.

**B. Bug or performance.** (1) `pimcore-debugger`: reproduce, root cause, smallest safe fix proposal, read-only. (2) Architect only if the cause is a design problem. (3) Checkpoint. (4) Developer applies the fix. (5) QA adds a regression test that fails before and passes after, when possible. (6) Reviewer.

**C. Data modelling.** (1) `pimcore-data-modeler`: current model, proposed change, data impact, migration and rollback. (2) Architect if other systems or many classes are affected. (3) Checkpoint (class changes are always confirmed). (4) Developer applies the definition changes the project's way (admin UI export, definition file, or migration) and any code. (5) QA. (6) Reviewer.

**D. Integration.** (1) `pimcore-integration-specialist`: systems, source of truth per field, mapping, idempotency, failure handling, volumes, security. (2) Architect if it introduces a new pattern. (3) Checkpoint. (4) Developer. (5) QA with stubs or sandboxes, never live third-party writes. (6) Reviewer.

**E. Code review.** `pimcore-code-reviewer` on the diff the user named (default: `git diff` plus staged plus untracked files against the current branch base). Start QA only when a finding needs runtime proof. **E'** is the testing-only variant: `pimcore-qa-engineer` alone.

**F. Upgrade.** (1) `pimcore-upgrade-specialist`: current versions, target, breaking changes, dependency and bundle compatibility, plan, rollback. For 2025.4 or 2026 targets it reads `platform-2026-upgrade.md` and `references/pimcore-versions.md`, and the project's `adminUi`, `releaseLine` and `notes` from `detect-project.sh`. It also runs `scripts/scan-platform-impact.sh <project> --to <12|2024|2025|2026> --format json` (read-only) and builds the breaking-change list from its findings, one file list per item, instead of grepping by hand. (2) Architect turns it into phases. (3) Stop and report. Executing a major upgrade needs the user's explicit go-ahead in this conversation; then developer, QA and reviewer phase by phase.

**G. Release.** Use `deployment-release`: produce the deployment checklist from the diff (migrations, class rebuilds, cache, workers, config, rollback).

### Checkpoint before code changes
- If the user asked only for analysis, design, a review or a plan: stop after that step and report.
- If the user asked for implementation: show a five-line plan (approach, files, risks, tests) and continue without waiting. The default is to decide, not ask. For an open business question, more than one reasonable design, a class definition change on existing data, a destructive data step, a new composer dependency or work outside the stated scope, take the recommended and safest option (the additive class change, no destructive step, no new dependency unless required, stay inside the stated scope), and list it under "Decisions made" in the final report with the alternative you did not take. Destructive data steps are never run; they are listed as not done. Pass `--ask` in the request to be asked at these points instead.

## 4. Validation (before reporting done)
- The developer reports tier 1 (`php -l`, style tool, static analysis on changed paths, unit tests for the area).
- QA reports the acceptance criteria tests and regression tests it ran, with results.
- For DI, config, routing or class changes: cache clear and a container or route check in the environment where the app runs (Docker: `docker compose exec <php service> bin/console ...`). If the agent cannot run it (no access to the container, no database), it says so and gives the exact command for the user.
- Review findings rated critical or high are fixed or explicitly accepted by the user.
- The final report lists every command run and its result, and every check that could not run.

## 5. What an agent returns
Each agent ends with a short handback: status (done, blocked, needs decision), the key result in a few lines, files changed or files examined, commands run with results, open questions with a recommendation. "Commands run" is mandatory: list each command with its result, or write "none" for a read-only agent that ran nothing. If a handback omits it, ask the agent for it before you report. Long material (full design, full review) stays in the agent's answer; you summarise it for the user.
