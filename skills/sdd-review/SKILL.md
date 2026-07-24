---
name: sdd-review
description: >
  Coordinate multi-agent code review of an implemented diff: deterministic triage,
  read-only lenses, adversarial refutation, bounded fix rounds, Judgment Day mode.
  Trigger: When the orchestrator reaches post-apply review, or the user runs
  /sdd-review or asks for judgment day / dual review.
license: MIT
metadata:
  author: ai-workflow
  version: "1.0"
  scope: [root]
  auto_invoke: "Reviewing an implemented change or diff"
---

## Execution Level

This skill runs at LEAD level. The orchestrator loads it with the Skill tool and
follows it inline — it is never dispatched as a sub-agent. Reason: sub-agents
cannot launch sub-agents, and every reviewer MUST be a separate `Task(...)`
launch with fresh context and restricted tools. The lead does coordination only
(launch agents, merge rows, persist the ledger, ask the user); all code
inspection happens inside the review agents.

## What You Receive

- A change name (e.g., `add-dark-mode`) OR an ad-hoc target (PR number, branch, or user-stated scope)
- Artifact store mode (`engram | openspec | none`) — resolution rules in `skills/_shared/persistence-contract.md`

## Contract Resolution

The canonical ledger contract is `skills/_shared/review-ledger-contract.md`,
located relative to THIS skill file: `{directory of this SKILL.md}/../_shared/review-ledger-contract.md`.
Resolve it to an ABSOLUTE path once, at the start of the review, and pass that
absolute path in every delegate prompt. Never pass a project-relative path:
review agents run with the user's project as cwd and cannot locate the plugin
themselves.

## Triage

Triage is a deterministic decision procedure, not guidance. Evaluate the rules
IN ORDER against the target diff; the FIRST matching rule decides. Outcomes are
mutually exclusive, and rule 5 makes the ordering exhaustive — the same diff
description always yields the same lens selection.

The line budget defaults to 400 changed lines; a project overrides it via the
`review.budget_lines` key in `openspec/config.yaml`. Triage thresholds live in
this skill; every other numeric budget and ceiling lives in the contract.

1. **Trivial** — every changed line is docs, comments, or formatting; zero
   executable code and zero configuration changes; total changed lines at or
   under the line budget → **0 lenses**. Persist an empty ledger recording the
   triage decision, return `REVIEW: CLEAN`, and stop.
2. **Hot path** — the diff touches authentication, security, or payments code,
   at any diff size → **full 4R** (all four lenses), tier `full-4r`.
3. **Over budget** — changed non-documentation lines exceed the line budget →
   **full 4R**, tier `full-4r`.
4. **Large pure docs** — total changed lines exceed the line budget AND every
   changed line is human-facing documentation → **`review-readability` only**,
   tier `standard`.
5. **Standard** — everything else → **exactly ONE lens**, tier `standard`,
   selected by the dominant-risk table below. No rule in this procedure permits
   dispatching a second lens for a standard diff.

### Dominant-Risk Table (rule 5 only)

Rows are ordered by impact, highest first:

| Dominant change class | Lens |
|-----------------------|------|
| Security, permissions, data exposure, dependencies | `review-risk` |
| Integration, partial failure, recovery, error handling, fallbacks | `review-resilience` |
| Behavior, state, tests | `review-reliability` |
| Naming, structure | `review-readability` |

Classify the diff by the change class that dominates its changed lines and
select that row's lens. When more than one class matches, select the SINGLE
highest matching row in the table — never add lenses.

Every delegate prompt passes the resulting `tier`; agents apply the contract's
sweep budget for that tier and never triage themselves.

## Dispatch

Review agents are dedicated plugin agents. Launch them with the namespaced
identifier — `Task(subagent_type: 'spec-driven-dev:review-readability')` —
NOT `subagent_type: 'general'` plus a skill file. Plugin agents register as
`{plugin-name}:{agent-name}` and require the exact namespaced name.

Delegate prompt template:

```
You are the {agent role}. CONTRACT (read FIRST): {absolute path to review-ledger-contract.md}
REVIEW: change={change-name|ad-hoc target} tier={standard|full-4r} round={1}
TARGET (immutable): {diff source, e.g. git diff {base}..HEAD -- paths} + changed-path list
Return ledger rows per contract schema. If clean: "No findings."
```

## Merge and Persist

1. Collect the rows each agent returned in its reply (`No findings.` means zero rows).
2. Merge them into the ledger under a header recording change/target, tier, date, and round.
3. Persist the ledger to the destination the contract's Persistence Mapping defines for the active mode. For `engram`, upsert topic `sdd/{change-name}/review-ledger` (type `architecture`); for an ad-hoc target without a change, derive the slug for `review/{target-slug}/ledger` as `pr-{number}` for a PR, else the kebab-cased branch name, else the kebab-cased user-stated target.
4. An empty ledger is persisted too — it records the triage decision and lenses run.

## Return

```markdown
## Review Summary
**Target**: {change|slug} · **Tier**: {trivial|standard}
**Lenses run**: {list}
**Findings**: {n} ({severity counts})
**Ledger**: {topic + observation id | path | inline}
REVIEW: CLEAN | RESOLVED | OPEN-FINDINGS | ESCALATED
```

## Rules

- The coordinator is the ONLY ledger writer — agents emit rows in their replies and never persist anything.
- The ledger schema, precision gate, and persistence mapping are canonical in `skills/_shared/review-ledger-contract.md` — reference it, never restate it.
- ALWAYS persist the ledger, including when it is empty (mode `none`: report it inline).
