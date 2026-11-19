---
name: pimcore-environment
description: "Shared standards and setup modules for creating, validating and repairing Pimcore development environments (Docker first, native supported) on Linux, macOS, WSL2 and Windows. Loaded by the pimcore-environment-setup agent and the /pimcore-setup command."
user-invocable: false
---

# Pimcore environment standards

These rules apply to every environment task. Project instruction files and the user's explicit words in the conversation win over them, except the safety rules, which only the user can relax, one action at a time.

`SETUP_MODULES` = `${CLAUDE_SKILL_DIR}/modules` (or the absolute path given in your prompt).
`SETUP_SCRIPTS` = `${CLAUDE_SKILL_DIR}/../pimcore-setup/scripts`.

## 1. Safety rules (non-negotiable)
1. **Never overwrite.** A non-empty target folder, an existing database, Docker volume, compose project name or config file is never replaced or deleted without the user's explicit yes for that item. In the default autonomous mode the answer is never to ask: take a new name or location instead (see the decision table in `/pimcore-setup`).
2. **No privilege without permission.** No `sudo`, `runas`, administrator shell, system package install, Docker install, service start or stop, firewall, hosts file or system setting change unless the user says yes to that exact step. In the default autonomous mode, pick a route that needs none, and list the command under "Needs you" if no such route exists.
3. **Do not touch other projects.** Never change files, containers, volumes or databases that belong to another project. Never stop containers you did not start. Check port conflicts and choose other ports for the new project instead.
4. **Credentials:**
   - generated with `gen-secrets.sh` / `gen-secrets.ps1` (cryptographic randomness);
   - never `pimcore/pimcore`, `ROOT`, `password` or any other predictable value for the database or any service. The one exception is the local-development admin login `admin` / `admin` that `/pimcore-setup` uses by default (`gen-secrets --dev-login`), and only while every published port is bound to `127.0.0.1`. With `--secure-admin`, or when localhost binding is not possible, the admin login is random too;
   - stored only in `<project>/.pimcore-setup/secrets.env` (owner-only permissions) and in files Pimcore itself writes (`config/local/database.yaml`);
   - both locations git-ignored before the first `git add` anyone could run;
   - never printed, echoed, logged, put on a command line, in a URL, in the final report or in a commit;
   - passed to the installer through environment variables read from the secrets file on stdin (see `pimcore-installation.md`).
5. **No destructive commands** (`docker compose down -v`, `docker volume rm`, `DROP DATABASE`, `rm -rf`, `pimcore:deployment:classes-rebuild -d`) without approval naming the exact target. In autonomous mode they are skipped and reported, not asked about.
6. **Version honesty.** Never claim a version, image tag or requirement you did not read from the package, the image or the official docs in this session.
7. **Licences.** If the chosen Pimcore version is under a licence other than GPLv3 (for example the Pimcore Open Core License for newer releases), do not accept it for them. In autonomous mode, choose a version that does not need acceptance or a key, and say so under "Decisions made".
   **Product key.** Some newer Pimcore releases (the year-based ones, for example 2026.x) need a product key from Pimcore's licensing site before the installer can finish. Registering creates an account tied to the user's identity, so never register for them and never guess whether skipping it limits the install. Before installing a version that may need it, check the installer (`--help`, or the release's install docs) and tell the user in the plan. In autonomous mode, install a version that does not need one (for example Pimcore 11). Only when the user explicitly requested the newer version, prepare everything else and report the registration link under "Needs you". Never use a skip or bypass flag for registration or licence validation.
8. **Report what ran.** Every health check reports pass, fail or skipped with the reason. Never mark a check as passed because an earlier step returned exit code 0.

## 2. Runtime choice
| Situation | Recommend |
|---|---|
| Docker Engine or Docker Desktop available and running | Docker (default) |
| Windows without WSL2 | Install WSL2 and Docker Desktop (user does it), then Docker. Native Windows is not supported by Pimcore for development in practice. |
| Docker not allowed or not wanted, Linux or macOS | Native with PHP, Composer, MariaDB or MySQL, Redis optional |
| Existing Pimcore project folder | Use the project's own runtime files (`docker-compose*.y*ml`, `.ddev`, `.lando.yml`, README) |

## 3. Module index
| Module | Read it for |
|---|---|
| `environment-detection.md` | OS, CPU, memory, disk, tools, ports, readiness score |
| `docker-environment.md` | Docker project creation, compose override, ports, user ids, volumes |
| `native-environment.md` | PHP, extensions, Composer, database and web server without Docker, per OS |
| `pimcore-installation.md` | skeleton or demo, `pimcore-install` non-interactive, existing projects, bundles |
| `database-provisioning.md` | database and user creation, charset, existing DB checks, dumps |
| `environment-security.md` | secrets generation, storage, git-ignore, permissions, cleanup |
| `setup-validation.md` | the five health checks and how to run them |
| `environment-troubleshooting.md` | symptoms, causes, fixes, the `--repair` flow |

## 4. Writing style
Plain, short sentences. Commands in code blocks. No filler words. Mask any secret as `****`.
