---
name: pimcore-doctor
description: "Read-only health audit of an existing Pimcore project: versions and support status, composer files, secrets tracked in git, plain passwords in config, git-ignore of generated folders, class definitions under version control, debug settings, Messenger workers, quality tooling and CI, upgrade impact, optional dependency advisories, and whether toolkit auto-update is on. Changes nothing. Use when the user runs /pimcore-doctor."
argument-hint: "[<project folder>] [--online] [--json]"
disable-model-invocation: true
---

# /pimcore-doctor

Toolkit root (`TK`): `${CLAUDE_SKILL_DIR}/../..`
Doctor script: `${CLAUDE_SKILL_DIR}/scripts/doctor.sh`

Request: `$ARGUMENTS`

This command only reads. It never edits a file, runs a migration, starts or stops a container, or changes a setting. Every fix is a suggestion the user decides on.

## Step 1. Parse the arguments
| Argument | Default | Meaning |
|---|---|---|
| first word without `--` | current folder | the Pimcore project to audit |
| `--online` | off | also run `composer audit --locked` (needs network and composer on PATH) |
| `--json` | off | print the raw JSON instead of the report |

Unknown flags: say which one and stop.

## Step 2. Run the audit
```bash
bash "${CLAUDE_SKILL_DIR}/scripts/doctor.sh" "<project>" --format json [--online]
```
The script prints one JSON object: `summary` (pass, warn, fail counts) and `checks` (id, area, result, evidence, fix). It never prints a secret value, only file names and key names. A full upgrade-impact scan can take up to a minute on a large project; say so before you start.

If composer is not on the host PATH and the project runs in Docker, run the `--online` part inside the PHP container instead: `docker compose exec -T php composer audit --locked`.

## Step 3. Check what the script cannot see
Read, do not change:
- `config/packages/*messenger*.yaml`: every transport that is routed to has a consumer in the worker config the script found.
- `config/local/database.yaml` or `.env*`: the database user is not `root` outside local development.
- The project's own instruction files (`CLAUDE.md`, `AGENTS.md`, CONTRIBUTING): if they set rules the audit breaks, list them.

## Step 4. Report
```
Pimcore doctor: <project>   (read-only, nothing was changed)

Result  Area        Check            Evidence
FAIL    security    secrets-tracked  tracked in git: .env.local
WARN    versions    version          ...
PASS    ...

Fix first
1. <fail items, each with the exact command or file to change>
Then
2. <warn items, most useful first>

Not checked: <anything skipped, with the reason>
```
Rules:
- Fails first, then warnings. Passed checks go in the table, not in the fix list.
- For each upgrade or code finding, offer the next command: `/pimcore plan an upgrade to <target>`, `/pimcore-review --all`, or `/pimcore-setup --repair`.
- Never claim a check passed if the script reported `skip`. Say why it was skipped.
- Do not run any fix in this command, even a safe one. If the user wants one applied, they ask for it next.
