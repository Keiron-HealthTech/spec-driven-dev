# SDD Status Contract (canonical — shared across all SDD skills, agents, and commands)

Single source of truth for cycle state: the sub-agent return envelope, its two closed
enums, the `/sdd-status` projection, and the phase gate. Skills, agents, and commands
reference this file by path and cite its section numbers; they never duplicate its
values. Every enum and every number of the status system lives ONLY in this file.

## 1. Roles and Contract Resolution

| Role | Actor | Status access |
|------|-------|---------------|
| Producer | every phase sub-agent | Returns the §2 envelope; writes no projection |
| Renderer | `/sdd-status` | Builds the §4 projection by §7 enumeration; read-only in every mode |
| Router | `sdd-orchestrator` | Consumes the envelope and the projection; the only writer of the §10 cache |
| Validator | the phase validator dispatched at a §8 boundary | Reads artifacts to apply the gate checks; writes nothing |

### Contract Resolution

The canonical status contract is `skills/_shared/sdd-status-contract.md`, located relative
to the SKILL.md that loads it: `{directory of that SKILL.md}/../_shared/sdd-status-contract.md`.
Resolve it to an ABSOLUTE path once, at the start of the cycle, and pass that absolute path
in every delegate prompt. Never pass a project-relative path: sub-agents run with the user's
project as cwd and cannot locate the plugin themselves.

Command files are the one documented exception: Claude Code substitutes `${CLAUDE_PLUGIN_ROOT}`
inside `commands/*.md`, so a command names this file as
`${CLAUDE_PLUGIN_ROOT}/skills/_shared/sdd-status-contract.md`. Skill files cannot use that
variable and MUST use the absolute path above.

If the resolved path is unreadable, the reader's own inline invariants are authoritative, and
the degradation MUST be reported rather than guessed around.

### Modes

This contract applies unchanged in all three artifact store modes — `engram`, `openspec` and
`none` — and §10 maps a persistence destination for each. Mode RESOLUTION is owned by
`skills/_shared/persistence-contract.md` and is never restated here.

## 2. Return Envelope Schema

Every sub-agent returns exactly these six fields, and nothing else is part of the envelope.

| Field | Type | Required | Meaning |
|-------|------|----------|---------|
| `status` | enum `done \| partial \| blocked` | yes | `done` = the artifact was produced and its acceptance met; `partial` = §5 only; `blocked` = the phase could not complete |
| `executive_summary` | string, 1–3 sentences | yes | What the orchestrator shows the user |
| `detailed_report` | markdown | no | The full trace |
| `artifacts` | array of `{name, topic_key \| path, observation_id?}` | yes (may be empty) | What was persisted, by reference |
| `next_recommended` | array of §3 tokens, normally one | yes | Routing. Never prose |
| `risks` | array of strings | yes (may be empty) | When `status` is `blocked`, carries the blocking reasons |

This section is the ONLY definition site of the envelope and of the `status` enum. Consumers
cite `§2` by path; a file that enumerates three or more field names, or restates the `status`
values as a literal list, is drift and fails `scripts/check-envelope.sh`.

## 3. `next_recommended` Vocabulary (CLOSED)

The vocabulary is CLOSED at thirteen tokens. Every `next_recommended` value anywhere in this
plugin is one of them; a value outside this table is invalid, not an extension.

| Token | Orchestrator action |
|-------|---------------------|
| `propose` / `spec` / `design` / `tasks` / `apply` / `verify` / `archive` | Launch the corresponding sub-agent |
| `review` | Load `sdd-review` at LEAD level (orchestrator Rule 10 exception (b)) |
| `remediate` | Re-run the failed phase with corrective feedback; for an apply or verify failure, launch `sdd-debug` |
| `resolve-blockers` | STOP. Report the blocking reasons; launch no phase |
| `resolve-review` | STOP. Present the open ledger rows; the user decides (`review-ledger-contract.md` §11) |
| `select-change` | Ask the user which change. Never guess |
| `sdd-new` | No active change exists; suggest `/sdd-new {name}` |

**Route by the token, never by the prose.** The consumer reads the token and acts. It MUST NOT
parse an English sentence to infer intent, and MUST NOT accept a free-form value such as
`"resume sdd-apply"`: an unrecognised value is an error to report, never a sentence to
interpret. `executive_summary` explains; only the token routes.

