# Security best practices

## Purpose and scope
Keeping a Pimcore application and its data safe: authentication, authorisation (admin permissions, roles, workspaces, element permissions), API security, input validation, SQL and output injection, file handling, secrets, logging and personal data.

**Use when:** adding an endpoint, a permission rule, a file upload or download, an integration credential, raw SQL, or reviewing any change.
**Do not use when:** never skip it; at minimum run the review checklist below on every change.

## Inspect the project first
- `config/packages/security.yaml`: firewalls (admin firewall, API firewalls), access control, user providers.
- How existing controllers check permissions: admin controller helpers (`checkPermission`, `checkActionPermission`), `isGranted`, element `isAllowed()`.
- Roles and permission keys used in the project (grep `isAllowed(`, `checkPermission(`, `getPermission`).
- Where secrets come from: `.env` (committed defaults only), `.env.local` (not committed), Symfony secrets vault, Docker env.
- Raw SQL: grep for `->executeQuery(`, `->fetchAll`, `Db::get()`, string-built conditions.
- File handling: uploads, downloads, paths built from input.

## Workflow
1. **Authenticate** every non-public endpoint. Admin endpoints sit behind the admin firewall; API endpoints use API keys, tokens or the project's auth. DataHub configs have their own API key and permissions.
2. **Authorise**: check the user's permission for the action and the element. In the admin, users have permissions (system features), workspaces (folders they can view, save, publish, delete, rename, create) and per-element rules. Check them in PHP for every action, not only in the UI.
3. **Validate input**: types, lengths, allowed values, ids that the user may access. Use the Symfony Validator or explicit checks.
4. **SQL**: always use parameters (`setCondition('sku = ?', [$sku])`, `executeQuery($sql, $params)`). Quote identifiers you cannot parameterise with the DBAL quote helpers, and only from an allow-list.
5. **Output**: escape in Twig (default auto-escape); do not mark user input as safe; set correct content types for JSON and downloads.
6. **Files**: never build paths from raw input; resolve under a fixed base directory and reject `..`; check MIME and extension for uploads; store outside the web root unless public.
7. **Secrets**: from env vars or the secrets vault; never in code, committed config, logs, exceptions, test fixtures or screenshots.
8. **Logging and personal data**: log ids, not names, emails, addresses or tokens; follow the project's data retention rules.
9. **Dependencies**: run `composer audit` when dependencies change and report advisories.

## Best practices
- Deny by default; grant the smallest permission needed.
- Separate API users with their own roles; no shared admin accounts for integrations.
- Rate-limit public and token-based endpoints when the project has the RateLimiter.
- Keep `APP_DEBUG` and the profiler off in production.

## Common mistakes
- Admin endpoint without a permission check because "only admins see the button".
- Concatenating user input into listing conditions.
- Custom layouts or hidden fields treated as access control.
- Credentials in `.env` committed to git, in Docker compose files, or in command lines visible in process lists and shell history.
- Error responses that leak stack traces or SQL.

## Version notes
- Pimcore 11 admin controllers live in `pimcore/admin-ui-classic-bundle` (`Pimcore\Bundle\AdminBundle\...`); the permission helpers `checkPermission()` and `checkPermissionsHasOneOf()` are on `Pimcore\Controller\UserAwareController` in core. Pimcore 10 had everything in core. Grep `function checkPermission` in `vendor/pimcore` to confirm for the installed version.
- Symfony security configuration changed in 6.x (authenticator system only). Check the installed version before copying examples.

## Example
Endpoint to export product data for a role:
- Route under the admin firewall; controller calls `$this->checkPermission('objects')` (from `UserAwareController` in Pimcore 11) and checks `$product->isAllowed('view', $user)` per object.
- Input `ids` validated as integers, max 500.
- Listing condition uses `id IN (?)` with a parameter array (check DBAL array parameter support in the installed version) or a validated integer list.

## Validation checklist
- [ ] Every new endpoint authenticated and authorised in PHP.
- [ ] Inputs validated; SQL parameterised; output escaped.
- [ ] File paths safe; uploads checked.
- [ ] No secrets or personal data in code, config, logs or tests.
- [ ] `composer audit` run when dependencies changed.

## Expected output
Security checks done, findings by severity with `path:line`, fixes applied or recommended, and anything that needs an owner decision (for example a new role).
