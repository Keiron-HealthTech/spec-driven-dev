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

## Triage (minimal)

Apply in order; outcomes are mutually exclusive:

1. Trivial diff (only docs, comments, or formatting; zero executable code and zero configuration changes) → 0 lenses. Persist an empty ledger recording the triage decision, return `REVIEW: CLEAN`.
2. Otherwise → dispatch the `review-readability` lens.

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
