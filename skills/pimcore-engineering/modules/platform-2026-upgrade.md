# Platform 2026 upgrade

## Purpose and scope
Planning the move of a Pimcore 11, 12.x or 2025.x project to the year-based platform releases (2026.x), where Pimcore Studio is the only admin UI. Also covers the choice to stay on 2025.4 LTS. This module is a checklist built from the official 2026.1 release notes and the "Version 12 to Version 2026" upgrade page. Planning only; executing a major upgrade needs the user's explicit approval.

**Use when:** the target is 2026.x or 2025.4, the project must leave the Classic UI, or the question is which line to be on.
**Do not use when:** the upgrade stays inside one numbered line (use `upgrade-migration.md`).

## Inspect the project first
Read `references/pimcore-versions.md` in the toolkit first. Then, in the project:
- `composer.lock`: `pimcore/pimcore`, `symfony/framework-bundle`, every `pimcore/*` package, and whether `pimcore/admin-ui-classic-bundle` or the Studio packages are present.
- `composer.json`: PHP constraint and `config.platform.php`, explicit `symfony/*` 6.x constraints.
- The runtime: PHP version in the Docker image or server, database collation (`SHOW VARIABLES LIKE 'collation%'`), Messenger transport config.
- `config/bundles.php` for the bundles removed in 2026.1 (list below).
- Custom code that ships ExtJS, implements `PimcoreBundleAdminClassicInterface` or uses `BundleAdminClassicTrait`, subscribes to classic admin events, or has classic admin controllers.
- Code using `Symfony\Component\Templating\EngineInterface`, the `pimcore.templating.engine.delegating` service or `Pimcore\Templating\TwigDefaultDelegatingEngine`.
- Deployment scripts that call `pimcore-install` (they break, see below).
- Data Hub configs of type File Export, Productsup, Simple REST or Webhooks, E-Commerce Framework tracking code, Personalization GeoIP code.

## Workflow
1. **Current state** table and the target line, with the reason (see the decision table in `references/pimcore-versions.md`). If the project depends on Classic UI customisations and needs a long window, 2025.4 LTS (support stated as three years from the 2025-12-09 release) is a valid target. Say that LTS covers platform functionality, not Studio.
2. **Breaking changes to check** (all from the 2026.1 notes unless marked):
   | Change | What to check |
   |---|---|
   | Classic UI removed | all ExtJS, classic admin controllers, `PimcoreBundleAdminClassicInterface` and `BundleAdminClassicTrait` implementations, legacy admin listeners: rewrite for Studio (`studio-ui-development.md`, `studio-backend-extension.md`) |
   | PHP 8.3 removed | PHP 8.4 or 8.5 required: update the image, CI and `config.platform.php` |
   | Symfony 6.x removed | Symfony 7.x required (7.3 or higher per the upgrade page): update all components, test on Symfony 7, drop explicit 6.x constraints |
   | Installer redesigned | `pimcore-install` now requires `--install-profile`; automated deployment and CI pipelines that call it break; read `pimcore-install --help` for the profile names |
   | Templating removed | replace `Symfony\Component\Templating\EngineInterface` with `Twig\Environment` (upgrade page) |
   | Removed bundles | moved into Studio: Advanced Object Search, Perspective Editor, Simple Backend Search. Removed: File Explorer, Glossary, Google Marketing, Newsletter, SEO (redirects, robots.txt and sitemaps stay in core), Static Routes, System Info, Word Export, Output Data Config Toolkit, Web2Print Tools. Remove them from `composer.json` and replace what the project used |
   | Collation | all utf8mb4 tables and columns explicitly use `utf8mb4_unicode_520_ci`; check custom tables and migrations |
   | Messenger DSN | parameter `%pimcore.messenger.transport_dsn_prefix%` has a trailing separator; check each bundle's upgrade notes |
   | Data Hub | File Export, Productsup, Simple REST, Webhooks move from the tree schema to a pipeline schema; old configs still run but must be migrated by hand before editing in Studio; read-only support for the old schema ends in 2027.1.0 |
   | E-Commerce Framework | GA4 tracker replaces Universal Analytics; `formatPrice()` and `getCartValue()` return `?float`; `TrackingManagerInterface` gained methods (custom implementations must add them) |
   | Personalization | GeoIP2 library 2.x to 3.x, response structure changed |
   | Mail log folders | layout is now `YYYY/MM/DD/<log filename>`: run `pimcore:migrate:mail-logs-folder-structure` or move files by hand (upgrade page) |
   | QuantityValue | the space between value and unit is removed in formatting; check custom code that parses it |
   For each row, grep the project and list the affected files, or mark "not applicable".
