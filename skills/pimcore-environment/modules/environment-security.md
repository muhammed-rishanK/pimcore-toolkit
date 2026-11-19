# Environment security

## Purpose and scope
Generate, store, use and hand over credentials for a new environment without exposing them, and lock down the files that hold them. Covers the secrets file, the compose override, git-ignore rules, file permissions, retrieval by the user, rotation and cleanup.

**Use when:** every install, `--repair` that touches credentials, and any time a secret might leak.
**Do not use when:** never skipped for an install.

## Inspect
- Is the project a git repository? Does `.gitignore` already cover `.pimcore-setup/`, `config/local/`, `docker-compose.override.yaml`, `.env.local`, `var/`?
- Does `.pimcore-setup/secrets.env` already exist? If so, reuse it; never regenerate over it (the database volume may already use those values).

## Workflow
1. **Generate**: `bash "$SETUP_SCRIPTS/gen-secrets.sh" <project> [--compose] [--db-name <n>] [--db-user <u>] [--admin-user <a>]` (PowerShell: `gen-secrets.ps1`). It:
   - uses `/dev/urandom` (or `openssl rand`; PowerShell: `RandomNumberGenerator`) for 24+ character passwords from a safe alphabet, and a random admin user name (`admin_<6 random chars>`) unless one is given;
   - writes `.pimcore-setup/secrets.env` with mode 600 (folder 700), keys: `PIMCORE_INSTALL_ADMIN_USERNAME`, `PIMCORE_INSTALL_ADMIN_PASSWORD`, `PIMCORE_INSTALL_MYSQL_HOST_SOCKET`, `PIMCORE_INSTALL_MYSQL_PORT`, `PIMCORE_INSTALL_MYSQL_DATABASE`, `PIMCORE_INSTALL_MYSQL_USERNAME`, `PIMCORE_INSTALL_MYSQL_PASSWORD`, `DB_ROOT_PASSWORD`;
   - with `--compose`, writes `docker-compose.override.yaml` (mode 600) setting the database service's root password, database, user and password, and the uid:gid for PHP services on Linux;
   - adds the ignore rules to `.gitignore` (creates it if missing);
   - refuses to overwrite an existing secrets file or override and exits non-zero;
   - prints only file paths and key names, never values.
2. **Use**: load values inside a subshell from the file (`set -a; . file; set +a`) or pipe the file to stdin of the container command. Never place a value in an argument.
3. **Hand over**: tell the user where the admin credentials are and how to read them themselves:
   - Linux, macOS, WSL2: `grep ADMIN .pimcore-setup/secrets.env`
   - PowerShell: `Select-String ADMIN .pimcore-setup\secrets.env`
   Suggest moving them to a password manager and changing the admin password after first login.
4. **Verify**: `git check-ignore -v .pimcore-setup/secrets.env config/local/database.yaml docker-compose.override.yaml` (if git exists) and `ls -l` / `icacls` for permissions.
5. **Scan output**: before showing logs, filter them: no line that contains a value from the secrets file. The health-check script does this itself.
6. **Rotate** (on request): admin password via `bin/console pimcore:user:reset-password <user>` is interactive and prints nothing secret on the command line; DB password change needs `ALTER USER`, an update of `config/local/database.yaml` and of `secrets.env`; plan it and get approval.

## Best practices
- Owner-only permissions on Linux and macOS; on Windows, `icacls` to remove inherited access for other users (the PowerShell script does this).
- Keep secrets out of shell history: no `export X=...` lines typed in an interactive shell.
- Bind published ports to `127.0.0.1` where the compose file allows it, so the dev stack is not reachable from the network.

## Common mistakes
- Using the default skeleton credentials because "it is only local".
- Printing `cat secrets.env` to check it worked.
- Committing `docker-compose.override.yaml`.
- Regenerating secrets after the DB volume was created, which locks the app out.

## Version notes
The installer env var names are those read by `pimcore-install` in Pimcore 10 and 11 (`PIMCORE_INSTALL_` plus the option name). Confirm with `--help` on other versions.

## Example
`gen-secrets.sh ~/projects/acme-pim --compose` printed:
```
created .pimcore-setup/secrets.env (600) keys: PIMCORE_INSTALL_ADMIN_USERNAME ... DB_ROOT_PASSWORD
created docker-compose.override.yaml (600)
updated .gitignore (+4 rules)
```

## Validation checklist
- [ ] Secrets random, not default, not printed.
- [ ] Files owner-only and git-ignored.
- [ ] User told how to read them, not the values.

## Expected output
Paths of secret files, permission and ignore status, the retrieval command, rotation advice.
