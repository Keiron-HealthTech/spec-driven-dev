# Persistence Contract (shared across all SDD skills)

## Mode Resolution

The orchestrator passes `artifact_store.mode` with one of: `engram | openspec | none`.

Default resolution (when orchestrator does not explicitly set a mode):
1. If Engram is available → use `engram`
2. Otherwise → use `none`

`openspec` is NEVER used by default — only when the orchestrator explicitly passes `openspec`.

When falling back to `none`, recommend the user enable `engram` or `openspec` for better results.

## Behavior Per Mode

| Mode | Read from | Write to | Project files |
|------|-----------|----------|---------------|
| `engram` | Engram (see `engram-convention.md`) | Engram | Never (Domain Files excepted) |
| `openspec` | Filesystem (see `openspec-convention.md`) | Filesystem | Yes |
| `none` | Orchestrator prompt context | Nowhere | Never (Domain Files excepted) |

## Common Rules

- If mode is `none`, do NOT create or modify any project files. Return results inline only — except Domain Files, below.
- If mode is `engram`, do NOT write any project files. Persist to Engram and return observation IDs — except Domain Files, below.
- If mode is `openspec`, write files ONLY to the paths defined in `openspec-convention.md` — except Domain Files, below.
- NEVER force `openspec/` creation unless the orchestrator explicitly passed `openspec` mode.
- If you are unsure which mode to use, default to `none`.

## Domain Files

Domain files are project knowledge, not SDD artifacts: `GLOSSARY.md`, `GLOSSARY-MAP.md` and the
per-context glossaries it lists, ADRs under `docs/adr/` and, in the map layout,
`{context}/docs/adr/`, and the one pointer line in an existing
`CLAUDE.md` or `AGENTS.md`. Their formats and roles are defined in
`skills/_shared/domain-contract.md`. They are the one exception to the Common Rules above, and
the exception names these files only: it widens nothing an `openspec` artifact write may touch,
and `openspec/` is never created on their account.

| Mode | Read | Write |
|------|------|-------|
| `engram` | Always, from the repo | The orchestrator only: a term or ADR resolved with the user, or a pointer the user accepted |
| `openspec` | Always, from the repo | Same as `engram` |
| `none` | Always, from the repo | The orchestrator only, and only on the user's explicit request |

- The repo files are the source of truth in every mode. Engram holds only the layout, inside
  `sdd-init/{project}`, never their content.
- Phase sub-agents never write domain files, in any mode.
- They are never a registered artifact type and never move at archive.

## Detail Level

The orchestrator may also pass `detail_level`: `concise | standard | deep`.
This controls output verbosity but does NOT affect what gets persisted — always persist the full artifact.