3. **Dependencies.** For each third-party bundle, find a release that supports the target (`composer why-not pimcore/pimcore <target>` explains blockers without changing anything). Bundles built on the Classic UI have no Studio version unless their vendor ships one.
4. **Phases** (the toolkit's recommended order, derived from the facts above; each phase must leave the project working):
   1. Clear deprecations on the current line; get to the newest release of the current line.
   2. Move to PHP 8.4 and Symfony 7.x while still on a line that supports them (2025.4 supports Symfony 7 beside 6.4). Remove explicit Symfony 6.x constraints.
   3. Replace `EngineInterface` with `Twig\Environment`; fix the other removed APIs.
   4. Remove the bundles that no longer exist; replace their features.
   5. Rewrite Classic UI customisations as Studio plugins and backend extensions, one feature at a time.
   6. Update CI and deployment scripts for `--install-profile` and PHP 8.4 or 8.5.
   7. Upgrade the platform, then run the migrations the safe way (see below), `classes-rebuild -c -n`, cache clear, `assets:install`, restart workers.
   8. Move Data Hub configs to the pipeline schema; migrate mail log folders.
   A project on 10.x goes to 11 first (`upgrade-migration.md`). A community guide says 10 to 12 in one step fails; it was not verified, so keep one major per phase.
5. **Migrations.** After the upgrade run `doctrine:migrations:status` and `doctrine:migrations:list`. Do not run `doctrine:migrations:migrate`. For each pending migration the user approves, print `bin/console doctrine:migrations:execute '<FQCN>' --up --no-interaction` with the class name read from the file. The 2026.1 notes say to run all migrations after the update; show the user that list and let them choose.
6. **Rollback** per phase: git revert, database backup before any migration, previous Docker image, `composer.lock` kept.
7. **Validation:** full test suite, admin smoke test in Studio as admin and restricted role, imports, exports, integrations, performance comparison.

## Best practices
- Work on a copy of production data first.
- One phase per branch; each phase deployable.
- Keep a list of every manual step for the release runbook.
- Estimate the Classic UI rewrite separately; it is usually the largest item.

## Common mistakes
- Treating the installer change as cosmetic: pipelines that call `pimcore-install` fail.
- Upgrading Pimcore before the PHP image.
- Assuming every Classic UI bundle has a Studio replacement.
- Reading the 12.x docs for a 2026 project (or the reverse).
- Claiming a licence or product key rule that the docs did not state.

## Version notes
- Everything here is from the official pages dated up to 2026-11-20 (see sources in `references/pimcore-versions.md`). The upgrade page for 2026 content sits in the 2025.4 docs tree; the latest docs may have added items. Re-read the upgrade notes for the exact target release before you plan.
- Not stated on the pages read: exact PHP range for 2025.4, end of support for 2026.x, any licence change.

## Example
Project on 12.x with custom ExtJS panels, Data Hub File Export and the Glossary bundle, target 2026.3: phase 1 and 2 (PHP 8.4, Symfony 7.3), phase 4 (replace Glossary), phase 5 (port two panels to Studio plugins plus backend endpoints), phase 6 (pipelines call `pimcore-install --install-profile <profile>`), phase 7 upgrade, phase 8 migrate the Data Hub config.

## Validation checklist
- [ ] Current and target versions with sources.
- [ ] Every row of the breaking-change table mapped to files or marked not applicable.
- [ ] Classic UI customisations listed with a Studio replacement plan.
- [ ] Dependency blockers listed.
- [ ] Phases with rollback and validation; nothing executed without approval.

## Expected output
Current state, target and reason, mandatory changes by table row, Classic UI rewrite list, dependency compatibility, phased plan with rollback, migration commands (targeted), validation plan, sources, and the items the docs do not state.