**Citation form.** Outside this contract a concrete value appears ONLY as `` `next_recommended:
{token}` `` or inside a JSON `"next_recommended": ["{token}"]` array. This is what makes
membership mechanically checkable: the looser reading — any backticked kebab-case word near a
mention of `next_recommended` — false-positives on unrelated vocabularies such as `wont-fix`
and `full-4r`.

`remediate` is load-bearing, not vestigial: it is the gate's second-attempt route and
`sdd-verify`'s failure route, and it is what dispatches `sdd-debug`. There is deliberately no
`explore` or `brainstorm` token: discovery is orchestrator-owned (Rule 10(a)), so there is no
delegate to route back from and the vocabulary correctly starts at `propose`.

Adding a token means editing this table and nothing else. Every consumer cites `§3`.

## 4. Status Projection

`/sdd-status` returns this projection, `sdd.status/v1`, and nothing else.

```yaml
schemaName: sdd.status
schemaVersion: 1
changeName: <name|null>
artifactStore: engram | openspec | none
artifacts:
  brainstorm / explore / proposal / spec / design / verify-report / archive-report:
      missing | done                    # BINARY (7 types)
  tasks / apply-progress / review-ledger:
      missing | done | partial          # COUNTABLE (3 types)
artifactRefs:
  <type>: { topic_key: <string>, observation_id: <int|null> }   # engram
  <type>: { path: <absolute path> }                             # openspec
taskProgress: { total: 0, completed: 0, pending: 0, allComplete: false }
dependencies:   # one key per phase, each: blocked | ready | all_done
  brainstorm / proposal / spec / design / tasks / apply / review / verify / archive
nextRecommended: <one §3 token>
blockedReasons: []
```

### The five components

1. **`artifacts`** — one entry per change-scoped type registered in
   `skills/_shared/engram-convention.md`, currently ten. A type absent from that registry
   MUST NOT appear in the map.
2. **`taskProgress`** — exactly `total`, `completed`, `pending`, `allComplete`. It spans two
   artifacts, because neither one knows both halves: the plan knows how many tasks exist, the
   record of work knows how many were done.
   - `total` — the number of task ids in the `tasks` artifact, counting headings that match
     `### T{phase}.{n}`. No tasks artifact: `0`.
   - `completed` — the number of those tasks carrying recorded evidence in the `apply-progress`
     artifact. No apply-progress artifact yet: `0`, which is honest — nothing has been applied.
   - `pending` — `total - completed`.
   - `allComplete` — `total > 0` and `pending == 0`. With no tasks artifact, `total` is `0`
     and `allComplete` is false.
3. **`dependencies`** — one state per phase, per §6.
4. **`blockedReasons`** — an array, empty when nothing is blocked. Each entry MUST name at
   least one registered artifact type or a review ledger row id, and MUST NOT carry a claim
   inferred from prose.
5. **`nextRecommended`** — exactly one §3 token and no explanation. Explanations belong in
   `blockedReasons`.

The per-type value sets in the schema encode §5 structurally: the seven BINARY types have no
partial value available to report.

### `nextRecommended` derivation — ORDERED, first match wins

Evaluate the rows in the order given and STOP at the first whose condition holds. The
conditions are mutually exclusive and exhaustive, so identical artifact state always yields
the same token.

| Order | Condition | Token |
|-------|-----------|-------|
| 1 | No change selected and at least one change exists | `select-change` |
| 2 | No change exists, or the selected change has zero artifacts | `sdd-new` |
| 3 | A gatekeeper STOP is recorded for the change | `resolve-blockers` |
| 4 | The review ledger has a row blocking archive (`review-ledger-contract.md` §11) | `resolve-review` |
| 5 | A `verify-report` exists and records non-compliance | `remediate` |
| 6 | Otherwise: the first phase in DAG order whose dependency state is `ready` | that phase's token |
| 7 | All phases `all_done` | `archive` when the archive-report is missing, otherwise `select-change` |

## 5. The `partial` Rule

`partial` is permitted ONLY where the artifact itself carries a countable signal. Exactly
three of the ten registered change-scoped types do:

| Type | Countable signal | `partial` when |
|------|------------------|----------------|
| `tasks` | task lines marked `[x]` versus `[ ]` | at least one of each |
| `apply-progress` | tasks recorded complete versus tasks recorded in total | more than none and fewer than all |
| `review-ledger` | rows still open versus rows closed | at least one row is not in a terminal state (`review-ledger-contract.md` §9 — cited, never restated) |

