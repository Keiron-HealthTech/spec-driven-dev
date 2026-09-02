---
name: sdd-archive
description: >
  Sync delta specs to main specs and archive a completed change.
  Trigger: When the orchestrator launches you to archive a change after implementation and verification.
license: MIT
metadata:
  author: ai-workflow
  version: "2.0"
  scope: [root]
  auto_invoke: "Archiving a completed change"
---

> **ORCHESTRATOR GATE** — If you loaded this file with the Skill tool, you are the
> ORCHESTRATOR: STOP. Do NOT execute these instructions inline. Launch a sub-agent with
> `Task(subagent_type: 'general')` whose prompt names this skill file and the absolute
> path to `skills/_shared/sdd-status-contract.md`, per the Sub-Agent Launching Pattern in
> `skills/sdd-orchestrator/SKILL.md`. This file is for EXECUTORS.

## Executor Override

If you ARE the sub-agent launched for this phase — your prompt told you to read this skill
file and follow it — the gate above does NOT apply to you. Do not delegate, do not call the
Skill tool, do not read the gate as an instruction to stop. You are the executor: execute
the phase work below and return the §2 envelope.

## Purpose

You are a sub-agent responsible for ARCHIVING. You merge delta specs into the main specs (source of truth), then move the change folder to the archive. You complete the SDD cycle.

## What You Receive

From the orchestrator:
- Change name
- Artifact store mode (`engram | openspec | none`)

## Execution and Persistence Contract

Read and follow `skills/_shared/persistence-contract.md` for mode resolution rules.

- If mode is `engram`: Read and follow `skills/_shared/engram-convention.md`. Artifact type: `archive-report`. Retrieve `verify-report`, `proposal`, `spec`, `design`, and `tasks` as dependencies. Include all artifact observation IDs in the archive report for full traceability.
- If mode is `openspec`: Read and follow `skills/_shared/openspec-convention.md`. Perform merge and archive folder moves.
- If mode is `none`: Return closure summary only. Do not perform archive file operations.

## What to Do

### Step 0: Review Gate (BLOCKING)

Before any spec sync or archive move, retrieve the change's review ledger
(schema and destinations defined in `skills/_shared/review-ledger-contract.md`):

- `engram` → topic `sdd/{change-name}/review-ledger`, using the two-step recovery from `skills/_shared/engram-convention.md` (`mem_search` then `mem_get_observation`)
- `openspec` → `openspec/changes/{change-name}/review-ledger.md`
- `none` → the orchestrator provides the inline ledger from the review phase

Then evaluate the gate (canonical rule: `skills/_shared/review-ledger-contract.md` §11 — the LEDGER contract, not the status contract):

- The archive pass set is `verified`, `refuted`, evidenced `wont-fix` and evidenced `deferred`. This inline set is a MIRROR of `skills/_shared/review-ledger-contract.md` §11, kept because an executor that cannot resolve that path still has to hold the rule; CI asserts the two set-equal.
- **BLOCK** the archive if any BLOCKER or CRITICAL row has a status outside that pass set. `open` rows, un-reverified `fixed` rows, and JD `suspect` rows all block — a `fixed` row without a verifying re-review is NOT closed; the review loop did not converge and the user must decide, never the agent. Return `status: blocked` and list every offending row (id, location, severity, status).
- On a blocked archive set `next_recommended: resolve-review`; the user chooses a fix round, an explicit wont-fix decision, or an explicit deferred decision naming a destination.
- `wont-fix` closes a row ONLY when its evidence records an explicit user decision in the exact form `wont-fix — user decision (YYYY-MM-DD): {reason}`. A wont-fix row without a recorded user decision counts as open and blocks. NEVER set wont-fix yourself — only the user can authorize it, and the sdd-review coordinator records it.
- `deferred` closes a row ONLY when its evidence records an explicit user decision in the exact form `deferred — user decision (YYYY-MM-DD): {destination}: {reason}`. The destination segment is MANDATORY: a deferred row whose evidence names no destination counts as open and blocks. NEVER set deferred yourself — only the user can authorize it, and the sdd-review coordinator records it. This inline rule is a MIRROR of `skills/_shared/review-ledger-contract.md` §9, kept because an executor that cannot resolve that path still has to hold the rule; CI asserts the two carry the same form.
- Rows with status `info` never block (severity floor, `skills/_shared/review-ledger-contract.md` §5).
- If no ledger exists, WARN that this change was implemented without review and require explicit user confirmation before proceeding (backwards compatibility for pre-review changes).
- Audit trail: List all `wont-fix`, `deferred` and `info` rows in the archive report, naming for each `deferred` row the destination its evidence records, and include the ledger observation ID in the lineage.

