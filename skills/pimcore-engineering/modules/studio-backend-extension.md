# Studio backend extension

## Purpose and scope
Extending the Pimcore Studio Backend (`pimcore/studio-backend-bundle`), the PHP REST layer behind Studio: custom endpoints, response enrichment through events, grid columns, filters and asset metadata adapters, plus OpenAPI registration. The pattern is always: implement an interface, tag the service, and the backend discovers it at runtime.

**Use when:** the project runs Pimcore Studio and a task needs a new API endpoint for the UI, extra attributes on an element response, a custom grid column or filter, or a custom asset metadata type.
**Do not use when:** the project runs the Classic UI (use `admin-ui-development.md`), or the task is an external integration API (use `integration-development.md`).

## Inspect the project first
- `pimcore/studio-backend-bundle` and its version in `composer.lock`.
- The config key `pimcore_studio_backend` in `config/` and in bundle config.
- Existing Studio extensions: grep for `StudioBackendBundle` and for the tags below.
- Whether the project has Classic admin controllers or admin events that this work replaces (see `platform-2026-upgrade.md`).

## Workflow
1. **Pick the extension point.**
   | Need | Extension point |
   |---|---|
   | new endpoint | controller extending `Pimcore\Bundle\StudioBackendBundle\Controller\AbstractApiController` |
   | change data before it is sent | PreResponse event, for example `Pimcore\Bundle\StudioBackendBundle\Asset\Event\PreResponse\AssetEvent` |
   | change input before a lookup | PreResolve event, for example `Pimcore\Bundle\StudioBackendBundle\Element\Event\PreResolve\ElementResolveEvent` |
   | new grid column | `ColumnDefinitionInterface`, `ColumnResolverInterface`, optionally `ColumnCollectorInterface` and `TransformerInterface` |
   | new filter | search index filters (OpenSearch or Elasticsearch through the Generic Data Index) or listing filters (classic listings); read the matching docs page |
   | new asset metadata type | `MetaDataAdapterInterface` with `DataNormalizerInterface` and `DataDenormalizerInterface` |
2. **Endpoint.** Extend `AbstractApiController` and call `parent::__construct($serializer)` with the Symfony `SerializerInterface`. Use `#[Route]`, `#[IsGranted(UserPermissions::<CASE>->value)]` (enum `Pimcore\Bundle\StudioBackendBundle\Util\Constant\UserPermissions`), OpenAPI attributes from `OpenApi\Attributes\` and `Pimcore\Bundle\StudioBackendBundle\OpenApi\Attribute\...`, and `#[MapQueryString]` or `#[MapRequestPayload]` for input.
3. **OpenAPI.** Register the scan path so the endpoint appears in the docs:
   ```yaml
   pimcore_studio_backend:
       open_api_scan_paths:
           - "%kernel.project_dir%/vendor/<namespace>/<bundle-name>/src"
   ```
4. **Events.** Subscribers implement `Symfony\Component\EventDispatcher\EventSubscriberInterface`. Use the event class's `EVENT_NAME` constant. Examples seen in the docs: `AssetEvent::getAsset()`, `addAdditionalAttribute()`, `setCustomAttributes()` with `Pimcore\Bundle\StudioBackendBundle\Element\Schema\CustomAttributes`; `ElementResolveEvent::getElementType()`, `getSearchTerm()`, `setModifiedSearchTerm()`. The full event list is on the "Additional and Custom Attributes" docs page.
5. **Grid columns.** Service tags: `pimcore.studio_backend.grid_column_definition`, `pimcore.studio_backend.grid_column_resolver`, `pimcore.studio_backend.grid_column_collector`, `pimcore.studio_backend.grid_transformer`. A column's `getFrontendType()` returns a built-in `FrontendType` value (for example `input`, `select`, `checkbox`, `datetime`, `image`, `asset-link`, `object-link`) or a custom string that needs a matching Studio UI cell type (`studio-ui-development.md`). Config keys: `pimcore_studio_backend.grid.asset.predefined_columns`, `grid.data_object.predefined_columns`, `search_grid.asset.predefined_columns`, `grid.data_object.skip_field_types`.
6. **Asset metadata adapters.** Tag `pimcore.studio_backend.metadata_adapter` (use `#[AutoconfigureTag(AdapterLoader::METADATA_ADAPTER_TAG->value)]` with the enum `Pimcore\Bundle\StudioBackendBundle\Util\Constant\AdapterLoader`) and map the type in `pimcore_studio_backend.asset_metadata_adapter_mapping`.
7. **Permissions.** Every endpoint checks permission in PHP with `#[IsGranted]`. A denied call returns 403 through `UserPermissionVoter`.
8. **Verify against `vendor/`.** Confirm each class, interface and constant exists in the installed `pimcore/studio-backend-bundle` before you use it. The names above come from the 2026.3 docs and may differ in your version.

## Not covered here
The pages this module was written from did not give: the service tag for listing filters and search index filters, the namespace of the `FrontendType` enum, custom OpenAPI schemas, data object field definition adapters and custom document types. Read those docs pages and the installed package before writing code for them, and do not guess the names.

## Best practices
- Thin controllers; business logic in services shared with commands and handlers.
- Paginate collection endpoints (`PaginatedResponseTrait`, `PageParameter`, `PageSizeParameter`).
- Add OpenAPI attributes to every endpoint; the UI and external clients rely on the schema.
- Keep event subscribers cheap; they run on every element response.

## Common mistakes
- Missing service tag: the class exists and is never called.
- Missing `open_api_scan_paths` entry: the endpoint works but is not documented.
- No `#[IsGranted]` on a custom endpoint.
- Copying Classic admin controller code (`/admin/...` routes) into Studio.
- A custom `getFrontendType()` string with no UI cell type.

## Version notes
- Studio Backend is part of the platform from 2026.1. Names and tags are taken from the 2026.3 docs.
- The Classic admin controllers and `AdminSubscriber` listeners are removed in 2026.1. Each project endpoint built on them needs a Studio Backend replacement.
- Not documented as a one-to-one table in the pages read: how each Classic admin event maps to a Studio event. Build the mapping per feature from the installed package.

## Example
Add a "last synced from SAP" attribute to the asset or element response:
- A PreResponse subscriber reads the project's sync service and calls `addAdditionalAttribute()` on the event.
- The attribute is shown by a Studio UI plugin (`studio-ui-development.md`).
- A unit test builds the event, runs the subscriber and asserts the attribute.

## Validation checklist
- [ ] Every interface, enum and tag verified in installed `vendor/`.
- [ ] Services tagged; discovery confirmed (`bin/console debug:container --tag=<tag>`).
- [ ] Endpoints have `#[IsGranted]` and OpenAPI attributes; scan path registered.
- [ ] Unit test for each subscriber or service; endpoint called as admin and restricted role.
- [ ] Caches cleared; commands and results reported.

## Expected output
Extension points used, files changed, tags and config keys added, the commands run with results, the endpoints exercised with status codes, and names that could not be verified.
