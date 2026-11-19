# Native environment

## Purpose and scope
Run Pimcore without Docker: PHP with the required extensions, Composer, a MariaDB or MySQL server, optional Redis, and a web server for development, per operating system. Installation of system software is done by the user (or by you only after explicit approval for each command).

**Use when:** the user chose `--runtime native`, or Docker cannot be used.
**Do not use when:** Docker is available and the user did not ask for native.

## Inspect
- `detect-env` output: PHP version and extensions, Composer, database client, ports.
- The target Pimcore version's official system requirements (PHP range, required and recommended extensions, database versions). Read them; do not use a remembered list.
- Whether a database server is reachable and whether the user has credentials that can create a database and user.

## Workflow
1. **Compare** the installed PHP and extensions with the requirements. Typical required extensions include `intl`, `pdo_mysql`, `mbstring`, `iconv`, `dom`, `simplexml`, `xml`, `fileinfo`, `zip`, `gd` or `imagick`, `exif`; `opcache`, `redis`, `apcu` are recommended. Confirm against the docs for the version.
2. **Missing software**: give the user the install commands for their OS and wait. Examples (verify package names for their release):
   - Ubuntu or Debian: `sudo apt install php8.x-{cli,fpm,intl,mysql,mbstring,xml,zip,gd,curl,bcmath} mariadb-server redis-server composer` (versions depend on the distribution or a PPA).
   - macOS: `brew install php composer mariadb redis`, then `brew services start mariadb`.
   - Windows: not supported natively in practice; use WSL2 (Ubuntu) and follow the Linux steps inside it, or Docker Desktop.
3. **Database**: create the database and a dedicated user with `database-provisioning.md`.
4. **Create the project**: `composer create-project pimcore/skeleton:<constraint> <name>` in an empty folder.
5. **Secrets**: `gen-secrets.sh <project>` (no `--compose`), then install with `pimcore-installation.md`, using `mysql-host-socket` = `127.0.0.1` (or the socket path) and the generated credentials.
6. **Web server** for development:
   - Symfony CLI if installed: `symfony server:start -d --port=<free port>` in the project.
   - Or PHP built-in server: `php -S 127.0.0.1:<port> -t public public/index.php` (development only).
   - Nginx or Apache with PHP-FPM: use the official Pimcore server config for the version; changing system web server config needs approval.
7. **Workers and maintenance**: run `bin/console messenger:consume pimcore_core pimcore_maintenance pimcore_scheduled_tasks pimcore_image_optimize pimcore_asset_update` (transport names for Pimcore 11; check `config` for the installed version) in a terminal or a process manager, and `bin/console pimcore:maintenance` from cron if needed.

## Best practices
- Use a PHP version manager the user already has (phpenv, Homebrew versions, ondrej PPA) instead of replacing the system PHP.
- Bind development servers to `127.0.0.1`.
- Raise `memory_limit` for CLI to at least what the docs recommend (often 512M or more) in a user-level ini, not the system one, unless approved.

## Common mistakes
- Installing packages with `sudo` without asking.
- Using the database root account for the application.
- PHP CLI and PHP-FPM with different versions or extensions.
- Forgetting the workers, so thumbnails and maintenance jobs never run.

## Version notes
PHP and database requirements change with every major version. Pimcore 11 supports PHP 8.1 to 8.3 (check the docs for the exact minor you install); later releases raise the minimum. Always read the requirements page for the chosen version.

## Example
macOS, PHP 8.3 via Homebrew, MariaDB via Homebrew services, Symfony CLI on port 8000, workers in a separate terminal.

## Validation checklist
- [ ] PHP version and extensions match the docs for the version.
- [ ] Dedicated DB user, not root.
- [ ] Web server bound to localhost on a free port.
- [ ] Workers running or documented.

## Expected output
Software versions found, what the user installed, project path, database name and user (no password), web URL, worker command.