### Step 1: Sync Delta Specs to Main Specs

The delta spec becomes part of the main specs. Where both live depends on the active mode —
resolution in `skills/_shared/persistence-contract.md`.

#### In `openspec` mode

For each delta spec in `openspec/changes/{change-name}/specs/`:

##### If Main Spec Exists (`openspec/specs/{domain}/spec.md`)

Read the existing main spec and apply the delta:

```
FOR EACH SECTION in delta spec:
├── ADDED Requirements → Append to main spec's Requirements section
├── MODIFIED Requirements → Replace the matching requirement in main spec
└── REMOVED Requirements → Delete the matching requirement from main spec
```

**Merge carefully:**
- Match requirements by name (e.g., "### Requirement: Session Expiration")
- Preserve all OTHER requirements that aren't in the delta
- Maintain proper Markdown formatting and heading hierarchy

##### If Main Spec Does NOT Exist

The delta spec IS a full spec (not a delta). Copy it directly:

```bash
# Copy new spec to main specs
openspec/changes/{change-name}/specs/{domain}/spec.md
  → openspec/specs/{domain}/spec.md
```

#### In `engram` mode

The delta is ONE observation at topic `sdd/{change-name}/spec`, with every domain concatenated
into it. The main specs are one observation per domain at `sdd/specs/{domain}`. Sync like this:

1. Split the delta on its domain headers. **The domain set is the delta's `# Domain:` headers
   and nothing else** — in particular it is NOT the delta header's "main specs read" line, which
   records what the author consulted while writing, sits two lines away, and sounds more
   authoritative. Merging into a spec the delta only read overwrites untouched content and
   strands the domain it did produce. A multi-domain delta produces **one upsert per domain**,
   never one merged observation. Delta material sitting **outside any domain section** belongs
   to EVERY domain the split produces: whatever sits above the first domain header — a legend, a
   shared preamble, a mode note — and whatever sits below the last, which is where the Coverage
   Summary, Risks and Lineage trailer live.
   Carry it into each upsert. Leaving it in the first domain only, or dropping it because the
   split did not name it, strands every scenario that keys on it.
2. **Snapshot before you write.** For each `sdd/specs/{domain}` the merge will touch, save its
   retrieved body unchanged at `sdd/specs/{domain}/pre-merge-{YYYY-MM-DD}` and **record every
   snapshot's observation id in the archive report — before the first upsert.** Upsert replaces
   the body wholesale and engram has no revert, so this snapshot is the only way back. A
   snapshot taken after the write is a copy of the damage; an id nobody recorded is not a
   recovery path. The archive report is this phase's LAST artifact, so satisfying both orderings
   takes two passes: write a **stub** archive report carrying the snapshot ids first, then upsert
   the finished report over the same topic at the end. Without the stub the two requirements
   cannot both hold, and the reading that satisfies the words leaves the snapshot unfindable.
   The `openspec` branch needs none of this: git is already its snapshot.
3. Retrieve `sdd/specs/{domain}` for each domain the delta touches. If it does not exist, that
   domain's section IS the full main spec — upsert it as it stands.
4. If it does exist, merge requirement by requirement, matching requirements by name:
   - ADDED → append the requirement to the main spec
   - MODIFIED → replace the requirement the delta names
   - REMOVED → delete the requirement the delta names
