# Deployment and release

## Purpose and scope
Getting a Pimcore change safely from a branch to an environment: what to deploy, the commands to run and their order, class and config changes, migrations, caches, workers, release checks, and rollback.

**Use when:** preparing deploy notes for a change, writing a release runbook, checking a release, or diagnosing "works locally, not on the server".
**Do not use when:** setting up a new local environment (`/pimcore-setup`).

## Inspect the project first
- The deploy mechanism: CI pipelines, deploy scripts, Deployer or Ansible files, Docker images, `composer.json` scripts.
- Migrations directories and the migrations config.
- Which settings are stored as files in git (class definitions, custom layouts, DataHub configs, thumbnails, workflows) and which live in the database (classification store, users and roles, some settings, depending on config).
- Worker setup: supervisor or Docker service running `messenger:consume`, and how it restarts.
- Maintenance and cron jobs (`pimcore:maintenance` and project commands).

## Workflow
1. **Collect what changed**: code, config, class definitions, migrations, assets, env vars, composer dependencies, data steps.
2. **Order the steps** (typical, adapt to the project):
   1. maintenance mode if needed (`bin/console pimcore:maintenance-mode --enable`; in Pimcore 11 other console commands then need `--ignore-maintenance-mode`; verify for the installed version);
   2. `composer install --no-dev --optimize-autoloader` (or build the image);
   3. migrations: run only the versions this release adds, one by one: `bin/console doctrine:migrations:execute '<FQCN of the migration class>' --up --no-interaction` (read the class name from the file). Use `doctrine:migrations:migrate` only when the user wants every pending migration applied, after a database backup;
   4. `bin/console pimcore:deployment:classes-rebuild -c` (never `-d` unless deleting classes is intended and approved);
   5. one-off data commands, with dry-run first;
   6. `bin/console assets:install` with the project's flags;
   7. `bin/console cache:clear` and `bin/console pimcore:cache:clear`;
   8. `bin/console messenger:stop-workers` so workers restart with new code;
   9. disable maintenance mode.
3. **Database-stored config** (classification store, roles, some settings): ship it with a migration or an import command, or list the manual steps.
4. **Release checks**: smoke test admin login, open and save an object of each changed class, run the key import or export with dry-run, check logs and failed messages.
5. **Rollback plan**: previous release or image, down migrations (or the database backup taken before migrating), restore class definition files and rebuild, clear caches, restart workers.

## Best practices
- Back up the database before migrations in production.
- Make migrations and data commands safe to run twice.
- Keep env var changes in the release notes; never put values in the notes.
- Deploy class definitions and the code that uses them together.

## Common mistakes
- Forgetting to restart Messenger workers, so they run old code.
- Running `classes-rebuild -d` and dropping classes.
- Classification store changes made only in the development admin and never shipped.
- Clearing only the Symfony cache and not the Pimcore cache (or the reverse).

## Version notes
- Command names and options differ by version; confirm with `bin/console list pimcore`, `bin/console pimcore:deployment:classes-rebuild --help`.
- Pimcore 11 added configurable storage for several settings; check `pimcore.config_location` (or the equivalent in the installed version) before deciding what ships through git.

## Example deploy note
- Code: new subscriber and service.
- Class: Product gets `warrantyMonths` (definition file in git).
- Steps: migrate, `classes-rebuild -c`, `cache:clear`, `pimcore:cache:clear`, `messenger:stop-workers`.
- Env: new `SHOP_API_TIMEOUT` (value set by ops).
- Rollback: redeploy previous release, `classes-rebuild -c` restores the previous definition (the new column remains, harmless), clear caches, restart workers.

## Validation checklist
- [ ] All change types collected.
- [ ] Steps ordered; destructive steps called out.
- [ ] Database-stored config handled.
- [ ] Release checks and rollback written.

## Expected output
Deploy steps in order with commands, env var names (no values), database-stored config steps, release checks, rollback.
