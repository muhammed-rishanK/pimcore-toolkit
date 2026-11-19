# Database provisioning

## Purpose and scope
Create the database and a dedicated application user for a new Pimcore project, check that an existing database is safe to use, and import a dump for the existing-project profile. MariaDB and MySQL only.

**Use when:** native installs, existing-project setups, `--repair` when the database is missing or unreachable. In Docker installs the database container creates the database and user from the compose environment, so this module only checks it.
**Do not use when:** the database already holds the project's data and the user did not ask to change it.

## Inspect
- Server type and version: `SELECT VERSION();` (Docker: `docker compose exec -T db mariadb -V` or `mysql -V`).
- Whether the target database exists and has tables:
  `SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = '<db>';`
- Whether the target user exists: `SELECT User, Host FROM mysql.user WHERE User = '<user>';` (needs privileges; skip if denied and say so).
- The required version and charset for the Pimcore version from the official requirements page.

## Workflow
1. **Names**: database and user default to the project name in lower case with `_` (for example `acme_pim`). Never reuse a name that exists without the user's yes.
2. **Existing database**: if it exists with 1 or more tables, stop. Report the table count and ask: use another name, or (with explicit approval) use this one.
3. **Create** with the admin credentials the user supplies or a local socket login they already have. Pass passwords through a client option file, not the command line:
   ```bash
   umask 077
   printf '[client]\nuser=%s\npassword=%s\n' "$ADMIN_USER" "$ADMIN_PASS" > .pimcore-setup/admin.cnf
   mariadb --defaults-extra-file=.pimcore-setup/admin.cnf <<SQL
   CREATE DATABASE \`acme_pim\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
   CREATE USER 'acme_pim'@'localhost' IDENTIFIED BY '<from secrets.env>';
   GRANT ALL PRIVILEGES ON \`acme_pim\`.* TO 'acme_pim'@'localhost';
   SQL
   rm -f .pimcore-setup/admin.cnf
   ```
   Read the app password from `secrets.env` inside the same shell; do not paste it into the conversation.
4. **Docker**: the skeleton's database service creates the database and user from its environment on the first start of an empty volume. Verify with `docker compose exec -T db sh -c 'mariadb -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" -e "SELECT 1" "$MYSQL_DATABASE"'` (variable names come from the compose file; read them). If the volume already existed with other credentials, the new ones are ignored: report it, do not delete the volume without approval.
5. **Dump import** (existing profile): only into an empty database, with the user's dump path. Stream it: `mariadb --defaults-extra-file=<app.cnf> <db> < dump.sql` (or `zcat dump.sql.gz | ...`). After import, run migrations and class rebuild as `pimcore-installation.md` says.

## Best practices
- `utf8mb4` with `utf8mb4_unicode_ci` (or the collation the docs specify for the version).
- One user per project, privileges on that database only.
- `localhost` or the Docker network host only; never `'%'` on a shared server unless the user needs it.

## Common mistakes
- Using `root` as the application user.
- `-pPASSWORD` on the command line.
- Importing a production dump with real customer data into a local machine without the user knowing what it contains.
- Running the Pimcore installer against a database that already has tables.

## Version notes
- MariaDB clients are `mariadb` and `mariadb-admin` in recent releases; `mysql` and `mysqladmin` in older ones and in MySQL. Use what the image or host has.
- MySQL 8 needs `CREATE USER` before `GRANT` (no implicit creation).
- Check the Pimcore docs for minimum MariaDB and MySQL versions for the chosen release.

## Example
`acme_pim` did not exist; created with utf8mb4; user `acme_pim@localhost` with all privileges on it; password stored in `.pimcore-setup/secrets.env`; temporary client file removed.

## Validation checklist
- [ ] No existing database or user overwritten.
- [ ] Charset utf8mb4.
- [ ] Dedicated user, limited privileges.
- [ ] No password on a command line or in output; temporary client files deleted.

## Expected output
Server version, database name, user name (no password), status (created, existing and empty, imported), table count.
