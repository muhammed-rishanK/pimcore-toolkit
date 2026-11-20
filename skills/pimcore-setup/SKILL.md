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
| `--repair` | off | diagnose and apply safe repairs automatically; unsafe ones are listed, not done |
| `--plan` | off | show the options and scenarios below, then stop without building anything |
| `--secure-admin` | off | use a random admin name and password instead of the local-development default `admin` / `admin` |
| `--no-install` | off | do not install missing prerequisites (Docker, WSL2); list them under "Needs you" instead |
| `--ask` | off | stop and ask at each decision instead of choosing the recommended option |

Unknown flags: say which one and stop. `--check` and `--repair` together: run `--repair` (it includes the check).

## Step 1. Detect (always, read-only)
```bash
bash "${CLAUDE_SKILL_DIR}/scripts/detect-env.sh" --dir "<target>"
```
On native Windows without bash, run `powershell -ExecutionPolicy Bypass -File "${CLAUDE_SKILL_DIR}/scripts/detect-env.ps1" -Dir "<target>"`.
Show the readiness table from `environment-detection.md`. Pick the runtime with the skill's runtime table.

- `--check`: run `health-check.sh` if the target is a Pimcore project, then print the final report (Step 6) with "check only" and stop.
- `--repair`: follow `environment-troubleshooting.md` (diagnose, apply the safe fixes one at a time, re-check). Then Step 6.

