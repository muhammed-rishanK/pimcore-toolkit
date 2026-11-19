# Changelog

## 0.1.1

- `/pimcore-setup` now builds a local developer setup by default: admin login `admin` / `admin`, random database passwords, and every published port bound to `127.0.0.1`. If a port cannot bind to localhost, it falls back to a random login. Use `--secure-admin` for a random admin name and password. Never use the dev login on a server or shared host.
- `gen-secrets.sh` and `gen-secrets.ps1` gained `--dev-login` / `-DevLogin`.
- Autonomous mode is the default: the command decides with the recommended option and lists each choice under "Decisions made". `--ask` restores the prompts.
- `--plan` prints the installable Pimcore versions (PHP needed, product key, notes) and what happens in each situation, then stops.
- Product-key handling: a version that may need a key is never registered for and never bypassed; the row shows `unknown` unless confirmed.
- `detect-project.sh` falls back to the `pimcore/pimcore` PHP range when the skeleton has none.
- Agent handbacks must list "Commands run".

## 0.1.0

- First release: `/pimcore` and `/pimcore-setup`, 9 agents, 15 development modules, 8 setup modules.
