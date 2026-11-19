# Solution planning

## Purpose and scope
Break an analysed requirement into an ordered, sized plan of work units that a developer, data modeler or QA engineer can pick up, with dependencies, risks, validation and rollback. Planning comes after requirements analysis and the design; it does not redo them.

**Use when:** the task is M or L, touches more than one area, needs a class change plus code, or will be split across agents.
**Do not use when:** the task is S and fits in one change; write the five-line plan from the orchestration guide instead.

## Inspect the project first
- The design or requirement output you were given.
- How the project ships changes: migrations directory, deploy scripts, CI config (`.gitlab-ci.yml`, `.github/workflows/`), `Makefile`, `composer.json` scripts.
- Test layout and commands (see `testing-validation.md`).
- Areas that must change together: class definition and the code that reads it, Messenger message and its handler, config and the service that consumes it.

## Workflow
1. **List the units of work**. Each unit has: goal, files or config it touches, owner (developer, data modeler spec, QA), size (S/M/L) and the acceptance criteria it covers.
2. **Order them** by dependency: data model first, then services, then UI and integrations, then tests that need all of it. Mark units that can run in parallel (no shared files, no dependency).
3. **One writer per file set.** Two units that touch the same file are one unit or run in sequence.
4. **Risks** per unit: data loss, regression in a shared service, performance under real volume, permission gaps, integration contract change. Give the mitigation for each.
5. **Validation per unit**: which checks prove it (unit test, functional test, command dry-run, manual admin check).
6. **Deployment steps**: migrations, `pimcore:deployment:classes-rebuild`, cache clear, worker restart, config or env changes, one-off data commands, and their order.
7. **Rollback**: how to undo each step (revert commit, down migration, restore definition file and rebuild, restore data from backup or export).
8. **Checkpoint**: name what needs the user's approval before work starts (see the orchestration guide's checkpoint rules).

## Best practices
- Prefer small, independently testable units over one large change.
- Put destructive or irreversible steps last and behind a dry-run.
- Keep the plan short enough to read in a minute; detail lives in the units.
- Estimate in size buckets, not hours, unless asked.

## Common mistakes
- Plans that skip deployment and rollback.
- Parallel units that both edit `services.yaml` or the same class definition.
- Treating "write tests" as a final unit instead of part of each unit.
- Forgetting the cache clear or class rebuild in the deploy steps, so the change works locally but not on the server.

## Version notes
Deploy commands differ by version: Pimcore 10 and 11 use Doctrine migrations (`doctrine:migrations:migrate`) and `pimcore:deployment:classes-rebuild`. Confirm with `bin/console list pimcore:deployment` and `bin/console list doctrine` in the project.

## Example
Feature "add a `warrantyMonths` field to Product, export it to the shop":
1. Data model (S): add `warrantyMonths` numeric field to Product definition. Spec by data modeler, applied by developer.
2. Export mapping (S): add the field to the shop export mapper. Depends on 1.
3. Tests (S): unit test for the mapper.
Deploy: definition file, `bin/console pimcore:deployment:classes-rebuild -c`, `bin/console cache:clear`, restart Messenger workers. Rollback: revert, rebuild, clear cache (the column stays, data is harmless).

## Validation checklist
- [ ] Every acceptance criterion is covered by a unit and a check.
- [ ] Dependencies and parallel units are explicit; no shared files across parallel units.
- [ ] Deploy and rollback steps are listed in order.
- [ ] Approval points are named.

## Expected output
Units table (goal, files, owner, size, criteria, depends on), risks with mitigations, validation per unit, deployment steps, rollback, approval points.
