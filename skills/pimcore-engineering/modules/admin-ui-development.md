# Admin UI development

## Purpose and scope
Changing what editors see and do in the Pimcore admin: admin JavaScript extensions, admin events that shape data sent to or received from the UI, custom layouts, grid configuration, object editor buttons and tabs, and the difference between the classic admin UI and Pimcore Studio.

**Use when:** adding a button, panel or tab; changing how a field is shown; reacting to object open or save in the UI; adjusting data sent to the editor; editing custom layouts.
**Do not use when:** the rule must also hold for imports, APIs or commands. Enforce it in PHP (event subscriber or validation) and use the UI only as a convenience. Also not for Pimcore Studio projects: use `studio-ui-development.md` and `studio-backend-extension.md`.

## Inspect the project first
- Which admin UI the project runs: `pimcore/admin-ui-classic-bundle` in `composer.lock` (Pimcore 11), core admin (Pimcore 10), or Pimcore Studio packages (later releases).
- How the project registers admin JS and CSS: a bundle implementing `Pimcore\Extension\Bundle\PimcoreBundleAdminClassicInterface` with `getJsPaths()`/`getCssPaths()` (Pimcore 11), `getJsPaths()` on the bundle (Pimcore 10), or event listeners on the admin asset events. Find existing files under `public/js/` or `Resources/public/js/` in project bundles.
- Existing admin event subscribers: grep for `AdminEvents::`.
- Custom layouts: `var/config/object_custom_layouts/` (Pimcore 11 file storage) or the database, and which roles use which layout.
- Workflow field permissions, which also change field visibility and editability.

## Workflow
1. **Decide the layer**: rule or validation, put it in PHP. Presentation only, use a custom layout or admin JS. Data shaping for the editor, use an admin event.
2. **Admin events (PHP)**: subscribe to the event in `Pimcore\Bundle\AdminBundle\Event\AdminEvents` (Pimcore 11) that matches, for example `OBJECT_GET_PRE_SEND_DATA` to adjust data sent to the object editor. Check the event constant and its arguments in `vendor/`.
3. **Admin JS (classic UI)**: listen to the documented JS events, for example `document.addEventListener(pimcore.events.postOpenObject, (e) => { ... })` in Pimcore 11. Check `vendor/pimcore/admin-ui-classic-bundle/public/js/pimcore/events.js` for the available event names. The old plugin broker of Pimcore 10 is deprecated in 11.
4. **Register** the JS or CSS file the way the project already does, then run `bin/console assets:install` (with the project's flags) and clear caches.
5. **Custom layouts**: change them in the admin and commit the resulting files, or edit the stored file carefully. Field names must exist in the class; a layout only hides or reorders, it does not protect data.
6. **Test** in the browser with an admin and with a restricted role. Check the browser console for errors.

## Best practices
- Keep admin JS small; call admin endpoints (controllers with permission checks) for logic.
- Namespace your JS (`pimcore.plugin.<project>...` or a module pattern) and avoid globals.
- Translate labels with the admin translation system rather than hard-coding text.
- Check the user's permissions in the PHP endpoint, never only in JS.

## Common mistakes
- Enforcing a rule only in JS: imports, APIs and scripts bypass it.
- Using a custom layout to "secure" a field.
- Forgetting `assets:install` and the browser cache after changing JS.
- Copying Pimcore 10 plugin broker code into Pimcore 11.
- Building new extensions on the classic UI for a project that will move to 2026.x: they must be rewritten for Studio. Check `platform-2026-upgrade.md` first.

## Version notes
- Pimcore 10: admin UI in core; JS plugins through the plugin broker.
- Pimcore 11: classic admin UI in `pimcore/admin-ui-classic-bundle`; JS events through `pimcore.events.*` and `document.addEventListener`; admin PHP events in `Pimcore\Bundle\AdminBundle\Event\AdminEvents`.
- 12.x and 2025.4 (LTS): classic UI; Pimcore Studio can run beside it. 2025.4 is the last release with the classic UI.
- 2026.1 and later: Pimcore Studio (React) is the only admin UI. The classic UI, its ExtJS files, classic admin controllers and `PimcoreBundleAdminClassicInterface` implementations are removed. Use `studio-ui-development.md` and `studio-backend-extension.md`, and plan the move with `platform-2026-upgrade.md`. Facts and sources: `references/pimcore-versions.md`.

## Example
Show a read-only warning banner when an editor opens a Product that is locked by an integration:
- PHP: `OBJECT_GET_PRE_SEND_DATA` subscriber adds `lockedByIntegration: true` to the response data for Product objects that have the lock flag.
- JS: on `pimcore.events.postOpenObject`, if the object data has the flag, add a message to the object toolbar.
- PHP save guard: `PRE_UPDATE` subscriber rejects changes to locked fields by non-integration users. The UI is a convenience; the guard is the rule.

## Validation checklist
- [ ] Rules enforced in PHP, not only UI.
- [ ] Event names verified in installed `vendor/`.
- [ ] Assets installed, caches cleared, browser console clean.
- [ ] Checked as admin and as a restricted role.

## Expected output
Files changed, how the extension is registered, events used, the assets and cache commands, and the manual UI checks performed with their result.
