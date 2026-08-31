# Engram Artifact Convention (shared across all SDD skills)

## Naming Rules

ALL SDD artifacts persisted to Engram MUST follow this deterministic naming:

```
title:     sdd/{change-name}/{artifact-type}
topic_key: sdd/{change-name}/{artifact-type}
type:      architecture
project:   {detected or current project name}
scope:     project
```

### Artifact Types (exact strings)

These ten types are change-scoped: title and `topic_key` are both `sdd/{change-name}/{artifact-type}`. This table is the single source of truth for artifact enumeration.

| Artifact Type | Produced By | Description |
|---------------|-------------|-------------|
| `explore` | sdd-explore | Exploration analysis |
| `brainstorm` | sdd-orchestrator | Brainstorm summary from discovery loop |
| `proposal` | sdd-propose | Change proposal |
| `spec` | sdd-spec | Delta specifications (all domains concatenated) |
| `design` | sdd-design | Technical design |
| `tasks` | sdd-tasks | Task breakdown |
| `apply-progress` | sdd-apply | Implementation progress (one per batch) |
| `review-ledger` | sdd-review | Review findings ledger — topic `sdd/{change-name}/review-ledger` |
| `verify-report` | sdd-verify | Verification report |
| `archive-report` | sdd-archive | Archive closure with lineage |

### Cycle State Cache

| Artifact Type | Produced By | Description |
|---------------|-------------|-------------|
| `status` | sdd-orchestrator | Cached cycle-state projection at `sdd/{change-name}/status` |

The cache is written by the orchestrator; `/sdd-status` is read-only and never writes it. It is a cache and never the authority — live enumeration of the ten types above always wins, and a stale or missing cache costs one enumeration pass, never correctness.

### Gate STOP Record

| Artifact Type | Produced By | Description |
|---------------|-------------|-------------|
| `gate-stop` | sdd-orchestrator | Unresolved phase-gate STOP at `sdd/{change-name}/gate-stop` |

A STOP has to outlive the session that produced it. Without a durable record, a compacted
orchestrator re-reads the cycle, sees the phase's own artifact present, and feeds an artifact
that never cleared the gate to the phase downstream. So the STOP is written here, one per
change, upserted, and read back by live enumeration like any other topic.

This record is NOT one of the ten registered types above and MUST NOT appear in the
`artifacts` map of the cycle-state projection. It is cleared when the same phase later passes
the gate, and rewritten when the user overrides the STOP.

### Exceptions to Change-Scoped Naming

| Topic form | Scope | When |
|------------|-------|------|
| `sdd-init/{project}` | project-scoped | Project context written by sdd-init |
| `sdd/specs/{domain}` | domain-scoped | Main specs — one observation per domain, merged at archive |
| `review/{target-slug}/ledger` | target-scoped | A review with no active change: an ad-hoc target outside the `sdd/{change-name}/` namespace |

### Example

```
mem_save(
  title: "sdd/add-dark-mode/proposal",
  topic_key: "sdd/add-dark-mode/proposal",
  type: "architecture",
  project: "my-app",
  content: "# Proposal: Add Dark Mode\n\n..."
)
```

## Recovery Protocol (2 steps — MANDATORY)

To retrieve an artifact, ALWAYS use this two-step process:

```
Step 1: Search by topic_key pattern
  mem_search(query: "sdd/{change-name}/{artifact-type}", project: "{project}")
  → Returns a truncated preview with an observation ID

Step 2: Get full content (REQUIRED)
  mem_get_observation(id: {observation-id from step 1})
  → Returns complete, untruncated content
```

NEVER use `mem_search` results directly as the full artifact — they are truncated previews.
ALWAYS call `mem_get_observation` to get the complete content.

### Retrieving Multiple Artifacts

When a skill needs multiple artifacts (e.g., sdd-tasks needs proposal + spec + design):

```
1. mem_search(query: "sdd/{change-name}/proposal", project: "{project}") → get ID
2. mem_search(query: "sdd/{change-name}/spec", project: "{project}") → get ID
3. mem_search(query: "sdd/{change-name}/design", project: "{project}") → get ID
4. mem_get_observation(id) for EACH → full content
```

### Loading Project Context

```
mem_search(query: "sdd-init/{project}", project: "{project}") → get ID
mem_get_observation(id) → full project context
```

### Browsing All Artifacts for a Change

```
mem_search(query: "sdd/{change-name}/", project: "{project}")
→ Returns all artifacts for that change
```

## Writing Artifacts

### Standard Write (new artifact)

```
mem_save(
  title: "sdd/{change-name}/{artifact-type}",
  topic_key: "sdd/{change-name}/{artifact-type}",
  type: "architecture",
  project: "{project}",
  content: "{full markdown content}"
)
```

### Update Existing Artifact

When updating an artifact you already retrieved (e.g., marking tasks complete):

```
mem_update(
  id: {observation-id},
  content: "{updated full content}"
)
```

Use `mem_update` when you have the exact observation ID. Use `mem_save` with the same `topic_key` for upserts (Engram deduplicates by topic_key).

## Why This Convention Exists

- **Deterministic titles** → recovery works by exact match, not fuzzy search
- **`topic_key`** → enables upserts (updating same artifact without creating duplicates)
- **`sdd/` prefix** → namespaces all SDD artifacts away from other Engram observations
- **Two-step recovery** → `mem_search` previews are always truncated; `mem_get_observation` is the only way to get full content
- **Lineage** → archive-report includes all observation IDs for complete traceability
