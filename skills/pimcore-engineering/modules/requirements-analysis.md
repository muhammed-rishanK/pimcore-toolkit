# Requirements analysis

## Purpose and scope
Turn a ticket, a message or a vague request into a precise, testable statement of what must change in a Pimcore project, before anyone designs or codes. Covers business intent, users and roles, acceptance criteria, edge cases, data and integration impact, and open questions.

**Use when:** a request arrives as a ticket, a user story, a client email or a one-liner; the request mentions data, roles, workflows or another system; the user asks "analyse this ticket".
**Do not use when:** the task is a trivial, fully specified change (rename a label, fix a typo), or a bug with a clear stack trace (go to the debugger workflow; it does its own scoping).

## Inspect the project first
- The project instruction files (`CLAUDE.md`, `AGENTS.md`, `README`, `docs/`) for domain terms and rules.
- The classes involved: `var/classes/definition_<Class>.php`, their field collections and bricks.
- Workflows on those classes (`config/**/workflows*.y*ml`, or the `pimcore.workflows` key in config).
- Roles and permissions the request mentions: grep `config/` and `src/` for role names, `isAllowed`, `checkPermission`.
- Integrations that read or write the same data: Messenger handlers, commands, DataHub and data importer configs.
- Git history for the area (`git log --oneline -20 -- <path>`) and related ticket keys in commit messages.

## Workflow
1. **Restate** the request in two or three sentences in plain language. Name the actor, the object, the change and the reason.
2. **Identify the users and roles** affected: editors, approvers, admins, API clients, scheduled jobs.
3. **Write acceptance criteria** as observable outcomes: "Given / When / Then" or a numbered list. Each criterion must be testable without reading the code.
4. **List edge cases**: empty values, inherited values, variants, unpublished objects, localized fields per language, existing objects created before the change, bulk edits, imports, concurrent edits, permission-restricted users, workflow places that lock fields.
5. **Data impact**: which classes and fields change, whether existing objects need a migration or a re-save, whether search indexes, exports or feeds change.
6. **Integration impact**: which external systems read or write these fields, which messages or files change format.
7. **Non-functional needs**: volume (number of objects), response time, audit (versions, notes), security.
8. **Open questions**: every gap you cannot close from the project. Do not fill gaps with assumptions; when you must assume to continue, mark it `ASSUMPTION` and keep it in the output.
9. **Size**: S (one file or config, no data change), M (a few files, one area), L (several areas, data model change, integration change).

## Best practices
- Use the project's vocabulary (class names, field titles, workflow place names) so the criteria map straight to code.
- Separate what the user asked from what you think is needed; propose extras as options.
- Ask the question with your recommended answer so the user can reply "yes".
- Look for an existing feature that already does most of it, and say so.

## Common mistakes
- Criteria that describe implementation ("add a subscriber") instead of behaviour.
- Ignoring existing objects: a new mandatory field breaks saving every old object in the admin.
- Forgetting inherited values and variants.
- Forgetting the import and API paths, which bypass admin UI validation and layouts.
- Treating a field hidden in a custom layout as protected; layouts are not permissions.

## Version notes
Behaviour that differs by version and can change requirements: admin UI (classic bundle in 11, Pimcore Studio in later releases), bundles that are optional in 11 and must be enabled, workflow and permission features. Check `composer.lock` before promising UI behaviour.

## Example
Request: "Editors should not change the SAP number after a material is approved."
- Restated: once a Material reaches the `approved` workflow place, the `sapNumber` field is read-only for non-admin users in the admin UI and rejected on save from any path.
- Criteria: (1) In `approved`, an editor sees `sapNumber` read-only. (2) Saving a changed `sapNumber` through the API or import as an editor fails with a clear message. (3) Admins can still change it. (4) Objects not in `approved` are unaffected.
- Edge cases: inherited `sapNumber` on variants, import user role, objects approved before the release.
- Questions: Should the integration user be allowed to change it? (Recommend: yes, it owns the field.)

## Validation checklist
- [ ] Every criterion is observable and testable.
- [ ] Roles, edge cases, existing data and integrations are covered.
- [ ] Assumptions are marked and questions carry a recommendation.
- [ ] Size given with a reason.

## Expected output
Restated requirement, users and roles, acceptance criteria, edge cases, data impact, integration impact, non-functional needs, assumptions, open questions, size.
