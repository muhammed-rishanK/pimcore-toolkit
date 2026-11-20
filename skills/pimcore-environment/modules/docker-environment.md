# Docker environment

## Purpose and scope
Create and run a Pimcore project with Docker the way the official skeleton and demo do it, adjusted for safe credentials, free ports and correct file ownership. Covers project creation with a throwaway container, the compose override, start-up, and container commands.

**Use when:** runtime is Docker (default).
**Do not use when:** Docker is unavailable or the user chose native.

## Inspect
- `detect-env` output: Docker and Compose v2 running, ports, architecture, OS.
- The chosen package and version (`pimcore/skeleton` or `pimcore/demo`), decided with `pimcore-installation.md`.
- After creation: the project's own `docker-compose.yaml` (service names, image tags, ports, volumes). Read it; do not assume service names.

## Workflow
1. **Pick the PHP image** for creating the project: read the target version's `docker-compose.yaml` from the package source (for example the GitHub tag of `pimcore/skeleton`) and use the same `pimcore/pimcore:<tag>` image the project will run. State the tag and where it came from.
2. **Create the project** in an empty target folder with a throwaway container (no host PHP or Composer needed):
   ```bash
   docker run -u "$(id -u):$(id -g)" --rm -v "$PWD:/var/www/html" pimcore/pimcore:<tag> \
     composer create-project pimcore/skeleton:<constraint> <name>
   ```
   On Windows, prefer the WSL route: run the same commands through `wsl -d Ubuntu -u dev --cd ~ --` with the project under `~/`. With a Docker Desktop the user already has, omit `-u` and use `${PWD}`. On macOS, `-u` is optional.
3. **Secure the project before starting it**: run `gen-secrets.sh <project> --dev-login --compose` (see `environment-security.md`). It writes `.pimcore-setup/secrets.env` and `docker-compose.override.yaml` (both git-ignored, owner-only) with:
   - random database root and user passwords and a random admin user and password;
   - your host uid:gid for the PHP and supervisord services on Linux (the skeleton ships these `user:` lines commented out);
   - nothing else. Compose loads the override automatically.
4. **Ports**: the skeleton publishes nginx on host port 80. If 80 is used, change that one mapping in the new project's `docker-compose.yaml` to a free port (for example `"8080:80"`). This is the new project's own file, so editing it is fine; say so in the report. Bind every published port to `127.0.0.1` (for example `"127.0.0.1:8080:80"`) because the default admin login is `admin` / `admin`. Do not publish the database port unless the user wants host access.
5. **Compose project name**: defaults to the folder name. Check `docker compose ls` and `docker volume ls` for clashes first; if a clash exists, stop and ask.
6. **Start**: `docker compose up -d`, then `docker compose ps` until services are running and the database accepts connections (`docker compose exec -T db mariadb-admin ping` or `mysqladmin ping` with the image's tool; read the compose healthcheck if present).
7. **Install Pimcore** with `pimcore-installation.md`.
8. **Workers**: the skeleton runs Messenger consumers in the `supervisord` service; confirm it is running.

## Best practices
- Read the generated compose file and follow its service names (`php`, `db`, `redis`, `nginx`, `supervisord` in recent skeletons, but verify).
- Keep the project under the Linux filesystem on WSL2 (`~/projects`), not `/mnt/c`.
- Use `docker compose exec -T` in scripts (no TTY).
- Use `docker compose logs --tail=100 <service>` when something fails.

## Common mistakes
- Creating the project as root inside the container, leaving root-owned files on Linux.
- Starting the stack with the default database passwords, then changing them later (the DB volume keeps the first values).
- Running `docker compose down -v` to "fix" something and wiping the database.
- Publishing 3306 on a machine where a local MySQL already uses it.
- Apple Silicon: pulling an amd64-only tag without noticing the emulation cost.

## Version notes
- Image tags follow `pimcore/pimcore:php<major.minor>-<variant>` patterns that change over time; take the tag from the target version's own compose file.
- Older Docker installs have only `docker-compose` v1; the toolkit expects Compose v2 (`docker compose`). Tell the user to upgrade rather than mixing.

## Example
Target `~/projects/acme-pim`, port 80 busy:
- created with `pimcore/pimcore:<tag from skeleton compose>`
- nginx mapped to 8080
- override with uid 1000:1000 and generated secrets
- `docker compose up -d`, all services running

## Validation checklist
- [ ] Image tag sourced and stated.
- [ ] Secrets and override written before first `up`.
- [ ] No port or project-name clash.
- [ ] Services running; database reachable.

## Expected output
Image tag and source, project path, ports, files created (names only), service status table.
