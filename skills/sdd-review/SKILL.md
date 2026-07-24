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

## Target Freeze

Resolve the review target ONCE, at the start of the review, and record it in
the ledger header (change/target, tier, date, round):

- Change-bound: the change's implementation diff — the worktree or branch diff
  against its base (e.g., `git diff {base}..HEAD`) plus the changed-path list.
- Ad-hoc: the PR diff, the branch diff, or the user-stated scope.

The frozen target is immutable for the whole review: every lens, judge, and
refuter receives the SAME diff source and path list. In later rounds the fix
deltas append to the record; the target itself is never re-derived mid-review.

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

Lens / judge delegate prompt template:

```
You are the {agent role}. CONTRACT (read FIRST): {absolute path to review-ledger-contract.md}
REVIEW: change={change-name|ad-hoc target} tier={standard|full-4r|judgment-day} round={1|2}
TARGET (immutable): {diff source, e.g. git diff {base}..HEAD -- paths} + changed-path list
{round 2 only: FROZEN LEDGER rows under verification + immutable fix delta — verify resolution only, no new discovery}
Return ledger rows per contract schema (judges: findings without ids). If clean: "No findings."
```

Refuter delegate prompt template:

```
You are the review refuter. CONTRACT (read FIRST): {absolute path to review-ledger-contract.md}
REVIEW: change={change-name|ad-hoc target} tier={standard|full-4r} round={1|2}
TARGET (immutable): {the same frozen diff source} + changed-path list
REFUTATION LENS: {general|correctness|exploitability-impact|reproducibility}
CANDIDATES (complete merged batch): one line per candidate — {id | location | severity | claim/evidence}
Return one verdict line per id: {id}: corroborated|refuted|inconclusive — {proof_refs}
```

Fix delegate prompt template:

```
You are the surgical fix agent. CONTRACT (read FIRST): {absolute path to review-ledger-contract.md}
REVIEW: change={change-name|ad-hoc target} round={1|2}
TARGET (immutable): {the same frozen diff source} — apply fixes in the project working tree
CONFIRMED IDS (fix ONLY these): one line per finding — {id | location | severity | evidence}
Return ## Fixes Applied and ## Fixed IDs per your agent rules.
```

## Orchestration Sequence

Run these steps in order. "Persist" always means upserting the destination
defined in Ledger Lifecycle and Persistence below.

1. **Freeze the target** and run **Triage**. Trivial tier: persist the empty
   ledger and return `REVIEW: CLEAN` — done.
2. **Dispatch lenses** in PARALLEL — one `Task(...)` per lens selected by
   triage, each with the lens delegate template: contract absolute path,
   `tier`, `round=1`, and the frozen target. (Judgment Day mode replaces this
   step and steps 4–5 with its own dispatch and corroboration — see below.)
3. **Merge rows** returned in the agents' replies (`No findings.` = zero rows):
   - Cross-lens duplicates (same location, same underlying defect) collapse
     into ONE row keeping the HIGHEST severity; note the merged ids in the
     surviving row's evidence.
   - Judge findings arrive WITHOUT ids: the coordinator assigns `JD-{NNN}`
     sequentially and computes corroboration (contract §7).
   - Severity floor (contract §5):
     WARNING/SUGGESTION rows get status `info` exactly once —
     they are never refuted, never fixed, never re-reviewed, and never block.
   - **Persist ledger v1** (post-merge). An empty ledger is persisted too.
4. **Refutation**:
   - Batch ONLY open BLOCKER/CRITICAL rows. If there are none, go to step 8.
   - Dispatch refuter tasks at the structural ceiling of contract §6:
     exactly 1 task (lens `general`) for a standard review; exactly 3 tasks in
     parallel (lenses `correctness`, `exploitability-impact`,
     `reproducibility`) for full-4R — whether the batch has 1 candidate or 20.
     NEVER one task per finding. Every task receives the complete batch.
   - Apply verdicts per contract §6: standard — a `refuted` general verdict
     kills the finding; full-4R — a finding is refuted only when
     at least 2 of the 3 lens verdicts refute it.
     A malformed or missing per-finding verdict defaults to `stands`:
     the finding survives and stays open, never silently dropped.
   - **Persist** (post-refutation).
5. **USER GATE (ALWAYS)** — before any round-1 fix work: present every
   surviving open BLOCKER/CRITICAL row and ask the user to approve fixing.
   Per finding the user picks: fix / wont-fix (recorded per contract §9) /
   leave open. No approval → go to step 8 with the rows open.
6. **Fix round** — dispatch `jd-fix-agent` ONCE with the complete list of
   user-approved, verification-surviving open BLOCKER/CRITICAL rows —
   confirmed ids only, never suspects, never `info` rows. Record its
   `## Fixed IDs` as status `fixed`. New problems it reports go to the user in
   your summary — never appended to the ledger.
7. **Scoped re-review** — re-dispatch ONLY the originating lens(es) (or both
   judges in Judgment Day mode) with `round=2`: input restricted to the
   FROZEN ledger rows under verification plus the immutable fix delta —
   never a fresh full-diff review; `info` rows are excluded.
   Re-review confirms a fix → `verified`; rejects it → back to `open`.
   **Persist** (post-round).
   Steps 6–7 form one fix round; the budget is contract §8: MAXIMUM 2 rounds.
   A second round repeats steps 6–7 only for rows still open, after showing
   the user round-1 results and getting approval to continue. Anything still
   open after round 2 is reported to the user as open and the loop STOPS —
   no round 3 exists in this procedure.
8. **Final persist + return** — persist the final ledger and return the
   Review Summary with the outcome token.

## Ledger Lifecycle and Persistence

The coordinator is the ONLY ledger writer. The ledger lives under a header
recording change/target, tier, date, and round. It is persisted at four
checkpoints — post-merge (v1), post-refutation, post-round, final — ALWAYS
upserting the same destination, never creating a new one:

- `engram`: upsert topic `sdd/{change-name}/review-ledger` (type
  `architecture`). Ad-hoc target without a change: topic
  `review/{target-slug}/ledger`, deriving the slug as `pr-{number}` for a PR,
  else the kebab-cased branch name, else the kebab-cased user-stated target.
- `openspec` and `none`: destinations per the contract's Persistence Mapping
  (§10).

An empty ledger is persisted too — it records the triage decision and lenses
run (mode `none`: reported inline).

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
