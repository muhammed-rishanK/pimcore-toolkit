# Contributing to pimcore-toolkit

- Entry commands are `skills/pimcore/SKILL.md` and `skills/pimcore-setup/SKILL.md` (`disable-model-invocation: true`). Knowledge lives in the hidden skills `pimcore-engineering` and `pimcore-environment` as `modules/*.md`.
- A new module needs: the nine template sections, a line in its skill's index, and an entry in `tests/test_structure.py`.
- A new agent needs: frontmatter `name`, `description`, `model`, `skills`, `tools`; no Agent or Task tool (subagents cannot start agents); a row in the routing table in `references/orchestration.md`.
- Never write Pimcore APIs from memory. Check them in `vendor/pimcore/pimcore` of a real project or in the official docs, and mark version-specific facts in "Version notes".
- Scripts must never print secrets, never overwrite existing files, and never need sudo.
- Writing style: plain English, no em-dashes, no filler words.
- Before releasing, run `python3 tests/test_structure.py`, run `claude plugin validate .`, and run the `--route` scenarios in `tests/scenarios.md`.
