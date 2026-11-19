# Integration development

## Purpose and scope
Building connections between Pimcore and other systems: REST and GraphQL APIs exposed by Pimcore, outbound calls to ERP, eCommerce, DAM or search systems, webhooks, and asynchronous synchronisation through Symfony Messenger. Covers contracts, authentication, mapping, idempotency, retries, failure handling and monitoring.

**Use when:** a feature reads from or writes to another system, or exposes Pimcore data to one.
**Do not use when:** the task is a file-based bulk import or export with no live system (`data-import-export.md`), though both often apply together.

## Inspect the project first
- Existing clients: grep for `HttpClientInterface`, `GuzzleHttp`, SOAP clients, SFTP services.
- Messenger: `config/packages/messenger.yaml` (transports, routing, failure transport, retry strategy), message classes and handlers, how workers run (supervisor config, Docker service).
- DataHub: `pimcore/data-hub` in `composer.lock`, its configs (GraphQL endpoints, API keys, permissions per config).
- API controllers and their security (`config/packages/security.yaml`, firewalls, API key checks).
- Env vars and secrets for endpoints and credentials (`.env`, `.env.local` pattern, secrets vault).
- Mapping code or mapping tables between Pimcore fields and the other system.

## Workflow
1. **Define the contract**: direction, trigger, payload or file format, identifiers, authentication, rate limits, expected volume and latency.
2. **Field ownership**: a table of fields, owner system, and conflict rule.
3. **Choose the transport**:
   - Pimcore exposes data, consumer pulls: DataHub GraphQL if it fits, otherwise a controller.
   - Pimcore pushes on change: event subscriber dispatches a Messenger message; the handler calls the API.
   - Scheduled sync: console command (cron) that dispatches messages in batches.
   - Inbound push (webhook): controller validates signature, stores or dispatches a message, returns quickly.
4. **Messages** carry ids and minimal data; handlers reload current data. Configure retries and a failure transport.
5. **Idempotency**: handlers can run twice. Use upserts by external id, compare before write, store last-synced hashes or timestamps where useful.
6. **Errors**: classify as retryable (timeouts, 5xx, 429) and permanent (validation, 4xx). Retry the first, record and report the second with the object id. Use `UnrecoverableMessageHandlingException` (Symfony Messenger) for permanent failures if the project uses that pattern.
7. **Observability**: log start, counts, failures with ids, duration; never log tokens, passwords or personal data. Make failed messages visible (`messenger:failed:show`) and replayable.
8. **Security**: credentials from env vars or the secrets vault; least-privilege API users; validate inbound input; TLS verification on.
9. **Tests**: unit tests with a mocked HTTP client (`MockHttpClient` for Symfony HttpClient), contract tests against a sandbox if available. Never write to a live third-party system from tests.

## Best practices
- Wrap each external system in one client service; the rest of the code calls the client.
- Timeouts on every call.
- Map in a dedicated mapper class that is easy to unit test.
- Version the outbound payload if consumers depend on it.
- Avoid saving the Pimcore object from a sync handler unless needed; when you must, prevent the save from triggering an outbound sync again (loop).

## Common mistakes
- Calling the external API synchronously inside `POST_UPDATE`, making admin saves slow and fragile.
- Sync loops: inbound update saves the object, the save triggers an outbound push, the other system pushes back.
- Matching records by name or title.
- No failure transport: failed messages are lost after retries.
- Credentials in code, config committed to git, or logs.

## Version notes
- Messenger transports used by Pimcore 11 core include `pimcore_core`, `pimcore_maintenance`, `pimcore_scheduled_tasks`, `pimcore_image_optimize` and `pimcore_asset_update`; project transports are separate. Check the installed config.
- DataHub features and editions differ by version (some adapters are enterprise only). Confirm in `composer.lock` and the docs for that version.
- `#[AsMessageHandler]` needs Symfony 5.4+ attribute support; older projects tag handlers in YAML.

## Example
Push product price changes to the shop:
- `ProductPriceChangedSubscriber` on `POST_UPDATE`: if Product and price changed, dispatch `SyncProductPrice($id)`.
- `SyncProductPriceHandler`: reload product, map, `PUT /prices/{sku}` with timeout 10s; 429 and 5xx retry (3 times, exponential); 4xx logs and throws an unrecoverable exception.
- Monitoring: daily `messenger:failed:show` check, log counts per run.

## Validation checklist
- [ ] Contract and field ownership written down.
- [ ] Async where the caller should not wait; retries and failure transport configured.
- [ ] Handlers idempotent; loops prevented.
- [ ] Secrets in env or vault; logs clean.
- [ ] Tests mock the external system.

## Expected output
Integration overview, ownership and mapping table, components and files, failure and retry design, security notes, tests, deployment steps (workers restart, env vars).
