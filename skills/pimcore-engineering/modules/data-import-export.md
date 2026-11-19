# Data import and export

## Purpose and scope
Moving data in and out of Pimcore in bulk: CSV, Excel, XML and JSON files, SFTP and HTTP sources, the Pimcore data importer, custom import and export commands, batch processing, validation, error reporting and idempotent re-runs.

**Use when:** building or changing a bulk import, an export file, a migration of existing data, or a scheduled feed.
**Do not use when:** the data moves one object at a time through a live API (`integration-development.md`).

## Inspect the project first
- Existing import and export commands and services; reuse their reader, writer, logging and reporting.
- `pimcore/data-importer` and `pimcore/data-hub` in `composer.lock`, and their configs if present.
- Libraries available: `phpoffice/phpspreadsheet`, `league/csv`, `league/flysystem-sftp*`, `phpseclib/phpseclib`.
- Where files arrive and go: SFTP settings, Flysystem storages (`config/packages/flysystem.yaml`), local paths.
- Messenger setup if imports run asynchronously.
- Data volume: rows per file, objects per class.

## Workflow
1. **Pick the tool**:
   - Mapping-driven import that business users maintain: the Pimcore data importer (DataHub config with data source, interpreter, resolver, mapping, processing). Check the commands it provides with `bin/console list datahub`.
   - Complex logic, cross-object rules, custom validation: a console command (often dispatching Messenger messages per batch).
   - Exports: DataHub (GraphQL or the export features available in the installed edition) or a command that writes the file.
2. **Define the format**: columns or nodes, types, required values, identifier column, encoding (UTF-8), delimiter, date and number formats, language columns.
3. **Validate before writing**: header check, required columns, types, references to other objects. Collect row-level errors and keep going; stop only for file-level errors.
4. **Match records** by a stable key (SKU, external id), never by title. Decide create, update or skip per row.
5. **Write in batches**: a listing or a reader in chunks, save, then free memory (`\Pimcore::collectGarbage()` in Pimcore 10 and 11, verify in `vendor/`). Consider `Version::disable()` for the run if history is not needed (agreed with the business).
6. **Dry-run**: a `--dry-run` option that runs everything except saves and prints the planned changes and errors.
7. **Report**: counts (read, created, updated, skipped, failed), an error file with row numbers and reasons, duration. Exit code non-zero on failures.
8. **Idempotency**: running the same file twice must not duplicate objects or corrupt data.
9. **Exports**: stream or write in chunks; keep memory flat; write to a temp file then move it to the target to avoid partial files; upload with retries.

## Best practices
- Keep reading, mapping, validating and saving in separate classes; unit test mapping and validation.
- Log ids and row numbers, not full rows with personal data.
- Lock the command (Symfony Lock) so two runs do not overlap.
- Archive processed files with a timestamp; never delete the source without a copy.
- For Excel, read with read-only mode and only the needed sheets to save memory.

## Common mistakes
- Loading the whole file and all objects into memory.
- One bad row stops the whole run, or bad rows are skipped silently.
- Matching by name, creating duplicates.
- Writing an export file in place so consumers read half a file.
- Running a new import on production without a dry-run.

## Version notes
- Data importer configuration and processing commands changed between versions; read the installed bundle's docs and `bin/console list datahub`.
- PhpSpreadsheet versions differ in reader API details; check `composer.lock`.

## Example
Import supplier prices from SFTP daily:
- Command `app:import:supplier-prices --dry-run --file=<optional>`: downloads the newest file, validates header, maps rows by `supplierSku`, updates `purchasePrice` in batches of 200, writes `var/import-reports/<date>.csv` with failures, archives the file.
- Cron: once a day; alert if exit code is non-zero.

## Validation checklist
- [ ] Dry-run implemented and run on a sample.
- [ ] Row-level errors reported; counts printed; non-zero exit on failure.
- [ ] Matching by stable key; second run changes nothing.
- [ ] Memory stays flat on a large sample.

## Expected output
Format definition, components and files, matching rule, batch and memory approach, dry-run output from a sample, report format, scheduling and deploy notes.
