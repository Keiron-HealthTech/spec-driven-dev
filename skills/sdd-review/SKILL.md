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

- A change name (e.g., `add-dark-mode`) OR an ad-hoc target (PR number, branch, or user-stated scope). A review is CHANGE-BOUND when it belongs to an SDD change; otherwise it is AD-HOC (`/sdd-review` works with or without an active change).
- Artifact store mode (`engram | openspec | none`) — resolution rules in `skills/_shared/persistence-contract.md`
- Judgment Day flag — set ONLY when the user explicitly requested judgment day / dual review

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
  (§10). Ad-hoc reviews in `openspec` and `none` modes are INLINE ONLY —
  the review loop completes within the session, with no file or topic created.

A change-bound review persists to its change ledger destination in every mode
(mode `none`: the inline ledger is handed back to the orchestrator, which
supplies it to `sdd-archive` for the Step 0 gate).

An empty ledger is persisted too — it records the triage decision and lenses
run (mode `none`: reported inline).

## Judgment Day Mode

Judgment Day (JD) runs ONLY on an explicit user request ("judgment day",
"dual review"). It REPLACES the lens + refutation pipeline (steps 2, 4, and 5)
for that target — never both on the same target,
and never automatically after apply. Tier is `judgment-day`.

- **Blind parallel dispatch**: launch `jd-judge-a` and `jd-judge-b` in PARALLEL
  over the SAME immutable frozen target, with byte-identical delegate prompts
  (same contract path, tier, target, and round).
  Neither prompt ever contains the other judge's output, findings, or any hint
  of them — the judges are blind; only the coordinator compares their replies
  after both terminate.
- **Corroboration** (contract §7): match the two reply sets by
  location and claim, assign `JD-{NNN}` ids, and record convergence:

  | Convergence | Verification | Handling |
  |-------------|--------------|----------|
  | Both judges report it | `jd:both` | `confirmed` — fixable ONLY after the user is asked and approves |
  | Exactly one judge reports it | `jd:a-only` / `jd:b-only` | `suspect` — the fix agent is NEVER dispatched for it; only the user resolves it (fix or wont-fix) |
  | The judges contradict each other on the same location | `jd:contradiction` | Escalate to the human. Automated handling stops for that finding |

- **No refuter**: no refuter task is dispatched anywhere in JD mode —
  two-judge convergence is the corroboration mechanism (contract §6 JD
  exception).
- **Fix loop**: same as steps 6–7, with a user ask before EVERY round:
  user-approved confirmed findings only, then scoped re-judging by BOTH judges
  (blind again) over the frozen ledger rows plus the immutable fix delta;
  maximum 2 rounds (contract §8).
- Any `jd:contradiction`, or a `suspect` row the user leaves unresolved, makes
  the outcome token `REVIEW: ESCALATED`.

## Return

```markdown
## Review Summary
**Target**: {change|slug} · **Tier**: {trivial|standard|full-4r|judgment-day}
**Lenses/Judges run**: {list} · **Fix rounds**: {0|1|2}
**Findings**: {n} BLOCKER, {n} CRITICAL, {n} info → {n} verified, {n} refuted, {n} wont-fix, {n} open
**Ledger**: {topic + observation id | path | inline}
REVIEW: CLEAN | RESOLVED | OPEN-FINDINGS | ESCALATED
```

Close with exactly ONE outcome token:

| Token | Meaning |
|-------|---------|
| `REVIEW: CLEAN` | Trivial tier, or the run produced zero findings |
| `REVIEW: RESOLVED` | Findings existed and every BLOCKER/CRITICAL row closed (`verified`, `refuted`, or evidenced `wont-fix`); only `info` rows remain |
| `REVIEW: OPEN-FINDINGS` | One or more BLOCKER/CRITICAL rows remain open (round budget exhausted, or the user declined fixes) |
| `REVIEW: ESCALATED` | At least one finding needs a human decision (JD contradiction, or a suspect row the user left unresolved) |

Wrap the summary in the standard structured envelope: `status`,
`executive_summary`, `detailed_report` (the Review Summary above), `artifacts`
(the ledger reference), `next_recommended`, and `risks`.

Routing for `next_recommended`:

- `CLEAN` / `RESOLVED` → `/sdd-verify {change-name}` (change-bound; ad-hoc reviews end here)
- `OPEN-FINDINGS` / `ESCALATED` → user decision required (fix round, wont-fix, or accept the risk); the orchestrator MUST NOT auto-proceed to verify

## Rules

- The coordinator is the ONLY ledger writer — agents emit rows in their replies and never persist anything.
- The ledger schema, precision gate, severity floor, refutation ceilings, and fix-round budget are canonical in `skills/_shared/review-ledger-contract.md` — cite its sections, never redefine its numbers. Triage thresholds (the line budget) live in THIS skill only.
- ALWAYS persist the ledger, including when it is empty (mode `none`: report it inline).
- NEVER dispatch the fix agent for `suspect` or `info` rows, and NEVER set `wont-fix` without the user's explicit decision recorded per contract §9.
- ALWAYS stop at the USER GATE before the first fix round — findings are fixed only with user approval.
