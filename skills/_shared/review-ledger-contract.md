# Review Ledger Contract (canonical — shared across the SDD review system)

Single source of truth for the review ledger. Review agents and SDD skills
reference this file by path; they never duplicate its schema or its numbers.
Every numeric budget and ceiling of the review system lives ONLY in this file
(triage thresholds live in `skills/sdd-review/SKILL.md`).

## 1. Roles

| Role | Actor | Ledger access |
|------|-------|---------------|
| Coordinator | `sdd-review` skill (lead level) | The ONLY ledger writer: merges rows, assigns JD ids, applies verdicts, persists/upserts |
| Lens | `review-risk`, `review-readability`, `review-reliability`, `review-resilience` | Emits candidate rows in its reply; never persists |
| Judge | `jd-judge-a`, `jd-judge-b` | Emits findings without ids in its reply; never persists |
| Refuter | `review-refuter` | Emits verdict lines in its reply; never persists |
| Fix agent | `jd-fix-agent` | Reports fixed ids + evidence in its reply; never edits the ledger |

## 2. Ledger Schema

Every ledger starts with a header recording: change (or ad-hoc target), tier,
date, and round. Finding rows follow this table:

| id | lens | location | severity | status | evidence | verification |
|----|------|----------|----------|--------|----------|--------------|

- `id` — `{PREFIX}-{NNN}` with fixed prefixes: `R1` (risk), `R2` (readability), `R3` (reliability), `R4` (resilience), `JD` (judgment day). Example: `R2-001`. Lenses self-assign ids; judges return findings WITHOUT ids and the coordinator assigns `JD-{NNN}`.
- `lens` — originating lens or judge.
- `location` — `path:line`.
- `severity` — one of `BLOCKER | CRITICAL | WARNING | SUGGESTION`.
- `status` — one of `open | fixed | verified | refuted | wont-fix | deferred | info`.
- `evidence` — concrete evidence for the finding.
- `verification` — adversarial outcome: `refuter:corroborated|refuted|inconclusive`, `jd:both|a-only|b-only|contradiction`, or `—` (pre-verification / info rows).

## 3. Precision Gate

Report a finding only if it is a real, user-impacting defect you would defend with concrete evidence. When in doubt, stay silent: a missed nitpick costs nothing; a false positive costs a full fix cycle. Style and preference findings are banned unless they obscure a defect.

## 4. Sweep Budget

- Standard review: exactly 1 exhaustive sweep of the diff per lens, then stop.
- Full-4R review: at most 2 sweeps per lens.
- There is no loop-until-dry mechanism; the sweep budget is the entire pass.
- The coordinator passes `tier` in every delegate prompt; agents apply the
  budget for that tier and never triage themselves.

## 5. Severity Floor

- Only BLOCKER/CRITICAL findings that survive adversarial verification enter
  the fix → re-review loop.
- WARNING/SUGGESTION findings are recorded exactly once with status `info`.
  They are never sent to refutation, never re-reviewed in later rounds, and
  never block archive.
- `info` is terminal (§9).

## 6. Refutation Protocol

- The coordinator invokes refutation once, after merging lens rows and before
  any fix work. Only BLOCKER/CRITICAL candidates are included in the batch.
- The task ceiling is review-level and structural: exactly 1 refuter task
  (lens `general`) for a standard review; exactly 3 refuter tasks (lenses
  `correctness`, `exploitability-impact`, `reproducibility`, in parallel) for
  full-4R — whether the candidate list has 2 findings or 20. NEVER dispatch
  one refuter task per finding.
- Every refuter task receives the complete merged candidate list and returns
  one verdict per finding id.
- Standard review: a finding is `refuted` only when the general verdict
  refutes it.
- Full-4R: voting is independent per finding — a finding is refuted (killed)
  only when at least 2 of the 3 lens verdicts refute it; a 1-of-3 result or
  tie keeps it standing.
- A malformed or missing per-finding verdict defaults to `stands` for that
  finding: it survives and remains open, never silently dropped.
- Judgment Day exception: two-judge convergence (§7) replaces refutation; no
  refuter is dispatched in JD mode.

## 7. Judgment Day Corroboration

- Both judges report the same finding (matched by location and claim) → `confirmed`: status `open`, verification `jd:both`. Confirmed findings become fixable ONLY after the user is asked and approves proceeding to fix.
- Exactly one judge reports it → `suspect`: status stays `open`, verification `jd:a-only` or `jd:b-only`. A suspect finding is NEVER auto-fixed.
- The judges contradict each other on the same location → verification `jd:contradiction`: escalate to the human; automated handling stops for that finding.
- Suspect and contradiction findings resolve only by user decision (fix or wont-fix).

## 8. Fix-Round Budget

- Maximum 2 fix rounds per review.
- One fix round = the coordinator dispatches `jd-fix-agent` once with ALL
  confirmed open BLOCKER/CRITICAL ids, then a scoped re-review by the
  originating lens(es)/judges over the frozen ledger plus the immutable fix
  delta only — never a fresh full-diff review. Rows with status `info` are
  excluded from re-review.
