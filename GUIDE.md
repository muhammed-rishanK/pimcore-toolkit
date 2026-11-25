# Pimcore Engineering Toolkit: user guide

This guide walks through the toolkit step by step. The README has the reference tables; this page is the "how do I use it" version.

## 1. Install once

In Claude Code:

```text
/plugin marketplace add muhammed-rishanK/pimcore-toolkit
/plugin install pimcore-toolkit@pimcore-toolkit
```

Turn on automatic updates so new versions arrive without a manual step:

- `/plugin`, then Marketplaces, `pimcore-toolkit`, Enable auto-update, or
- in a terminal:

```bash
bash ~/.claude/plugins/marketplaces/pimcore-toolkit/skills/pimcore/scripts/enable-auto-update.sh
```

Run it again with `--check` to see the status. A new version is applied after `/reload-plugins` or the next start of Claude Code. If your setup blocks updates (`DISABLE_AUTOUPDATER` or `DISABLE_UPDATES` is set), add `FORCE_AUTOUPDATE_PLUGINS=1` to your environment.

## 2. The four commands

| Command | Use it for | Changes code? |
|---|---|---|
| `/pimcore <request>` | any development task: explain, build, debug, model data, integrate, test, review, upgrade | yes, when the task needs it |
| `/pimcore-setup [name]` | build a new Pimcore environment, or `--check` / `--repair` an existing one | creates the environment |
| `/pimcore-review` | review the current changes, or the whole codebase with `--all` | no |
| `/pimcore-doctor` | a health and best-practice audit of a project | no |

## 3. A new project

1. Open an empty folder in Claude Code.
2. Run `/pimcore-setup my-shop`.
3. It detects your OS, picks Docker when it can, and installs Docker itself if it is missing.
   - On Linux it may need your `sudo` password. A terminal tab opens with the command; type the password there. The plugin never sees it.
   - On Windows it may show the administrator prompt once and ask for a restart.
4. It creates the project, random database passwords, starts the services, installs Pimcore and runs five health checks.
5. The report lists the URLs and the admin login (`admin` / `admin` for local development; use `--secure-admin` for a random one).

## 4. An existing project

```text
/pimcore-doctor              # what is healthy, what needs attention, and the fix for each
/pimcore-setup --check       # does the environment run
/pimcore-setup --repair      # fix what is broken, safe fixes only
```

`/pimcore-doctor` checks the lock file, PHP platform, secrets in git, `.gitignore`, class definitions, debug settings, workers, tooling, CI, upgrade impact and the auto-update status. Add `--online` to also check composer security advisories.

## 5. Daily development

Describe what you need in plain words:

```text
/pimcore add a read-only lastSyncedAt date on the Product edit page
/pimcore saving a Product fails with "Integrity constraint violation"
```

The command reads the project's version and `CLAUDE.md`, starts only the agents the task needs, asks before risky steps (class changes on existing data, destructive steps, new dependencies), validates the work and reports. It never commits or pushes.

## 6. Code review

Run it yourself:

```text
/pimcore-review                      # uncommitted changes and everything they affect
/pimcore-review --staged             # only what is staged
/pimcore-review --base production    # everything since the branch left production
/pimcore-review --all                # the whole first-party codebase
/pimcore-review --focus security     # weight the review (security, performance, data, upgrade)
```

Each finding looks like this:

```text
### 1. [HIGH] SQL built from user input
File: `src/Service/ProductExporter.php:41`
    40     $list = new Product\Listing();
    41     $list->setCondition("sku = '" . $sku . "'");   <- issue
Why: a SKU with a quote breaks the query; a crafted SKU reads other rows
Fix: $list->setCondition('sku = ?', [$sku]);
Test plan: a unit test with the SKU "a'b", then the export command on a test object
```

Reply `fix 1 3` to have the listed findings fixed.

### Automatic review

When Claude changes code in a Pimcore project, the plugin asks for this review before Claude finishes its reply. It runs once per new set of changes and never loops. Turn it off:

```bash
export PIMCORE_AUTO_REVIEW=0            # everywhere
git config pimcore.autoReview false     # one project
```

## 7. Upgrades

```text
/pimcore plan an upgrade from Pimcore 11 to 2026
```

The upgrade specialist starts from the impact scan, which lists every affected `file:line` per breaking change:

```bash
bash skills/pimcore/scripts/scan-platform-impact.sh <project> --to 2026
```

## 8. Updating by hand

```bash
claude plugin marketplace update pimcore-toolkit
claude plugin update pimcore-toolkit@pimcore-toolkit
```

Then `/reload-plugins`. `CHANGELOG.md` lists what changed.

## 9. Problems

Open an issue at https://github.com/muhammed-rishanK/pimcore-toolkit/issues with the plugin version, OS, Pimcore and PHP versions, the command and what happened. Remove passwords and private names first.
