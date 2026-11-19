# Pimcore architecture

## Purpose and scope
How a Pimcore application is put together and where new code belongs: kernel and bundles, service container, configuration layout, events, Messenger, the data layer and the admin UI. Use it to place a change correctly and to read an unfamiliar project quickly.

**Use when:** designing a feature, deciding where code lives, reviewing structure, onboarding to a project.
**Do not use when:** you only need the API of one feature; go to the specific module (object lifecycle, admin UI, integration).

## Inspect the project first
- `composer.lock`: `pimcore/pimcore` version and every `pimcore/*` package.
- `src/Kernel.php` and `config/bundles.php`: which bundles are enabled. In Pimcore 11 many features are separate bundles that must be listed here.
- `config/`: `services.yaml`, `packages/*.yaml`, `config.yaml` (or `pimcore.yaml`), `routes*.yaml`, `security.yaml`, workflow files.
- `src/` layout and any `bundles/` directory with project bundles; each bundle's `Resources/config` or `config`.
- `var/classes/` (class definitions), `var/config/` (settings stored as files in 11, for example custom layouts, when the storage is configured as files).
- Messenger transports and routing: `config/packages/messenger.yaml` and the bundle config.

## Workflow
1. **Find the extension point** that matches the need:
   - React to data changes: event subscriber on `DataObjectEvents`, `AssetEvents` or `DocumentEvents`.
   - Change admin behaviour: admin events (`AdminEvents` in the admin bundle) or admin JS.
   - Heavy or external work: dispatch a Messenger message and handle it in a handler.
   - Scheduled work: a console command run by cron, or a Messenger scheduled task if the project uses that.
   - New endpoint: a controller (thin) calling a service.
   - Reusable feature set: a bundle, only when it is shared or large.
2. **Place the code** where the project already keeps that kind of code. Match namespace and directory conventions.
3. **Wire it** the way the project does: autowiring and autoconfigure in `services.yaml`, explicit service definitions, tags (`kernel.event_subscriber`, `messenger.message_handler`, `console.command`) or PHP attributes (`#[AsMessageHandler]`, `#[AsCommand]`, `#[AsEventListener]`) when the Symfony version supports them and the project uses them.
4. **Check config storage**: in Pimcore 11 some settings (custom layouts, image thumbnails, DataHub configs, perspectives) can be stored in `var/config` files or the settings store, depending on `pimcore.config_location`. Know which before editing.
5. **Confirm the container** after wiring: `bin/console debug:container <id>`, `bin/console debug:event-dispatcher <event>`, `bin/console debug:router <name>`.

## Best practices
- Thin controllers and commands; logic in services.
- Constructor injection; no `\Pimcore::getContainer()` or static service lookups in new code unless the project does it and there is no alternative.
- One responsibility per subscriber; check the class or object type early and return.
- Keep project config in `config/`; do not edit files in `vendor/`.
- Use Symfony components (Validator, Serializer, HttpClient, Lock, Messenger) before writing your own.

## Common mistakes
- Putting business logic in admin JS or controllers, where imports and APIs bypass it.
- Subscribers that run for every class and every save, slowing the whole system.
- A new bundle for a single service.
- Editing generated files (`var/classes/DataObject/*.php`) instead of definitions.
- Forgetting that console, Messenger workers and web requests all trigger the same events.

## Version notes
| Area | Pimcore 10 | Pimcore 11 | Later (12, year-based releases) |
|---|---|---|---|
| Symfony | 5.4 | 6.2+, 6.4 LTS | check release notes |
| Admin UI | in core | `pimcore/admin-ui-classic-bundle` | Pimcore Studio; check if classic UI is still available for the release |
| Optional features | in core | separate bundles to enable in `config/bundles.php` | check docs |
| Config storage | mostly files and DB | configurable locations (`config_location`) | check docs |
Never assume a newer layout; read the installed `vendor/pimcore/pimcore` code.

## Example
"Send a notification when a Product is published": event subscriber on `DataObjectEvents::POST_UPDATE`, return early unless the object is a Product and became published, dispatch a Messenger message; the handler sends the mail. No controller, no admin JS.

## Validation checklist
- [ ] Extension point chosen with a reason, matching the project's existing pattern.
- [ ] Wiring confirmed with `debug:container` or `debug:event-dispatcher`.
- [ ] No vendor or generated files edited.
- [ ] Every API used exists in the installed version.

## Expected output
Where the change lives (paths), the extension points used, the wiring, and the commands that confirm it is registered.