5. **Preserve every requirement the delta does not mention.** Upsert replaces the observation
   body wholesale, so a requirement omitted from the merge is a requirement deleted from the
   spec.
6. **Preserve everything in the main spec that is not a requirement.** A main spec's header can
   carry adjudications, a decision record, a pass set — material no delta mentions and the
   requirement-by-requirement walk in step 4 never visits, so matching on `### Requirement:`
   alone silently deletes it. Carry the header, any preamble and any decision record forward
   verbatim unless the delta explicitly replaces them.
7. Record any design-over-spec adjudication applied while merging in BOTH the main spec and the
   archive report. The merge is where an adjudication stops being a note and becomes the source
   of truth.
8. **Measure the merged body before you write it, and STOP short of the store's limit.** Rules 1
   and 6 grow a main spec on every merge and copy the shared material into each domain, so a
   domain only ever gets bigger. Engram truncates silently and reports success, so an over-limit
   upsert is a deletion of the tail with no error to notice: within 10% of **50,000 bytes**, do
   not write it — STOP, report the measured size, and let a human decide whether to split the
   domain. After every upsert, **read it back** and confirm the stored body ends on the last
   line you authored; a round-trip is the only proof the write survived.

Topic forms and naming come from `skills/_shared/engram-convention.md`; this step defines none.

### Step 2: Move to Archive

Move the entire change folder to archive with date prefix:

```
openspec/changes/{change-name}/
  → openspec/changes/archive/YYYY-MM-DD-{change-name}/
```

Use today's date in ISO format (e.g., `2026-02-16`).

### Step 3: Verify Archive

Confirm:
- [ ] Main specs updated correctly
- [ ] Change folder moved to archive
- [ ] Archive contains all artifacts (proposal, specs, design, tasks)
- [ ] Active changes directory no longer has this change

### Step 4: Return Summary

Return to the orchestrator:

```markdown
## Change Archived

**Change**: {change-name}
**Archived to**: openspec/changes/archive/{YYYY-MM-DD}-{change-name}/

### Specs Synced
| Domain | Action | Details |
|--------|--------|---------|
| {domain} | Created/Updated | {N added, M modified, K removed requirements} |

### Archive Contents
- proposal.md ✅
- specs/ ✅
- design.md ✅
- tasks.md ✅ ({N}/{N} tasks complete)

### Review Gate (Step 0)
**Ledger**: {topic + observation id | path | inline | none — archived on explicit user confirmation}
**Wont-fix rows**: {id — recorded user decision | none}
**Deferred rows**: {id — destination — recorded user decision | none}
**Info rows**: {ids | none}

### Source of Truth Updated
The following specs now reflect the new behavior:
- `openspec/specs/{domain}/spec.md`

### SDD Cycle Complete
The change has been fully planned, implemented, verified, and archived.
Ready for the next change.
```

## Superpowers Integration

### Branch Completion
After archiving, the orchestrator will invoke `superpowers:finishing-a-development-branch`.
Your job is ONLY the archive (spec sync + folder move). Branch completion is handled separately.

## Rules

- NEVER archive a change that has CRITICAL issues in its verification report
- NEVER archive while the review ledger has open BLOCKER/CRITICAL rows (Step 0)
- ALWAYS sync delta specs BEFORE moving to archive
- When merging into existing specs, PRESERVE requirements not mentioned in the delta
- Use ISO date format (YYYY-MM-DD) for archive folder prefix
- If the merge would be destructive (removing large sections), WARN the orchestrator and ask for confirmation
- The archive is an AUDIT TRAIL — never delete or modify archived changes
- If `openspec/changes/archive/` doesn't exist, create it
- Apply any `rules.archive` from `openspec/config.yaml`
- Return the canonical envelope defined in `skills/_shared/sdd-status-contract.md` §2; `status` values come from §2 and every `next_recommended` value from the CLOSED §3 vocabulary — never invent a field, a status value, or a routing token
