# Output formats for /pimcore

Use the one that matches the task. Leave out a section that has nothing in it, rather than filling it with "none".

## Routing (for `--route`, and as the first lines of every run)
```
Project: Pimcore <version> | PHP <version> | Symfony <version> | runtime <docker/native/unknown>
Task type: <type>   Size: <S/M/L>   Workflow: <A..G or none>
Modules: <list>
Agents: <ordered list, or "none (answered directly)">
Why: <one or two lines>
Checkpoint: <where the run will stop or ask, if anywhere>
```

## Implementation
1. Requirement understanding (with acceptance criteria)
2. Existing implementation (what is there, with `path:line`)
3. Proposed solution (and the alternative not taken, one line)
4. Files changed
5. Implementation notes (anything a reviewer should know)
6. Validation (each command and its result; checks not run and why)
7. Review result (findings fixed, findings accepted)
8. Deployment notes (migrations, class rebuild, cache, workers, config) and rollback
9. Summary (three lines)

## Debugging
1. Problem
2. Reproduction (steps or the evidence used)
3. Root cause (why it happens, with `path:line`)
4. Affected components
5. Fix (applied or recommended, and why it is the smallest safe one)
6. Testing (regression test and result)
7. Result and remaining risk

## Code review
1. Overall assessment (one paragraph, and the verdict: ready, ready with fixes, not ready)
2. Critical findings
3. High findings
4. Medium and low findings
5. Regression risks (what to re-check)
6. Final recommendation
Each finding: `path:line`, the lines of code that cause it (2 to 6 real lines with line numbers, the causing line marked `<- issue`), what is wrong and the concrete scenario where it fails, the suggested fix as code, and a test plan (test to add, command to run, manual check). `/pimcore-review` uses this format with numbered findings.

## Architecture
1. Business requirement
2. Current architecture (relevant parts only)
3. Proposed architecture
4. Alternatives considered
5. Trade-offs
6. Implementation plan (phases, files, dependencies, sizes)
7. Risks and validation strategy

## Data model
1. Current model (classes, fields, relations involved)
2. Proposed change (field by field)
3. Data impact (existing objects, inheritance, versions, search, exports, DataHub, imports)
4. Migration steps and rollback
5. Code and configuration that must change with it

## Upgrade
1. Current state (versions, bundles, PHP, Symfony)
2. Target and why
3. Mandatory changes (breaking changes and removals, with source links)
4. Optional improvements
5. Dependency and custom bundle compatibility
6. Phased plan with rollback for each phase
7. Validation plan

## Setup report (for /pimcore-setup)
```
Pimcore setup: <done | done with warnings | failed | check only | repair>
OS:             <os and version, arch>
Method:         <docker | native>, profile <skeleton | demo | existing>
Pimcore:        <version> (<source: composer.lock>)
PHP:            <version> (<image tag or host php>)
Project:        <absolute path>
Services:       <service: status, host port> ...
Database:       <name>, user <user>, <created | existing | imported>, <n> tables
Admin user:     <username>
Password:       not shown. Read it with: grep ADMIN <project>/.pimcore-setup/secrets.env
URLs:           site <url>, admin <url>/admin
Commands:       start <cmd> | stop <cmd> | logs <cmd> | console <cmd> | workers <cmd>

Health checks
1 Installation completed  <pass|fail|skipped>  <evidence>
2 Database initialized    <pass|fail|skipped>  <evidence>
3 Application healthy     <pass|fail|skipped>  <evidence>
4 Admin accessible        <pass|fail|skipped>  <evidence>
5 Optional services       <pass|fail|skipped>  <evidence>

Files created: <paths, secrets files marked (git-ignored, 600)>
Decisions made: <each automatic choice and why, e.g. "folder acme-pim existed, used acme-pim-2", "2026.x needs a product key, installed 11"; none if nothing was decided>
Needs you:     <only what cannot be done for the user: third-party passwords or tokens, account registration, a sudo password; none if empty>
```
Never include a password, token or the content of a secrets file.