## Step 2. Plan and decide
Always print the options first, built from what you actually read (`composer show -a pimcore/skeleton` or Packagist, the release's installer `--help`, the detect-env JSON). Never fill the table from memory.

```
Pimcore versions you can install
  Version   PHP needed   Product key   Notes
  <ver>     <range>      <yes|no>      <source: read from ...>   <- recommended   (mark exactly one)
  ...

Your situation -> what happens
  Empty folder, no project      -> new project with the recommended version
  Folder already has a project  -> existing profile: --check first, --repair if broken
  Folder exists, not Pimcore    -> new project in <name>-2, the folder is left alone
  Newest version needs a key    -> recommended version above is installed; to get the newest, run again with --version <v> and register (the link is printed)
  Docker not ready              -> native route, or the one command you must run is listed
```

How to fill the table (tested against real Packagist data):
- Group `pimcore/skeleton` releases by line (11, 2025, 2026) and show the newest stable release of each. Skip dev and RC tags.
- `require.php` is often empty in skeleton releases (Pimcore 11.x and some year releases show none). When it is empty, take the PHP range from `pimcore/pimcore` for the same line (`https://repo.packagist.org/p2/pimcore/pimcore.json`). If that is also empty, print `see docs` and never guess.
- The product-key column is not in Packagist. Mark it `yes` or `no` only when the installer `--help`, the release notes or the licence page says so. Otherwise print `unknown` and treat that row as not recommended. Pimcore 11 is the fallback recommended row when newer rows are `unknown`.
- Rows whose PHP range excludes the host PHP (from the detect-env JSON) get the note `needs PHP <x>; Docker image provides it` when Docker is ready, or `not installable natively` otherwise.
- Only the last 3 lines are shown, to keep the table short.

Then continue with the recommended row unless `--plan` was given (stop here) or `--ask` was given (ask which row). To choose a different version, rerun with `--version <v>`.

Then print a short plan: OS, runtime, profile, package and version (with source), target folder, ports, database name, compose project name, files that will be created, and anything that needs the user's action (software to install, privileged steps, licence notes).

### Local developer setup (the default)
`/pimcore-setup` builds a local development environment, not a server. Unless `--secure-admin` is given, it:
- creates the admin user `admin` with password `admin` (`gen-secrets` with `--dev-login`); database passwords stay random;
- publishes every port on `127.0.0.1` only, so the stack and its `admin` login cannot be reached from the network (this is required, not optional: if it cannot bind to localhost, it switches to a random admin login instead);
- uses development settings (`APP_ENV=dev`) and the Docker route when Docker is ready.
Never use the dev login when the target is a server, a shared machine, a cloud host or anything reachable from outside. The report shows `admin / admin` as the login and says it is for local development only. Pimcore's admin UI requires 10 or more characters for any password change, so change it there if you ever want a different one.

### Decide, do not ask
By default the command makes every choice itself with the recommended option, records it, and keeps going. It does not stop to ask. Each decision is listed under "Decisions made" in the final report so you can see what was chosen and why.

| Situation | What it does on its own |
|---|---|
| Target folder exists and is not empty (and is not the existing profile) | Uses the next free name (`<name>-2`, `-3`). Never touches the existing folder. |
| Database, Docker volume or compose project name already exists | Adds a suffix to the new names. Never reuses or deletes the old ones. |
| Ports are taken | Picks the next free ports and writes them to the override file. |
| Version not obvious | Asks `pimcore-upgrade-specialist` (agent, not the user) and follows its recommendation. |
| Version needs a product key from Pimcore's licensing site, or other licence acceptance | Picks the newest version that does not need one (for example Pimcore 11) unless `--version` was given explicitly. Never registers for the user, and never uses a skip or bypass flag (such as `--skip-validation`) to get around registration or licence checks. |
| `--version` was given explicitly and needs a key | Builds everything else (secrets, services, database), prints the registration link, and ends with the install marked "waiting for product key" plus the one command to finish. No blocking question. |
| Docker or WSL2 is missing | Installs it itself with `install-prereqs` (see "Install prerequisites" below). Running the command is the user's consent. Skipped only with `--no-install`. |
| Another privileged step (firewall, hosts file, system settings) | Not done. Finishes every other step and lists the exact command under "Needs you". |
| Destructive step (delete, `down -v`, `DROP`, `rm -rf`, `classes-rebuild -d`) | Not done. It takes the non-destructive alternative and lists the skipped step. |
| `--repair` | Applies safe fixes itself (restart the project's own containers, clear caches, regenerate the project's own generated files), re-checks after each, and lists unsafe ones as not done. |

Only these cannot be decided for the user, and they never block the rest of the run: passwords or tokens for third-party accounts, account registration, and the operating system's own consent steps (the Windows administrator prompt, a `sudo` password, a restart). The plugin triggers those steps but never types, reads or bypasses them. They are reported under "Needs you".

### Install prerequisites (default, no questions)
When Docker is the chosen route and it is missing or not running, run the installer yourself instead of printing commands for the user:
```bash
# Linux / macOS / WSL2 / Git Bash
bash "$SETUP_SCRIPTS/install-prereqs.sh"
# Windows PowerShell
powershell -ExecutionPolicy Bypass -File "$SETUP_SCRIPTS/install-prereqs.ps1"
```
Add `--check` (`-Check`) first if you only need to know what is missing. Read the JSON `status`:
- `ready`: continue with Step 3.
- `restart_required` (Windows): WSL2 and Ubuntu are installed (free; Docker Desktop is never installed, so there is no licence question). Tell the user in one line that Windows must restart once (the OS requires it), give the exact command to run again afterwards, and stop. Everything chosen so far is repeatable because nothing was created.
- `needs_password` (Linux): `sudo` has no passwordless rule. Print the one command from the JSON under "Needs you".
- `failed`: show the note, then use the native route if possible, otherwise report under "Needs you".

On Windows the installer uses a Docker already on the machine if one works, otherwise it sets up Docker Engine inside WSL2 (run project commands with `wsl -d Ubuntu -u dev --cd ~ -- <command>`, and keep the project in the WSL filesystem, not `/mnt/c`). Windows shows its own administrator prompt once, only when WSL must be enabled. The user clicks Yes; the plugin cannot and does not click it. With `--no-install`, skip this and list the commands instead.

Pass `--ask` to turn the old behaviour back on: the command then stops and asks at each row above instead of deciding.

## Step 3. Build
Start the `pimcore-environment-setup` agent with: the detect-env JSON, the parsed arguments, the plan, the absolute `SETUP_MODULES` and `SETUP_SCRIPTS` paths, and the step to do. Split into steps when it helps you check progress:
1. create the project (`docker-environment.md` or `native-environment.md`);
2. secrets and override (`environment-security.md`);
3. database (`database-provisioning.md`) and start services;
4. install Pimcore (`pimcore-installation.md`).

When the agent returns `needs approval` or `blocked`, apply the "Decide, do not ask" table yourself and resume the agent with the decision (SendMessage) instead of starting a new one. Without `--ask`, never put a question to the user mid-run.

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
