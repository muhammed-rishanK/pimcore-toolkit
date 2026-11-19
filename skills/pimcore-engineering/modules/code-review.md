# Code review

## Purpose and scope
Reviewing a Pimcore change on its real diff against its requirement: correctness, regressions, security, data integrity, performance, maintainability and standards, with Pimcore-specific checks. The reviewer is independent of the author and does not fix the code.

**Use when:** after any implementation, for "review my changes", before a merge request or release.
**Do not use when:** there is no diff yet; review the design instead (architecture output).

## Inspect the project first
- The diff: `git diff`, `git diff --cached`, untracked files (`git status --porcelain`), or the branch range (`git diff <base>...HEAD`).
- The requirement, ticket or design the change serves.
- The project's standards: instruction files, style and static configs, existing patterns in the same area.
- Callers and consumers of each changed symbol (grep across PHP, YAML, Twig, JS, workflow and DataHub configs).

## Workflow
1. Read the requirement, then the full diff once without judging.
2. For each changed file, read the surrounding code and the callers.
3. Go through the checklist below in order. For each possible issue, build the concrete scenario that breaks. Drop it if you cannot.
4. Run the project's style and static tools on changed files if present.
5. Rate each finding (critical, high, medium, low) and propose the smallest fix.
6. Give a verdict: approve, approve with minor fixes, changes required.

## Checklist
**Functional**: meets every acceptance criterion; handles empty, null, inherited and unpublished values; correct for variants and localized fields; no unrelated changes.
**Regression**: changed signatures and events still match all callers; subscribers return early for other classes; no new recursion on save; existing data still valid with new mandatory or validation rules.
**Pimcore specifics**:
- listings have limits and parameterised conditions;
- no `save()` inside listeners without a guard;
- versions and inheritance behaviour intended;
- class definitions changed by definition files or migrations, never by generated classes;
- renames or removals have a data plan;
- `classes-rebuild -d` not in deploy steps;
- Messenger messages carry ids; handlers idempotent; transports and retry configured;
- admin JS not used as the only enforcement of a rule;
- permissions and workspaces checked in PHP.
**Security**: see `security-best-practices.md`.
**Performance**: N+1 relation loading, unbounded loops, synchronous external calls in save events, missing indexes for new filters.
**Maintainability**: follows the project's patterns; no duplicated logic; names clear; no dead code.
**Tests**: new logic covered; tests meaningful; no weakened assertions.
**Deployment**: migrations, rebuilds, cache, workers and env vars listed.

## Best practices
- Quote the line and explain the failure in one or two sentences.
- Separate "must fix" from "consider".
- Praise is not needed; clarity is.
- Say explicitly when you found nothing significant.

## Common mistakes
- Reviewing only the hunks, not the callers.
- Style preferences reported as high severity.
- Long refactoring lists that are not tied to a risk.
- Reviewing what the author described instead of what the diff does.

## Version notes
Check APIs used in the diff against the installed `vendor/`; code copied from docs for a newer Pimcore version is a frequent source of bugs.

## Example finding
High, `src/EventSubscriber/PriceSubscriber.php:42`: calls `$product->save()` inside `onPostUpdate` without a guard. Saving any Product triggers the subscriber again, creating a second version and a second export message. Fix: change the value in `PRE_UPDATE` without saving, or set a static guard flag around the save.

## Validation checklist
- [ ] Real diff reviewed, including untracked files.
- [ ] Each finding has location, scenario and fix.
- [ ] Verdict given.

## Expected output
Overall assessment and verdict, findings by severity with `path:line`, problem, failure scenario and fix, regression risks, final recommendation.
