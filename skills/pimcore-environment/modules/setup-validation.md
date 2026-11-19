# Setup validation

## Purpose and scope
Prove the environment works, separately for each level, so a partial success is never reported as a full one. Five checks, each pass, fail or skipped with evidence.

**Use when:** the end of every install, `--check`, and before and after every `--repair` action.
**Do not use when:** never skipped.

## Inspect: the five checks
| # | Check | Pass means | Evidence |
|---|---|---|---|
| 1 | Installation completed | `vendor/` present, `bin/console` runs, `pimcore-install` exited 0 (or the project was already installed) | `bin/console --version` output |
| 2 | Database initialized | Pimcore tables exist and the admin user row exists | `SELECT COUNT(*)` on information_schema for the DB; `bin/console dbal:run-sql "SELECT COUNT(*) FROM users WHERE type='user'"` or the version's equivalent |
| 3 | Application healthy | the front page or `/admin/login` returns HTTP 200 or 302 with no PHP error; `bin/console cache:clear` works | HTTP status and response time |
| 4 | Admin accessible | `/admin/login` returns 200 and contains the login form; optional browser login with the generated credentials (by the user, or by a browser tool that reads them from the file without echoing) | status and a check for the form |
| 5 | Optional services ready | Redis, workers (supervisord or messenger consumers), mail catcher, OpenSearch or Elasticsearch if configured | per-service status; skipped if not configured |

## Workflow
1. Run `bash "$SETUP_SCRIPTS/health-check.sh" --dir <project> [--runtime docker|native] [--url http://localhost:<port>]` (PowerShell: `health-check.ps1`). It runs the five checks, prints a table and JSON, and exits 0 only if checks 1 to 4 pass.
2. For anything the script marks `skipped`, give the reason (for example, no URL known, or the DB client missing on the host).
3. If a check fails, do not continue to later checks that depend on it; mark them `skipped (depends on #n)`.
4. On failure, go to `environment-troubleshooting.md`.

## Best practices
- Read each result; never treat a previous exit code as proof.
- Use the project's real URL and port (from compose or the web server you started).
- Keep the check read-only. It does not create, change or delete data.

## Common mistakes
- Reporting "installed" when only `composer create-project` finished.
- A 500 page counted as healthy because the server answered.
- Checking `/admin` instead of `/admin/login` and getting a redirect loop counted as pass.

## Version notes
The users table and console command names are for Pimcore 10 and 11; check the schema if a query fails on another version and report the check as `skipped` with the reason rather than guessing.

## Example
```
#  Check                   Result   Evidence
1  Installation completed  pass     Pimcore 11.x console runs
2  Database initialized    pass     212 tables, 1 admin user
3  Application healthy     pass     GET / 200 in 0.41s
4  Admin accessible        pass     GET /admin/login 200, form found
5  Optional services       pass     redis PONG, supervisord running
```

## Validation checklist
- [ ] All five checks reported.
- [ ] Each with evidence.
- [ ] Failures linked to the troubleshooting step.

## Expected output
The five-row table, plus the overall verdict: healthy, degraded (optional services only), or failed.
