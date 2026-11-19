# Testing and validation

## Purpose and scope
Proving that a change works and did not break anything: unit, integration and functional tests in the project's framework (Codeception or PHPUnit, Playwright where present), command and import checks, API checks, test data handling, and the validation tiers every change goes through.

**Use when:** after any code change; when asked to write tests; before a review or a release.
**Do not use when:** never skipped. If a tier cannot run, say so and why.

## Inspect the project first
- Frameworks: `codeception.yml`, `tests/*.suite.yml`, `phpunit.xml(.dist)`, `playwright.config.*`, `package.json` scripts.
- Test helpers and bootstrap: `tests/Support/`, `tests/bootstrap.php`, Pimcore test cases in `vendor/pimcore/pimcore/lib/Test/` (`KernelTestCase`, `WebTestCase` in Pimcore 11; verify).
- Test database setup: a separate DB in `.env.test` or the CI config. Never run tests that write against the development or production database unless the project is built for it.
- How tests run in CI (`.gitlab-ci.yml`, `.github/workflows/`) and in Docker (`docker compose exec php vendor/bin/...`).
- Static tools: PHPStan, Psalm, PHP-CS-Fixer, PHP_CodeSniffer, ECS.

## Validation tiers
| Tier | What | When |
|---|---|---|
| 1 | `php -l` on changed files, style tool in check mode, static analysis on changed paths, unit tests for the area | every change |
| 2 | `bin/console cache:clear` then `bin/console lint:container` (if available) and `lint:yaml config/`, `debug:container`/`debug:event-dispatcher` for new wiring, integration and functional tests | changes to config, wiring, events, classes |
| 3 | command dry-run on sample data, API calls against local, admin UI checks as admin and a restricted role, Playwright specs if the project has them | user-visible behaviour, imports, integrations |

## Workflow
1. **Map each acceptance criterion to a test** (or a documented manual check when a test is not practical).
2. **Unit tests** for services, mappers, validators and calculators. Mock repositories and clients. Avoid touching the database.
3. **Integration tests** for code that needs the kernel or Pimcore models: use the project's kernel test case, create objects under a dedicated test folder, delete them in teardown.
4. **Command tests** with Symfony `CommandTester`: options, exit codes, output summary, dry-run makes no changes.
5. **API tests**: functional test client or Playwright `request`; status codes, payload shape, permission failures.
6. **Run** the new tests and the existing suite for the area. Capture output to a file for long runs.
7. **Report** commands and results honestly, including skipped tiers and why.

## Best practices
- Test behaviour, not implementation details.
- Each test creates and removes its own data; never depend on ids from a shared database.
- Name tests after the behaviour (`testRejectsSkuChangeWhenApproved`).
- Keep tests fast; push slow end-to-end checks to the tiers that need them.

## Common mistakes
- Tests that pass because they assert nothing meaningful.
- Writing to the development database and leaving test objects behind.
- Changing a test to match buggy behaviour.
- Claiming checks ran when the container or DB was not reachable.

## Version notes
- Codeception 5 and PHPUnit 10+ changed configuration and attributes; follow what the project has installed.
- Pimcore's own test helpers changed between 10 and 11; check `vendor/pimcore/pimcore/lib/Test`.

## Example
Criterion: "Editors cannot change `sku` after approval."
- Unit: `SkuLockValidatorTest` with approved and draft objects (mocked workflow state), admin and editor users.
- Integration: create a Product in a test folder, move to approved, attempt to save a changed SKU as editor, assert exception, clean up.
- Manual: in admin as editor, field is read-only in the approved place.

## Validation checklist
- [ ] Every criterion mapped to a test or a manual check.
- [ ] Tier 1 run on changed files; tiers 2 and 3 when they apply.
- [ ] Test data created and removed by the tests.
- [ ] Results reported with commands; skipped tiers explained.

## Expected output
Criterion to test map, test files, commands run with pass/fail/skip counts, failures with causes, checks not run with reasons, manual checks still needed.
