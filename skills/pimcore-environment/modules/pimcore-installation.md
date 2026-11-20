# Pimcore installation

## Purpose and scope
Choose the package and version, create the project, and run the Pimcore installer non-interactively with generated credentials. Covers the skeleton profile (empty project), the demo profile (sample data), and the existing-project profile (set up an existing codebase).

**Use when:** after the runtime is ready (Docker containers running, or native PHP and database ready).
**Do not use when:** the project is already installed and healthy; run validation instead.

## Inspect
- The version request (`--version`). If absent, list the available versions of the package (`composer show -a pimcore/skeleton` in a throwaway container or on the host, or the Packagist metadata) and pick the newest stable release of the newest major the official docs list as supported. Ask `pimcore-upgrade-specialist` (through the orchestrator) when PHP, image or licence questions are not obvious.
- The licence of the chosen version (see the safety rules).
- Whether the installer asks for a product key (`pimcore-install --help`, release notes). If it does, follow the Licences rule in `SKILL.md`: pick a version that needs no key, or finish the other steps and report the registration link under "Needs you". Never pass a skip flag for registration.
- `vendor/bin/pimcore-install --help` in the created project: the options and the `PIMCORE_INSTALL_*` env vars it reads. Pimcore 11 reads, among others, `PIMCORE_INSTALL_ADMIN_USERNAME`, `PIMCORE_INSTALL_ADMIN_PASSWORD`, `PIMCORE_INSTALL_MYSQL_HOST_SOCKET`, `PIMCORE_INSTALL_MYSQL_USERNAME`, `PIMCORE_INSTALL_MYSQL_PASSWORD`, `PIMCORE_INSTALL_MYSQL_DATABASE`, `PIMCORE_INSTALL_MYSQL_PORT` and `PIMCORE_INSTALL_INSTALL_BUNDLES`. Confirm with `--help` for the installed version.

## Workflow
1. **Profile and package**:
   | Profile | Package | Notes |
   |---|---|---|
   | skeleton (default) | `pimcore/skeleton` | empty project |
   | demo | `pimcore/demo` | sample classes, data and assets; larger download; the demo may ship its own install steps; read its README |
   | existing | none | the codebase exists; run `composer install`, then install against a new empty DB or import the team's dump |
2. **Create** the project (`docker-environment.md` or `native-environment.md`).
3. **Secrets**: `gen-secrets.sh` has written `.pimcore-setup/secrets.env` with `PIMCORE_INSTALL_*` keys. Never print it.
4. **Install** with the secrets passed on stdin so they never appear on a command line or in the process list:
   - Docker: `docker compose exec -T php sh -c 'set -a; . /dev/stdin; set +a; exec vendor/bin/pimcore-install --no-interaction' < .pimcore-setup/secrets.env`
   - Native: `( set -a; . .pimcore-setup/secrets.env; set +a; exec vendor/bin/pimcore-install --no-interaction )`
   Add `--install-bundles=<list>` only for bundles the user wants (the installer lists installable bundles in `--help`).
5. **Database config**: the installer writes `config/local/database.yaml` with the DB password. Confirm `config/local/` is git-ignored (add it to `.gitignore` if not).
6. **Post-install**: `bin/console cache:clear`; for Docker, confirm the `supervisord` service runs the workers.
7. **Existing project**: never run the installer against a database that has data. Use an empty database for a fresh install, or import a dump the user provides (`database-provisioning.md`), then the **existing-project post-install steps** below.
8. **Validate** with `setup-validation.md`.

## Existing-project post-install steps
Run these after the dump import (or after a fresh install of an existing codebase). On the Docker route run each inside the PHP container (`docker compose exec php <command>`), never on the host PHP, which may be the wrong version.
1. `composer install` (add `--no-dev` only for non-development targets).
2. `bin/console cache:clear`
3. `bin/console pimcore:cache:clear` (`p:c:c`)
4. `bin/console pimcore:deployment:classes-rebuild -c -n` (create missing classes, never delete).
5. `bin/console assets:install public`
6. **Migrations: list, never run all.** `bin/console doctrine:migrations:status` and `doctrine:migrations:list` show what is pending. Do not run `doctrine:migrations:migrate`: it applies every pending migration, including ones the user did not ask for. For each pending migration the user wants, print the targeted command with the real class name read from the migration file (never invented):
   ```bash
   bin/console doctrine:migrations:execute 'App\Migrations\Version20260817120000' --up --no-interaction
   ```
   Run it only on the user's yes for that exact version. Take the namespace from the file's `namespace` line or `config/packages/doctrine_migrations.yaml`.
7. `-d` (delete classes without a definition file): skipped and reported. Run `pimcore:deployment:classes-rebuild -c -d -n` only when the user approves that exact target, for example in a project where `var/classes` is source-controlled and complete.
Report each step as pass, fail or skipped with the reason.

## Best practices
- Pin the version constraint you chose (`pimcore/skeleton:^11.0`, or an exact release when reproducibility matters).
- Keep the installer output in a log file under `.pimcore-setup/` and check it for errors; it does not contain the passwords, but scan it before showing it.
- Install only the bundles the user needs.

## Common mistakes
- Passing `--admin-password=...` on the command line (visible in shell history and process list; the installer itself warns about it).
- Running the installer twice on the same database.
- Committing `config/local/database.yaml`.
- Installing the demo when the user wanted a clean project.

## Version notes
- Pimcore 10: installer at `vendor/bin/pimcore-install`, similar options; check `--help`.
- Pimcore 11: same entry point; optional bundles can be installed with `--install-bundles`.
- Later releases may change packages, licences and installer options; always run `--help` first.

## Example
Skeleton, Docker, version `^11`:
`composer create-project pimcore/skeleton:^11.0 acme-pim` in the image from the skeleton's compose file, secrets generated, stack up, installer run from stdin, `database.yaml` git-ignored, cache cleared.

## Validation checklist
- [ ] Version, package and licence stated with sources.
- [ ] `--help` read; env var names confirmed.
- [ ] No secret on any command line or in output.
- [ ] `config/local/` and `.pimcore-setup/` ignored by git.
- [ ] Installer exit code 0 and no errors in its log.

## Expected output
Package and version, install command (with secrets referenced by file, not value), installer result, bundles installed, files that hold secrets (paths only).