The other seven types are BINARY — present is `done`, absent is `missing`, and they can never
be reported `partial`: `explore`, `brainstorm`, `proposal`, `spec`, `design`, `verify-report`,
`archive-report`. The per-type value sets in §4's schema encode this structurally, so a reader
cannot invent a partial `design` without editing the schema.

- A reader MUST NOT infer completeness from prose. An artifact whose body hedges — "TODO",
  "draft", an open question — but carries no countable signal is `done`, not `partial`.
- A type with no countable signal is NEVER `partial`. A `tasks` artifact written as task
  headings rather than checkbox lines carries no checkbox signal, so it is `done` once it
  exists.
- A type absent from the registry in `skills/_shared/engram-convention.md` MUST NOT appear in
  the `artifacts` map at all, and therefore can never be reported `partial`.
- Artifact state and `taskProgress` are separate signals and MUST NOT be conflated. A `tasks`
  artifact with every box unchecked is `done` AS AN ARTIFACT while `completed` is `0` and
  `allComplete` is false. `taskProgress` is derived per §4 from the `tasks` and
  `apply-progress` artifacts together; it is never read off this table.

## 6. Dependency States

`dependencies` reports one state per phase — `blocked | ready | all_done` — for the nine
phases of the graph `brainstorm` → `proposal` → { `spec`, `design` } → `tasks` → `apply` →
`review` → `verify` → `archive`.

- **`blocked`** — at least one upstream artifact is `missing`.
- **`ready`** — every upstream artifact is satisfied AND this phase's own artifact is `missing`
  or `partial`.
- **`all_done`** — every upstream artifact is satisfied AND this phase's own artifact is `done`.

| Phase | `ready` when |
|-------|--------------|
| `brainstorm` | always — it has no upstream, so it is never `blocked` |
| `proposal` | `brainstorm` is `all_done`, or the user supplied the intent directly |
| `spec` | `proposal` is `all_done` |
| `design` | `proposal` is `all_done` — parallel with `spec`; neither depends on the other |
| `tasks` | `spec` AND `design` are both `all_done` |
| `apply` | `tasks` is `all_done` and `taskProgress.allComplete` is false |
| `review` | the `apply-progress` artifact exists and `taskProgress.allComplete` is true |
| `verify` | `review` is `all_done` |
| `archive` | the `verify-report` is `done` AND `review` is `all_done` (`review-ledger-contract.md` §11) |

`all_done` means that phase's own artifact is `done`, with two exceptions: `apply` is
`all_done` when `taskProgress.allComplete` is true, and `review` is `all_done` when the ledger
closes per `review-ledger-contract.md` §11. Anything neither `ready` nor `all_done` is
`blocked`, and every blocked phase contributes one `blockedReasons[]` entry naming the missing
upstream artifact type(s) by their registered names. `blockedReasons` carries the explanation;
`nextRecommended` never does.

`sdd-debug` is NOT a phase of this graph. It can be invoked at any time, it has no upstream and
no dependents, and it MUST NOT appear in `dependencies`.

## 7. Artifact Enumeration and Recovery

**ENUMERATE, NEVER RECALL.** Cycle state MUST be reconstructed from the artifact store on
every read. The orchestrator's context window is NOT a source of state and MUST NOT be
consulted as one: a projection assembled from memory is invalid even when it happens to be
correct. This is what makes the projection survive a compaction, a `/clear`, or a new session.

The artifact TYPE list is owned by `skills/_shared/engram-convention.md`; this contract never
restates it.

- **`engram`** — for each registered type, `mem_search("sdd/{change-name}/{type}", project)`;
  on a hit, `mem_get_observation(id)`, per the two-step recovery protocol in
  `engram-convention.md`. No hit = `missing`. An ad-hoc review additionally probes
  `review/{target-slug}/ledger`.
- **`openspec`** — file existence per `skills/_shared/openspec-convention.md`.
- **`none`** — derived from the session's returned envelopes only, and labelled
  `artifactStore: none — session-scoped, not durable`.

## 8. Gate Checks

At every phase boundary the artifact just produced is validated against these five checks
before any dependent phase starts. This is their only definition site; consumers name them and
cite `§8`.

| # | Check | Definition |
|---|-------|------------|
| 1 | Contract conformance | The envelope carries every required §2 field, `status` is a §2 enum member, and every `next_recommended` value is a §3 token |
| 2 | Artifact existence | Every entry in `artifacts` resolves in the active store by §7 — the declared topic or path is actually readable |
| 3 | No hallucination | Every file, path, symbol, command and id the phase claims to have used or produced exists. Existence only, never quality |
| 4 | No drift from inputs | The content does not contradict the inputs the phase declared: proposal from brainstorm, spec and design from proposal, tasks from spec and design, apply from tasks |
| 5 | Routing coherence | The recommended token is reachable from the current §6 dependency state, and no unaddressed blocking risk remains |

