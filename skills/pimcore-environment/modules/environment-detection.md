# Environment detection

## Purpose and scope
Find out what the machine is and has before installing anything: operating system and variant (Linux distribution, macOS, WSL2, Windows with Git Bash or PowerShell), CPU architecture, memory, free disk, Docker and Compose, PHP and extensions, Composer, database clients, Git, Node, free ports, and path problems. Produces a readiness verdict.

**Use when:** the start of every `/pimcore-setup` run, `--check`, and `--repair`.
**Do not use when:** never skipped; it is read-only and fast.

## Inspect
Run the toolkit script; it only reads:
- Linux, macOS, WSL2, Git Bash: `bash "$SETUP_SCRIPTS/detect-env.sh" --dir <target>`
- PowerShell: `powershell -ExecutionPolicy Bypass -File "$SETUP_SCRIPTS/detect-env.ps1" -Dir <target>`

It prints JSON with: `os`, `osDetail`, `arch`, `cpus`, `memGB`, `diskFreeGB`, `docker` (installed, version, daemonRunning, compose v2 version), `php` (version, extensions), `composer`, `mysqlClient`, `git`, `node`, `ports` (80, 443, 3306, 6379, 8080 free or in use), `target` (exists, empty, isPimcore, onWindowsMount), `warnings`.

## Workflow
1. Run the script for the target folder the user gave (default: `./<name>` in the current directory; never inside another project's tree unless the user asked).
2. Read the JSON. Compute readiness:
   - **Ready for Docker**: Docker installed, daemon running, Compose v2, memory 4 GB or more for the containers, 5 GB free disk or more, a free HTTP port.
   - **Ready for native**: PHP version within the target Pimcore range, required extensions, Composer 2, a reachable MariaDB or MySQL server and credentials to create a database, 3 GB free disk.
   - **Blocked**: list exactly what is missing and the command or download the user needs (do not install it yourself).
3. Flag path problems: on WSL2, a target under `/mnt/c` (slow file access; recommend `~/projects/<name>`); on Windows, paths with spaces; on macOS, a folder not shared with Docker Desktop.
4. Flag architecture: Apple Silicon and ARM Linux need images with arm64 support; confirm the image tag supports the platform or plan `platform: linux/amd64` with a performance warning.
5. If the target is an existing Pimcore project (`isPimcore: true`), switch to the existing-project profile.

## Best practices
- Show the user a short readiness table, not the raw JSON.
- Recommend Docker when both runtimes are possible.
- Never guess a tool version; report "not found".

## Common mistakes
- Treating "docker installed" as "docker running".
- Missing that `docker compose` (v2 plugin) is absent while `docker-compose` (v1) exists.
- Ignoring port 80 already used by another local web server.
- Creating the project on a Windows mount from WSL2.

## Version notes
Version requirements (PHP range, database versions) depend on the Pimcore version chosen; take them from the official system requirements page for that version, or from the package's `composer.json` once downloaded.

## Example
```
OS: Ubuntu 24.04 (Linux, x86_64), 8 CPUs, 16 GB, 120 GB free
Docker 27.1, Compose v2.29, daemon running
Ports: 80 in use, 8080 free, 3306 in use
Verdict: ready for Docker; use host port 8080 for nginx; do not publish the DB port
```

## Validation checklist
- [ ] Script ran and JSON parsed.
- [ ] Readiness verdict per runtime with reasons.
- [ ] Port, path and architecture issues listed.

## Expected output
Readiness table (OS, resources, tools, ports), recommended runtime, blockers with the user's next step.