- Re-review confirms a fix → `verified`; re-review rejects it → back to `open`.
- Anything still open after round 2 is reported to the user as open — the
  loop never extends; no round 3 exists.

## 9. Status Transitions

```
open  → refuted    (adversarial verification killed it)
open  → fixed      (jd-fix-agent applied a fix; the coordinator records it)
open  → wont-fix   (user decision only)
open  → deferred   (user decision only; routed to a named destination)
fixed → verified   (scoped re-review confirmed the fix)
fixed → open       (scoped re-review rejected the fix)
```

- `wont-fix` REQUIRES evidence appended in the exact form
  `wont-fix — user decision (YYYY-MM-DD): {reason}`. The agent NEVER sets
  wont-fix on its own; only the user authorizes it and the coordinator
  records it.
- `deferred` REQUIRES evidence appended in the exact form
  `deferred — user decision (YYYY-MM-DD): {destination}: {reason}`. The
  destination segment is MANDATORY: it identifies where the finding was routed,
  the user supplies it, and this contract stays tracker-agnostic — it names no
  tracker and assumes none exists. Evidence carrying a reason but no
  destination does NOT close the row: it counts as open and blocks. The agent
  NEVER sets deferred on its own; only the user authorizes it and the
  coordinator records it.
- `info` is terminal: assigned once to WARNING/SUGGESTION rows, never revisited.
- `verified`, `refuted`, evidenced `wont-fix` and evidenced `deferred` are the
  only CLOSED states for BLOCKER/CRITICAL rows, and that set is exactly the
  archive pass set of §11.
- The TERMINAL states are those four plus `info`: a terminal row is resolved and
  never revisited. Terminal is the union, closed is the BLOCKER/CRITICAL gate
  set, and severity-floor rows are the only members of the first that are not
  members of the second. A consumer asking §9 for the terminal states gets
  these five.

## 10. Persistence Mapping

Mode resolution is defined by `skills/_shared/persistence-contract.md` — this
contract never restates it, only maps the ledger destination per mode:

| Mode | Ledger destination |
|------|--------------------|
| `engram` | Upsert topic `sdd/{change-name}/review-ledger` (type `architecture`, naming per `skills/_shared/engram-convention.md`). Ad-hoc target without a change: topic `review/{target-slug}/ledger` |
| `openspec` | `openspec/changes/{change-name}/review-ledger.md` |
| `none` | Inline in the conversation; the review loop completes within the session |

An empty ledger (zero findings) is ALWAYS persisted, recording the triage
decision and lenses run (mode `none`: reported inline instead).

## 11. Archive Gate

`sdd-archive` (Step 0) enforces this rule over the persisted ledger:

- The archive pass set is exactly the CLOSED states of §9: `verified`,
  `refuted`, evidenced `wont-fix` and evidenced `deferred`.
- BLOCK archive while any BLOCKER or CRITICAL row has a status outside that
  pass set. `open` rows, un-reverified `fixed` rows, and JD suspect rows all
  mean the review loop did not converge — the user must decide, never the
  agent.
- `wont-fix` counts as closed ONLY with the recorded explicit user decision
  in the §9 evidence form.
- `deferred` counts as closed ONLY with the recorded explicit user decision in
  the §9 evidence form, destination included.
- A ledger whose BLOCKER/CRITICAL rows are closed only by deferred decisions
  PASSES this gate. The archive proceeds with those findings unfixed, by
  design, because the user routed each of them to a named destination:
  `sdd-review` reports that ledger as `REVIEW: RESOLVED` and the cycle
  continues to verification. This is the intended behaviour, not a hole in the
  gate.
- No check can validate a real ledger row. Ledgers live in the artifact store
  or in the user's own project, while both checkers run over the plugin repo,
  so this contract mandates the form and the reader applies it. A mandated
  form is never a validated row.
- If no ledger exists for the change, warn that the change was implemented
  without review and require explicit user confirmation before archiving
  (backwards compatibility for pre-review changes).

## 12. Maintenance

`agents/jd-judge-a.md` is the single source of truth for the judge body —
edit jd-judge-a.md only. `agents/jd-judge-b.md` is REGENERATED, never
hand-edited:

```
sed -e 's/jd-judge-a/jd-judge-b/g' -e 's/Judge A/Judge B/g' agents/jd-judge-a.md > agents/jd-judge-b.md
```

Drift check (also runnable as `scripts/check-judges.sh`, exits non-zero on
drift or a missing judge file):

```
diff <(sed -e 's/jd-judge-a/jd-judge-X/g' -e 's/Judge A/Judge X/g' agents/jd-judge-a.md) <(sed -e 's/jd-judge-b/jd-judge-X/g' -e 's/Judge B/Judge X/g' agents/jd-judge-b.md)
```

The only permitted A/B differences are the `name:` frontmatter value and the
Judge A / Judge B tokens in the description and identity line.

## 13. Attribution

Adapted from gentle-ai (github.com/Gentleman-Programming/gentle-ai), MIT.
