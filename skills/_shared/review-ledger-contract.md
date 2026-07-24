# Review Ledger Contract (canonical — shared across the SDD review system)

Single source of truth for the review ledger. Review agents and SDD skills
reference this file by path; they never duplicate its schema or its numbers.

## Roles

| Role | Actor | Ledger access |
|------|-------|---------------|
| Coordinator | `sdd-review` skill (lead level) | The ONLY ledger writer: merges rows, assigns JD ids, persists/upserts |
| Lens | `review-risk`, `review-readability`, `review-reliability`, `review-resilience` | Emits candidate rows in its reply; never persists |
| Judge | `jd-judge-a`, `jd-judge-b` | Emits findings without ids in its reply; never persists |
| Refuter | `review-refuter` | Emits verdict lines in its reply; never persists |
| Fix agent | `jd-fix-agent` | Reports fixed ids + evidence in its reply; never edits the ledger |

## Ledger Schema

Every ledger starts with a header recording: change (or ad-hoc target), tier,
date, and round. Finding rows follow this table:

| id | lens | location | severity | status | evidence | verification |
|----|------|----------|----------|--------|----------|--------------|

- `id` — `{PREFIX}-{NNN}` with fixed prefixes: `R1` (risk), `R2` (readability), `R3` (reliability), `R4` (resilience), `JD` (judgment day). Example: `R2-001`. Lenses self-assign ids; judges return findings WITHOUT ids and the coordinator assigns `JD-{NNN}`.
- `lens` — originating lens or judge.
- `location` — `path:line`.
- `severity` — one of `BLOCKER | CRITICAL | WARNING | SUGGESTION`.
- `status` — one of `open | fixed | verified | refuted | wont-fix | info`.
- `evidence` — concrete evidence for the finding.
- `verification` — adversarial outcome: `refuter:corroborated|refuted|inconclusive`, `jd:both|a-only|b-only|contradiction`, or `—` (pre-verification / info rows).

## Precision Gate

Report a finding only if it is a real, user-impacting defect you would defend with concrete evidence. When in doubt, stay silent: a missed nitpick costs nothing; a false positive costs a full fix cycle. Style and preference findings are banned unless they obscure a defect.

## Persistence Mapping

Mode resolution is defined by `skills/_shared/persistence-contract.md` — this
contract never restates it, only maps the ledger destination per mode:

| Mode | Ledger destination |
|------|--------------------|
| `engram` | Upsert topic `sdd/{change-name}/review-ledger` (type `architecture`, naming per `skills/_shared/engram-convention.md`). Ad-hoc target without a change: topic `review/{target-slug}/ledger` |
| `openspec` | `openspec/changes/{change-name}/review-ledger.md` |
| `none` | Inline in the conversation; the review loop completes within the session |

An empty ledger (zero findings) is ALWAYS persisted, recording the triage
decision and lenses run (mode `none`: reported inline instead).

## Attribution

Adapted from gentle-ai (github.com/Gentleman-Programming/gentle-ai), MIT.
