# Environment troubleshooting

## Purpose and scope
Diagnose and repair a Pimcore development environment that fails a health check, and run the `--repair` flow: diagnose read-only first, then propose each repair and apply it only after approval.

**Use when:** a health check fails, `--repair`, or the user reports a broken local environment.
**Do not use when:** the problem is in application code (route to the debugger agent through `/pimcore`).

## Inspect
- `detect-env` and `health-check` output.
- Docker: `docker compose ps`, `docker compose logs --tail=200 <service>`.
- Native: PHP error log, web server log, `var/log/dev.log` (or the environment's log).
- `config/local/database.yaml` exists (do not print it).

## Workflow (`--repair`)
1. **Diagnose** without changing anything. Collect the failing checks and the matching symptoms below.
2. **Propose** a numbered repair list. For each: what, why, the exact command, whether it is reversible, and the risk.
3. **Approve**: each repair needs the user's yes, unless it only touches files the setup created in this project and is reversible (for example restarting a container of this project). Destructive repairs (volume removal, database drop, file deletion) always need a yes naming the target.
4. **Apply** one repair at a time, re-run the related health check after each, and stop if a repair does not help.
5. **Report** before and after results.

## Symptoms and fixes
| Symptom | Likely cause | Fix |
|---|---|---|
| `docker: Cannot connect to the Docker daemon` | Docker not running | User starts Docker Desktop or `sudo systemctl start docker` (user runs it) |
| `port is already allocated` | another service on the port | Change this project's port mapping; do not stop the other service |
| `Permission denied` on `var/` or `public/var` | files owned by root or the wrong uid | Set the uid:gid in the override, then `docker compose run --rm -u 0 php chown -R <uid>:<gid> var public/var` (approval) |
| `SQLSTATE[HY000] [1045] Access denied` | credentials in `database.yaml` do not match the DB (often a reused volume) | Compare with `secrets.env` (without printing); propose resetting the DB user password inside the container (approval), not deleting the volume |
| `SQLSTATE[HY000] [2002]` | DB not ready or wrong host | Wait for the DB health check; host must be the compose service name inside Docker, `127.0.0.1` natively |
| HTTP 500 after install | cache, missing extension, or class definitions not built | `bin/console cache:clear`, check the log, `bin/console pimcore:deployment:classes-rebuild -c` |
| `/admin` blank or assets 404 | assets not installed | `bin/console assets:install public` |
| Thumbnails never appear | workers not running | Start supervisord service or messenger consumers |
| Allowed memory size exhausted (CLI) | low `memory_limit` | Run with `php -d memory_limit=-1` for that command, or raise it in a user ini |
| Very slow on WSL2 | project under `/mnt/c` | Move to the Linux filesystem (user's decision; give the steps) |
| Container exits on Apple Silicon | amd64 image | Use an arm64 tag or set `platform: linux/amd64` (slower) |
| `Class ... not found` after pulling an existing project | autoload or class files stale | `composer install`, `bin/console pimcore:deployment:classes-rebuild -c`, cache clear |

## Best practices
- Change one thing at a time.
- Prefer fixes inside the project over host changes.
- Keep a short repair log in `.pimcore-setup/repair.log` (no secrets).

## Common mistakes
- `docker compose down -v` as a first move.
- Editing `database.yaml` by hand with a guessed password.
- Fixing permissions with `chmod -R 777`.

## Version notes
Command names here are for Pimcore 10 and 11. `pimcore:deployment:classes-rebuild -d` deletes classes that have no definition file; never use it in a repair without approval.

## Example
Check 2 failed with 1045. Cause: an old `acme-pim_db` volume from an earlier attempt. Proposed: (1) reset the DB user password inside the container to the value in `secrets.env`, reversible; (2) alternative: remove the volume, destructive. User approved 1; check 2 passed.

## Validation checklist
- [ ] Diagnosis before any change.
- [ ] Every repair approved as required.
- [ ] Health checks re-run after each repair.

## Expected output
Diagnosis table, repair proposals, what was applied with approval, before and after health results, remaining issues.
