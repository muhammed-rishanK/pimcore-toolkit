# Upgrade and migration

## Purpose and scope
Planning Pimcore, PHP, Symfony and bundle upgrades, and handling deprecations and breaking changes: compatibility analysis, the order of steps, data and schema migrations, testing and rollback. Planning only; executing a major upgrade needs explicit user approval.

**Use when:** the user asks about upgrading, a dependency needs a newer Pimcore, a deprecation warning must be cleared, or a new install needs a version decision.
**Do not use when:** the task is a normal feature within the current version.

## Inspect the project first
- `composer.lock`: every `pimcore/*` package, `symfony/*` versions, Doctrine, third-party bundles and their constraints.
- `composer.json`: platform PHP, constraints, scripts, repositories (private bundles).
- The runtime: PHP version in the Docker image or server, database server and version, Redis, search engine.
- `config/bundles.php` and the config tree for removed or renamed keys.
- Custom code using APIs known to change between versions (grep for deprecated classes, the admin bundle namespace, static helpers).
- Deprecation logs (`var/log/*deprecation*` or the profiler) if available.

## Workflow
1. **Current state** table: package, installed version, constraint.
2. **Target**: the user's target or a recommendation (supported, maintained, licence). Read the official system requirements for the target and the upgrade notes for every version in between (docs.pimcore.com, the GitHub release notes). Cite them.
3. **Breaking changes**: for each item in the upgrade notes, grep the project to see if it applies and list the files.
4. **Dependencies**: for each third-party bundle, find a version that supports the target (`composer why-not pimcore/pimcore <target>` explains blockers without changing anything).
5. **Phases** that each leave the project working:
   - fix deprecations on the current version;
   - upgrade PHP within the current Pimcore's support range;
   - upgrade Pimcore (and Symfony with it);
   - enable or replace moved bundles;
   - run migrations (`doctrine:migrations:migrate` after a backup when the whole upgrade is intended; otherwise `doctrine:migrations:execute '<FQCN>' --up` per version), rebuild classes, clear caches, restart workers;
   - clean up compatibility layers.
6. **Rollback** per phase: git revert, database backup taken before migrations, file and asset backup, previous Docker image.
7. **Validation**: full test suite, smoke checks in the admin, imports, exports, integrations, performance comparison.

## Version notes

### Pimcore 10 to 11 (verify against the official upgrade guide)
- Admin UI moved to `pimcore/admin-ui-classic-bundle`; several features moved to separate bundles that must be required and enabled (for example application logger, custom reports, glossary, SEO, static routes, TinyMCE, UUID, web-to-print, word export, XLIFF, simple backend search).
- `pimcore/compatibility-bridge-v10` exists to ease the move of some removed APIs.
- Symfony 6.x: authenticator-based security only, removed deprecated APIs.
- Some settings moved to config files or the settings store with configurable storage locations.

### Later releases (verify)
Pimcore 12 and the year-based releases introduce Pimcore Studio and licence changes, and raise PHP and Symfony requirements. Read the official requirements; do not assume the PHP or Symfony version from memory.

## Best practices
- One phase per branch or merge request; each phase deployable.
- Upgrade on a copy of production data before production.
- Keep a list of every manual step for the release runbook.

## Common mistakes
- Jumping several majors in one step.
- Upgrading Pimcore without upgrading the PHP image.
- Running migrations without a database backup.
- Forgetting third-party bundles that block the upgrade.
- Assuming docs for the newest version apply to the target version.

## Example
Pimcore 10.6 to 11.x: phase 1 clear deprecations on 10.6, PHP 8.1; phase 2 require `pimcore/pimcore:^11`, `pimcore/admin-ui-classic-bundle`, the needed feature bundles, update third-party bundles, update config and security; phase 3 migrations, rebuild, assets, caches, workers; phase 4 remove the compatibility bridge after code is updated.

## Validation checklist
- [ ] Current and target versions with sources.
- [ ] Every breaking change mapped to project files or marked not applicable.
- [ ] Dependency blockers listed.
- [ ] Phases with rollback and validation.
- [ ] Nothing executed without approval.

## Expected output
Current state, target, mandatory changes, optional improvements, dependency compatibility, phased plan with rollback, validation plan, sources.