**Dispatch is hybrid, by an explicit per-boundary mapping and never a heuristic.**

| Boundary | Validation |
|----------|------------|
| `explore`, `propose`, `spec`, `tasks`, `review`, `verify`, `archive` | inline |
| `design`, `apply` | a fresh-context sub-agent, dispatched as `spec-driven-dev:phase-validator` |

Discovery is orchestrator-owned and returns no delegate envelope, so it opens no boundary. An
inline boundary MAY be escalated to the fresh-context validator when a check smells wrong; the
reverse — downgrading `design` or `apply` to inline — is permitted only as the §9
`GATE: UNAVAILABLE` fallback, and is recorded when it happens.

Checks 1 and 2 are mechanically decidable in principle. **Checks 3, 4 and 5 are judgments
applied by an agent, not mechanical predicates**, and MUST NOT be written or reported as though
a tool decided them. None of the five is enforced by tooling — nothing in this repository can
run them, and §12 says why.

## 9. Gate State Machine

```
  attempt 1 ──envelope──▶ [ GATE — §8 checks 1-5 ]
                             │                    │
                        pass │                    │ fail
                             │                    ▼
                             │        attempt 2 — SAME phase, SAME inputs,
                             │        plus corrective feedback
                             │                    │ envelope
                             │                    ▼
                             │        [ GATE — §8 checks 1-5 ]
                             │            │                  │
                             │       pass │                  │ fail
                             ▼            ▼                  ▼
                   ┌────────────────────────┐      ┌──────────────────────┐
                   │        ADVANCE         │      │         STOP         │
                   │ route by the §3 token; │◀─────│   status: blocked    │
                   │ if a user gate is due, │ user │   blockedReasons[]   │
                   │ present there (§11.1)  │ over │   no dependent phase │
                   └────────────────────────┘ ride │   advances           │
                                                   └──────────────────────┘
```

- Terminal states: **ADVANCE** and **STOP**. There is no third outcome.
- Budget: the failed phase is re-run EXACTLY ONCE, with the failed check(s) passed back as
  corrective feedback. **There is no attempt 3 in this procedure** — no retry with a different
  prompt, no escalate-then-retry, no quiet extra pass.
- A second failure is a STOP: report `status: blocked` with one `blockedReasons[]` entry per
  failed check, and advance no dependent phase. **This is a report, not an approval request.**
  The gate never asks the user for permission to proceed.
- A user MAY override a STOP. The override REWRITES the overridden `blockedReasons[]` entry in
  the exact form `override — user decision (YYYY-MM-DD): {reason}`. Only the user authorises
  it; the agent never grants an override to itself.
- `GATE: UNAVAILABLE` is not a failure and does not consume the budget: degrade to inline
  validation and record `validator unavailable — inline fallback`.

## 10. Persistence Mapping

Mode resolution is owned by `skills/_shared/persistence-contract.md` and is never restated
here. This section maps only where the cached projection goes:

| Mode | Destination |
|------|-------------|
| `engram` | Upsert topic `sdd/{change-name}/status`, type `architecture`, named per `skills/_shared/engram-convention.md` |
| `openspec` | `openspec/changes/{change-name}/status.md` |
| `none` | Inline in the conversation; not persisted |

**The cached projection is a CACHE, never the authority.** Where it disagrees with a live §7
enumeration the enumeration wins and the cache is re-written from it. A stale or missing cache
is never an error: it costs one enumeration pass, never correctness. The orchestrator is its
only writer.

### Read-Only Guarantee for the Projection

Rendering the projection changes nothing, in any mode. In `engram` the renderer calls no write
tool: never `mem_save`, never `mem_update`, and it does not `persist` or `upsert` the cache.
In `openspec` it creates and modifies no file, `status.md` included. In `none` it reports
inline only. It creates no artifact of its own, and a run leaves the artifact store
byte-identical — two consecutive runs change no observation count and no revision number.
Refreshing the cache is the orchestrator's act, never the renderer's.

## 11. Gate Precedence (G1 / G2 / G3)

TBD.

## 12. Limits — What This Contract Cannot Enforce

TBD.

## 13. Maintenance and Drift Check

TBD.
