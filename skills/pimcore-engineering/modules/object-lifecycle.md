# Object lifecycle

## Purpose and scope
How Pimcore DataObjects are created, loaded, saved, published, versioned, deleted and moved through workflows, and which events, permissions and inheritance rules apply at each step. The first place to look for "my object does not save", "my value disappears" and "this listener runs twice".

**Use when:** writing code that creates or saves objects; debugging save, publish or version problems; adding event subscribers; working with workflows or element permissions.
**Do not use when:** the issue is purely a query or listing performance problem (`performance-optimization.md`).

## Inspect the project first
- Subscribers and listeners on data object events: `bin/console debug:event-dispatcher | grep -i dataobject`, and grep `DataObjectEvents::` in `src/` and bundles.
- Workflows: config files and `bin/console debug:config pimcore workflows` (or the project's workflow file); which places set field permissions.
- Class settings: inheritance, variants, mandatory fields, validation.
- Versioning settings in config (`pimcore.objects.versions` steps or days).
- Code that calls `save()` in loops or in listeners.

## Workflow
1. **Map the path** of the operation: who triggers it (admin, API, import, command, Messenger worker), which methods run, which events fire.
2. **Events on save** (Pimcore 10 and 11): `PRE_ADD`/`POST_ADD` for new objects, `PRE_UPDATE`/`POST_UPDATE` for updates, `POST_UPDATE_FAILURE` and `POST_ADD_FAILURE` when saving throws, `PRE_DELETE`/`POST_DELETE`. Constants live in `Pimcore\Event\DataObjectEvents`. The event object is `Pimcore\Event\Model\DataObjectEvent`; read its arguments (for example whether the save is an auto-save draft) in the installed version.
3. **Publishing**: `setPublished(true)` then `save()`. Unpublished objects are hidden from listings and getters by default in frontend context; admin and CLI context can differ. Use the listing or `DataObject::setHideUnpublished()` controls explicitly where it matters.
4. **Versions**: each save creates a version (subject to config). Bulk jobs can disable versions with `Pimcore\Model\Version::disable()` and must re-enable them with `Version::enable()` in a `finally` block. Only do this when the business agrees that history is not needed for that run.
5. **Inheritance**: getters return inherited values when inheritance is enabled for the class and the context. Use `DataObject\Service::useInheritedValues(bool, callable)` to run code with a known setting. Saving a child stores only its own values; a value equal to the parent may be stored as empty.
6. **Validation**: mandatory fields and validation run on publish of the object; unpublished saves may skip mandatory checks. Check the version's behaviour before relying on it.
7. **Workflows**: transitions change places and may set field permissions and run listeners (`workflow.<name>.transition.*` and Pimcore's workflow events). Applying a transition from code goes through the workflow registry, not a direct field write.
8. **Permissions**: element permissions and user workspaces apply in the admin and in code that checks them (`$element->isAllowed('save', $user)`); CLI and workers run without a user unless your code sets one.

## Best practices
- Make `PRE_UPDATE` listeners change the object in place and not call `save()`.
- In `POST_UPDATE`, dispatch a Messenger message for heavy work; do not save other objects synchronously in large numbers.
- Guard recursion with a static flag or a dedicated service state when a listener must save.
- Return early in listeners for other classes and for auto-save drafts if your logic should not run on them.
- Use `getById($id, ['force' => true])` (check the signature for the installed version) when you must bypass the cache after an external change.

## Common mistakes
- Listener calls `save()` on the same object: recursion, duplicate versions.
- Bulk import with versions on: database growth and slow runs.
- Code expects inherited values but runs with inheritance off (or the reverse).
- Treating `POST_UPDATE` as "data committed and visible to other processes" in code paths with open transactions.
- Applying workflow places by writing the state field directly.
- Forgetting that imports and workers have no admin user, so permission-based logic behaves differently.

## Version notes
- Event constants and `DataObjectEvent` arguments: check `vendor/pimcore/pimcore/lib/Event/DataObjectEvents.php` and the event class for the installed version.
- Pimcore 11 changed some getter defaults and removed deprecated static setters; prefer `Service::useInheritedValues()` over global toggles.
- Workflow configuration keys changed between major versions; read the installed docs.

## Example
Bug: "Saving a Product resets `status` to draft."
Path: admin save, `PRE_UPDATE` subscriber `ProductStatusSubscriber` sets status to draft when price changed. The admin sends the full object, so price "changes" from inherited to explicit on variants. Fix: compare with the previous version or the parent value before resetting, and skip when the object is a variant with inherited price.

## Validation checklist
- [ ] Operation path and every listener on it identified.
- [ ] Recursion, auto-save and other-class cases handled.
- [ ] Versions, inheritance and publish state behaviour stated.
- [ ] Workflow and permission effects checked.

## Expected output
The path (trigger, methods, events, listeners), the behaviour at each step, the problem or change, and the checks that prove it.
