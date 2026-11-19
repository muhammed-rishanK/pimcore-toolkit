# Performance optimisation

## Purpose and scope
Finding and fixing slowness and memory problems in Pimcore: object listings and queries, save cascades, events, caching, admin grid and editor load times, Messenger throughput, imports and exports, and database indexes.

**Use when:** something is slow, runs out of memory, times out, or a change must handle large volumes.
**Do not use when:** nothing is measured yet and there is no complaint; do not optimise blind.

## Inspect the project first
- The slow path: URL, command, handler, admin action; how slow, how often, since when.
- Volumes: objects per class, versions table size, assets count.
- Cache setup: `config/packages/cache.yaml` or the Pimcore cache pool (Redis or database), full page cache config.
- Event subscribers on the classes involved (`bin/console debug:event-dispatcher`).
- Database: indexes on query table columns used in conditions, slow query log if available.
- Worker setup: number of Messenger consumers, memory and time limits.

## Workflow
1. **Measure**: time and memory for the slow operation; query count (Symfony profiler in dev, or logging). Run several times and take the median.
2. **Find the hot spot**: profiler, timers around suspect blocks, slow query log, `EXPLAIN` on the heavy query.
3. **Typical causes and fixes**:
   - Listing without limit or loading full objects when ids are enough: use `setLimit`/`setOffset`, `loadIdList()` or a direct query on the query table for read-only lookups.
   - N+1 relation loading: load related ids once, or query the relations table.
   - Missing index on a field used in conditions: set the field's index option in the class definition (adds an index on the query table), confirm with `EXPLAIN`.
   - Save cascades: listeners saving other objects, versions for every bulk save, search index updates; move to Messenger, batch, disable versions for agreed bulk runs.
   - Memory growth in loops: `\Pimcore::collectGarbage()` every batch (verify API), avoid keeping objects in arrays.
   - Cache misses: cache expensive computed data with tags and invalidate on save.
   - Admin editor slow to open: very large classes, many relations, heavy `OBJECT_GET_PRE_SEND_DATA` listeners, large blocks.
   - Workers falling behind: more consumers, smaller messages, separate transports for heavy and light work.
4. **Fix one thing at a time**, then measure again with the same method.
5. **Check side effects**: caching can show stale data; disabled versions lose history; batching changes event order.

## Best practices
- Write down before and after numbers with the same data and method.
- Prefer algorithmic fixes (fewer queries, less data) over caching.
- Add indexes through the class definition so they survive rebuilds.
- Keep worker processes short-lived (`--limit`, `--memory-limit`, `--time-limit`) so leaks do not pile up.

## Common mistakes
- Optimising without a measurement, or measuring once.
- Caching data that must be fresh (prices, stock) without invalidation.
- Adding database indexes by hand that a class rebuild drops or duplicates.
- Raising PHP memory limits instead of fixing the leak.

## Version notes
- Listing APIs (`loadIdList`, `setCondition` parameters, `setUnpublished`) are stable across 10 and 11, but check signatures in `vendor/`.
- Pimcore 11 moved the generic search index to an optional bundle; later releases add a generic data index based on OpenSearch or Elasticsearch. Check which one the project uses before tuning search.

## Example
Command that recalculates 120k products takes 4 hours and dies with memory exhausted.
Measured: 0.12 s per object, memory grows 30 MB per 1000 objects. Hot spots: versions on every save, `POST_UPDATE` listener exporting each product synchronously, no garbage collection.
Fix: batch of 500 with `collectGarbage()`, versions disabled for the run (agreed), export listener skips when a "bulk run" flag is set and the command dispatches one export message per batch. Result: 0.02 s per object, flat memory.

## Validation checklist
- [ ] Before and after numbers with the same method and data.
- [ ] Hot spot identified with evidence.
- [ ] Side effects (freshness, history, event order) checked.
- [ ] Indexes added through class definitions.

## Expected output
Measurement method, before numbers, hot spot with evidence, change made, after numbers, side effects and remaining risks.
