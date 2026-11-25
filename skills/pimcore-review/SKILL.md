---
name: pimcore-review
description: "Code review for a Pimcore project. By default reviews the uncommitted changes and everything in the codebase they affect (callers, events, config, class definitions); --all reviews the whole first-party codebase. Every finding shows the severity, file:line, the lines of code that cause it, why it is a problem, the fix and a test plan. Read-only. Also run automatically by the plugin's Stop hook after code changes. Use when the user runs /pimcore-review."
argument-hint: "[--all | --staged | --base <branch>] [--focus security|performance|data|upgrade] [<path>]"
disable-model-invocation: true
---

# /pimcore-review

Toolkit root (`TK`): `${CLAUDE_SKILL_DIR}/../..`
Modules (`MODULES`): `TK/skills/pimcore-engineering/modules`
Scope script: `${CLAUDE_SKILL_DIR}/scripts/review-scope.sh`

Request: `$ARGUMENTS`

You coordinate the review. The `pimcore-code-reviewer` agent does the reading. Nothing is edited, staged or committed in this command, and no fix is applied, even a small one. The user decides what to fix next.

## Step 1. Parse the arguments
| Argument | Meaning |
|---|---|
| (none) | uncommitted changes: staged, unstaged and untracked code files, plus their impact on the rest of the code |
| `--staged` | only what is staged |
| `--base <ref>` | everything since the merge base with `<ref>` (for example `--base production`), plus uncommitted work |
| `--all` | the whole first-party codebase, not only changes |
| `--focus <area>` | weight the review: `security`, `performance`, `data` (class definitions, migrations, imports) or `upgrade` (adds the impact scan) |
| `<path>` | limit the review to files under this path |

Unknown flags: say which one and stop.

## Step 2. Detect and scope (read-only)
```bash
bash "TK/skills/pimcore/scripts/detect-project.sh" "$PWD"
bash "${CLAUDE_SKILL_DIR}/scripts/review-scope.sh" "$PWD" [--all | --staged | --base <ref>]
```
- Not a Pimcore project: say so in one line and stop.
- No code files in scope: say "Nothing to review" with the mode used, and stop.
- Read the project's instruction files (`CLAUDE.md`, `AGENTS.md`, CONTRIBUTING, `.claude/` rules). Their rules are part of the review.
- `--focus upgrade`: also run `bash TK/skills/pimcore/scripts/scan-platform-impact.sh "$PWD" --format json` and pass the matches in scope to the reviewer.

## Step 3. Review
Start the `pimcore-code-reviewer` agent with: the detect-project JSON, the scope JSON, the absolute `MODULES` path, the user's original requirement if one is known in this conversation, the focus, and the output format in Step 4.

- **Changes mode** (default, `--staged`, `--base`): one reviewer. Tell it to read each changed function in full and then search the whole codebase for what depends on it: callers of changed methods, services that wire changed classes, event subscribers on the same objects, Twig, admin JS, DataHub and import configs that use changed fields, class definitions and their generated classes. A change is not reviewed until its consumers are.
- **`--all`**: split by the `groups` in the scope JSON (for example `src`, `bundles/<name>`, `config`, `templates`, `var/classes`) into at most 4 parts of similar size, and start one reviewer per part in parallel. Each part also gets the list of the other parts, so cross-part calls are followed. Skip generated code (`var/classes/DataObject`), `vendor`, caches and compiled assets.

When the reviewer returns, check every critical and high finding yourself: open the file at the line and confirm the code is there and the scenario holds. Drop findings you cannot confirm, or mark them "unconfirmed".

## Step 4. Report
```
Pimcore review: <mode> (<n> files, +<added> -<removed>)   read-only, nothing was changed
Verdict: <ready | ready with fixes | not ready>   Findings: <c> critical, <h> high, <m> medium, <l> low

### 1. [HIGH] <short title>
File: `src/Service/ProductExporter.php:42`
```php
40     $list = new Product\Listing();
41     $list->setCondition("sku = '" . $sku . "'");   <- issue
42     foreach ($list->load() as $product) {
```
Why: <what goes wrong and the concrete scenario, for example "a SKU with a quote breaks the query; a crafted SKU reads other rows">
Fix:
```php
$list->setCondition('sku = ?', [$sku]);
```
Test plan:
1. <unit or functional test to add, with the input that failed before>
2. <command to run, for example vendor/bin/codecept run Unit Service/ProductExporterTest>
3. <manual check in the admin, if any>

### 2. ...

Regression risks: <consumers to re-check, with path:line>
Checks run: <linters, static analysis or tests run in check mode, with their result; "none" if none ran>
Not reviewed: <files skipped and why>
```
Rules:
- Order by severity, then by file. Number the findings so the user can say "fix 1 and 3".
- The code block shows the real lines from the file with their line numbers, 2 to 6 lines, and marks the line that causes the issue with `<- issue`. Never paraphrase code in that block.
- Every finding has all five parts: file:line, code, why, fix, test plan. If you cannot give a test plan, say what makes it hard to test.
- Severity: critical (data loss, security hole, broken main flow), high (bug in a real scenario, regression), medium (edge case, missing validation or test, costly maintainability problem), low (minor clarity). Style alone is never above low.
- No refactoring wish lists, no findings without a scenario. When there are no significant issues, say so plainly.
- End with one line: `Reply "fix <numbers>" to apply fixes, or /pimcore implement ... for larger ones.`

## Automatic review
The plugin's Stop hook (`TK/hooks/auto-review.sh`) asks for this review in changes mode when Claude has changed code in a Pimcore project and the changes differ from the last reviewed state. It runs once per set of changes, never in a loop. Turn it off with `PIMCORE_AUTO_REVIEW=0` in the environment, or for one project with `git config pimcore.autoReview false`.
