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
  proposal · spec · design · tasks · apply · review · verify · archive
nextRecommended: <one §3 token>
blockedReasons: []
```

### The five components

1. **`artifacts`** — one entry per change-scoped type registered in
   `skills/_shared/engram-convention.md`, currently ten. A type absent from that registry
   MUST NOT appear in the map.
2. **`taskProgress`** — exactly `total`, `completed`, `pending`, `allComplete`, where
   `pending = total - completed` and `allComplete = (total > 0 AND completed == total)`.
   With no tasks artifact: `total = 0`, `allComplete = false`.
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

TBD.

## 6. Dependency States

TBD.

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

TBD.

## 9. Gate State Machine

TBD.

## 10. Persistence Mapping

TBD.

## 11. Gate Precedence (G1 / G2 / G3)

TBD.

## 12. Limits — What This Contract Cannot Enforce

TBD.

## 13. Maintenance and Drift Check

TBD.
