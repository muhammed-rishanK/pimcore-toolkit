---
name: pimcore-setup
description: "Creates, checks or repairs a local Pimcore development environment on Linux, macOS, WSL2 or Windows. Docker first, native supported; skeleton, demo or existing-project profiles; generated credentials that are never printed; five-level health checks and a final setup report. Use when the user runs /pimcore-setup."
argument-hint: "[name] [--dir <path>] [--runtime docker|native] [--profile skeleton|demo] [--version 11] [--check] [--repair]"
disable-model-invocation: true
---

# /pimcore-setup

Toolkit root (`TK`): `${CLAUDE_SKILL_DIR}/../..`
Setup modules (`SETUP_MODULES`): `TK/skills/pimcore-environment/modules`
Setup scripts (`SETUP_SCRIPTS`): `${CLAUDE_SKILL_DIR}/scripts`

Request: `$ARGUMENTS`

You are the orchestrator for environment work. Load the `pimcore-toolkit:pimcore-environment` skill with the Skill tool first: its safety rules bind the whole run.

## Step 0. Parse the arguments
| Argument | Default | Meaning |
|---|---|---|
| first word without `--` | `pimcore-app` | project name (lower case, letters, digits, `-`) |
| `--dir <path>` | `./<name>` | target folder; for the existing profile, the project folder |
| `--runtime docker\|native` | docker, if ready | runtime |
| `--profile skeleton\|demo` | skeleton | package; an existing Pimcore folder switches to the existing profile automatically |
| `--version <v>` | newest supported stable major | Pimcore version constraint, for example `11` means `^11.0` |
| `--check` | off | inspect only: detection and health checks, no change at all |
| `--repair` | off | diagnose, then propose repairs; apply each only after approval |

Unknown flags: say which one and stop. `--check` and `--repair` together: run `--repair` (it includes the check).

## Step 1. Detect (always, read-only)
```bash
bash "${CLAUDE_SKILL_DIR}/scripts/detect-env.sh" --dir "<target>"
```
On native Windows without bash, run `powershell -ExecutionPolicy Bypass -File "${CLAUDE_SKILL_DIR}/scripts/detect-env.ps1" -Dir "<target>"`.
Show the readiness table from `environment-detection.md`. Pick the runtime with the skill's runtime table.

- `--check`: run `health-check.sh` if the target is a Pimcore project, then print the final report (Step 6) with "check only" and stop.
- `--repair`: follow `environment-troubleshooting.md` (diagnose, propose, approve, apply one at a time, re-check). Then Step 6.

## Step 2. Plan and confirm
Print a short plan: OS, runtime, profile, package and version (with source), target folder, ports, database name, compose project name, files that will be created, and anything that needs the user's action (software to install, privileged steps, licence notes).

Stop and ask the user before continuing when any of these hold:
- the target folder exists and is not empty (and is not the existing profile);
- a database, Docker volume or compose project with the same name exists;
- a privileged or system-level step is needed;
- the chosen version has licence terms the user has not accepted yet;
- a version decision is not obvious: ask `pimcore-upgrade-specialist` for a recommendation first (give it the detect-env JSON and the request), then put the recommendation to the user.

Otherwise continue without asking: creating a new folder, generating secrets and running containers for the new project are the requested work.

## Step 3. Build
Start the `pimcore-environment-setup` agent with: the detect-env JSON, the parsed arguments, the plan, the absolute `SETUP_MODULES` and `SETUP_SCRIPTS` paths, and the step to do. Split into steps when it helps you check progress:
1. create the project (`docker-environment.md` or `native-environment.md`);
2. secrets and override (`environment-security.md`);
3. database (`database-provisioning.md`) and start services;
4. install Pimcore (`pimcore-installation.md`).

When the agent returns `needs approval` or `blocked`, ask the user, then resume the agent with the answer (SendMessage) instead of starting a new one.

## Step 4. Validate
Run the health check yourself (do not rely on the agent's report):
```bash
bash "${CLAUDE_SKILL_DIR}/scripts/health-check.sh" --dir "<project>" --runtime <docker|native> [--url <base url>]
```
If checks 1 to 4 do not all pass, run the `--repair` flow once for the failing check, then re-run the health check.

## Step 5. Secret hygiene check
- `git -C <project> check-ignore -q .pimcore-setup/secrets.env` (when the project is a git repository) succeeds.
- `secrets.env` permissions are owner-only.
- No value from `secrets.env` appears in anything you are about to print.

## Step 6. Final report
Use the "Setup report" format in `TK/references/output-formats.md`:
OS, runtime and method, Pimcore version, PHP version, project folder, services and ports, database name and status, admin username, how to read the password (the command, not the value), URLs (site, admin), useful commands (start, stop, logs, console, workers), the five health checks, files created, open items. Never include a password.
