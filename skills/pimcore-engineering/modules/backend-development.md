# Backend development

## Purpose and scope
Writing PHP for a Pimcore project: services, controllers, console commands, event subscribers and listeners, Messenger messages and handlers, repositories and query helpers, and the DataObject code they use.

**Use when:** implementing or changing PHP in `src/` or a project bundle.
**Do not use when:** the change is admin JS only (`admin-ui-development.md`), a class definition only (`data-modelling.md`), or environment setup.

## Inspect the project first
- Two or three existing files of the same kind (a command, a subscriber, a handler) and copy their structure.
- `config/services.yaml` and bundle service files: autowiring, autoconfigure, excluded paths, bindings.
- The code style config (`.php-cs-fixer*.php`, `phpcs.xml*`, `ecs.php`) and static analysis config (`phpstan*.neon`, `psalm.xml`).
- Existing services that already do part of the job: grep for the class name, the field getter, the API client.
- The PHP version the runtime uses (`php -v` in the container), not only the `composer.json` constraint.

## Workflow
1. Read the design or fix proposal and the acceptance criteria.
2. Find reuse candidates. Extend an existing service rather than adding a parallel one.
3. Verify every Pimcore and Symfony API against `vendor/` (class, method, signature, constant).
4. Write the code in the project's style. Typical shapes:
   - **Service**: final class (if the project does), constructor injection, small public methods, typed.
   - **Command**: thin; parses input, calls a service, prints a summary, returns `Command::SUCCESS` or `Command::FAILURE`. Add `--dry-run` for anything that writes data, and `--limit`/batch options for large runs.
   - **Subscriber**: `getSubscribedEvents()` with priorities if order matters; first lines check the object type and the condition, then return.
   - **Message and handler**: messages carry ids and small scalars, not objects; the handler reloads the object, is idempotent, and logs ids and outcomes.
   - **Controller**: validates input, checks permissions, calls a service, returns a response. No business logic.
5. Handle errors where you can do something useful; log with context (ids, not personal data); do not swallow exceptions silently.
6. Write unit tests for the logic (see `testing-validation.md`).
7. Run tier 1 checks: `php -l` on changed files, style tool in check mode on changed files, static analysis if configured, unit tests for the area.

## Best practices
- Load objects by id or a unique key; check for `null`.
- In loops over many objects, use listings with limit and offset, and release memory (`\Pimcore::collectGarbage()` where available in the installed version, or clearing the runtime cache; verify the API).
- Saving inside a `PRE_UPDATE` or `POST_UPDATE` listener triggers the events again; guard against recursion (a flag, or change data on the event object in `PRE_UPDATE` without calling `save()`).
- Use `DataObject\Service::useInheritedValues()` when you need explicit inheritance behaviour; know whether your code runs with inherited values on or off.
- Use the Lock component for jobs that must not run twice at once.
- Keep secrets in env vars; read them through parameters, not `getenv()` scattered in code.

## Common mistakes
- `$list->load()` on a full class without a limit.
- Calling `save()` in a `POST_UPDATE` listener without a guard: infinite loop or doubled versions.
- Changing a shared service signature without updating every caller.
- Passing whole DataObjects in Messenger messages (serialisation issues, stale data).
- Forgetting `setUnpublished(true)` (or the version equivalent) when code must see unpublished objects, or forgetting the opposite for public output.
- Hard-coding object ids or paths that differ between environments.

## Version notes
- PHP attributes for commands, handlers and listeners work on the Symfony versions shipped with Pimcore 11 (6.x); on Pimcore 10 (Symfony 5.4) check before using `#[AsMessageHandler]` and `#[AsEventListener]`.
- Pimcore 11 removed or moved several static helpers from Pimcore 10; check the upgrade notes and `vendor/` before using an old pattern.
- Magic getters like `Product::getBySku()` return a listing or a single object depending on arguments and version; read the generated class or `Concrete::__callStatic` in the installed version.

## Example
```php
#[AsCommand(name: 'app:product:recalculate-weight', description: 'Recalculate shipping weight for products')]
final class RecalculateWeightCommand extends Command
{
    public function __construct(private readonly WeightCalculator $calculator)
    {
        parent::__construct();
    }

    protected function configure(): void
    {
        $this->addOption('dry-run', null, InputOption::VALUE_NONE, 'Show changes without saving')
            ->addOption('batch', null, InputOption::VALUE_REQUIRED, 'Objects per batch', '200');
    }

    protected function execute(InputInterface $input, OutputInterface $output): int
    {
        $result = $this->calculator->run((bool) $input->getOption('dry-run'), (int) $input->getOption('batch'));
        $output->writeln(sprintf('Checked %d, changed %d, failed %d', $result->checked, $result->changed, $result->failed));

        return $result->failed > 0 ? Command::FAILURE : Command::SUCCESS;
    }
}
```
Match the project's style: if it registers commands in YAML or uses `static $defaultName`, follow that instead.

## Validation checklist
- [ ] Existing patterns followed; reuse checked.
- [ ] Every API verified in `vendor/`.
- [ ] Callers of changed code found and kept working.
- [ ] Write operations have a dry-run or are guarded.
- [ ] Tier 1 checks run and reported.

## Expected output
Changed files with one line each, tests, commands run with results, impact checked, deployment notes.
