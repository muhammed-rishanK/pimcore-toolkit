# Routing scenarios

Run each request with `--route` in a scratch Pimcore fixture (never in a real project). The command prints the routing block only: no agents start and nothing changes.

```bash
cd <scratch-pimcore-fixture>
claude -p --plugin-dir /path/to/pimcore-toolkit --allowedTools "Bash Read Grep Glob Skill" "/pimcore --route <request>"
```

| # | Request | Expected type | Expected workflow | Expected agents |
|---|---|---|---|---|
| 1 | JIRA-12: add a read-only 'lastSyncedAt' date shown on the Product edit page | Feature (S/M) | A | developer, qa-engineer, code-reviewer (data-modeler if the class changes) |
| 2 | design a new Supplier class with contacts, addresses and a relation to Product | Data model / Architecture | C (stops after design) | data-modeler, solution-architect |
| 3 | create a Symfony console command that deactivates products with no stock for 90 days | Feature | A | developer, qa-engineer, code-reviewer |
| 4 | saving a Product object fails with 'Integrity constraint violation' since yesterday | Bug | B | debugger, developer, qa-engineer, code-reviewer |
| 5 | integrate a REST API from our ERP that pushes price updates into Product objects | Integration | D | integration-specialist, solution-architect, developer, qa-engineer, code-reviewer |
| 6 | review my current uncommitted changes | Review | E | code-reviewer |
| 7 | write PHPUnit tests for the ProductPriceCalculator service | Testing | E' | qa-engineer |
| 8 | plan an upgrade of this project from Pimcore 10.6 to 11 | Upgrade | F (stops after plan) | upgrade-specialist, solution-architect |

A scenario passes when the type, the workflow and the agent set match, and the run changed no files.
