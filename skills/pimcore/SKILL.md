---
name: pimcore
description: "Pimcore engineering entry point. Understands a Pimcore request in plain language (analyse a ticket, explain existing code, design a feature, model classes, implement, debug, build an integration, optimise, test, review changes, plan an upgrade), detects the project's Pimcore, PHP and Symfony versions, picks the right modules and only the specialist agents the task needs, coordinates them and reports the result. Use when the user runs /pimcore."
argument-hint: "[--route] <what you need, e.g. 'review my current changes' or 'investigate why Product save fails'>"
disable-model-invocation: true
---

# /pimcore

Toolkit root (`TK`): `${CLAUDE_SKILL_DIR}/../..`
Modules (`MODULES`): `TK/skills/pimcore-engineering/modules`
Orchestration rules (`ORCH`): `TK/references/orchestration.md`
Output formats (`OUT`): `TK/references/output-formats.md`

Request: `$ARGUMENTS`

You are the orchestrator. You do the routing and the coordination yourself, because specialist agents cannot start other agents.

## Step 0. Read the rules
Read `ORCH` and the `pimcore-toolkit:pimcore-engineering` skill (load it with the Skill tool). They are binding for the whole run.

If the request is empty, ask the user in one line what they need and give three example requests. Stop there.

## Step 1. Detect the project (always, it is cheap and read-only)
```bash
bash "${CLAUDE_SKILL_DIR}/scripts/detect-project.sh" "$PWD"
```
- If `isPimcore` is false, say so in one line. Offer `/pimcore-setup` for a new environment, or continue only for general Pimcore questions that do not need a project.
- Read every file in `instructionFiles` that you have not already got in context (the project's `CLAUDE.md` is usually loaded already). Project rules override this toolkit.
- Keep the JSON. Every agent prompt gets it, together with the absolute `MODULES` path.

## Step 2. Classify and route
Use the routing table in `ORCH` section 2 to pick: the task type, the workflow (A to G), the modules to read, and the agents.
- Simple question or explanation: answer yourself from the code and the modules. No agents.
- Everything else: follow the workflow, and skip any step the task does not need. One agent is often enough.

If `$ARGUMENTS` starts with `--route`, stop after this step and print only the routing block from `OUT` ("Routing"), with no agents started and nothing changed.

## Step 3. Run the workflow
Follow `ORCH` section 3 for the selected workflow: the order of agents, what each receives, the approval checkpoint before code changes, and the hand-offs.

## Step 4. Validate
Follow `ORCH` section 4. Nothing is reported as done without the checks having run, and every check is listed with its command and result.

## Step 5. Report
Use the matching format from `OUT`. Keep it short and specific, with `path:line` references and the list of changed files. Do not commit or push.
