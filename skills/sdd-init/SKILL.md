---
name: sdd-init
description: >
  Initialize Spec-Driven Development context in any project. Detects stack, conventions, and bootstraps the active persistence backend.
  Trigger: When user wants to initialize SDD in a project, or says "sdd init", "iniciar sdd", "openspec init".
license: MIT
metadata:
  author: ai-workflow
  version: "2.0"
  scope: [root]
  auto_invoke: "Initializing SDD in a project"
---

> **ORCHESTRATOR GATE** — If you loaded this file with the Skill tool, you are the
> ORCHESTRATOR: STOP. Do NOT execute these instructions inline. Launch a sub-agent with
> `Task(subagent_type: 'spec-driven-dev:sdd-init')`, passing NO model argument, per the
> Sub-Agent Launching Pattern in `skills/sdd-orchestrator/SKILL.md`, with the absolute
> path to `skills/_shared/sdd-status-contract.md` in the prompt. This file is for EXECUTORS.

## Executor Override

If you ARE the sub-agent launched for this phase — your prompt told you to read this skill
file and follow it — the gate above does NOT apply to you. Do not delegate, do not call the
Skill tool, do not read the gate as an instruction to stop. You are the executor: execute
the phase work below and return the §2 envelope.

## Purpose

You are a sub-agent responsible for initializing the Spec-Driven Development (SDD) context in a project. You detect the project stack and conventions, then bootstrap the active persistence backend.

## Execution and Persistence Contract

Read and follow `skills/_shared/persistence-contract.md` for mode resolution rules.

- If mode is `engram`: Read and follow `skills/_shared/engram-convention.md`. Do not create `openspec/`.
- If mode is `openspec`: Read and follow `skills/_shared/openspec-convention.md`. Run full bootstrap.
- If mode is `none`: Return detected context without writing project files; any domain pointer snippet is returned, never applied (Step 1b).

## What to Do

### Step 1: Detect Project Context

Read the project to understand:
- Tech stack (check package.json, go.mod, pyproject.toml, etc.)
- Existing conventions (linters, test frameworks, CI)
- Architecture patterns in use

### Step 1b: Detect Domain Layout

Apply `skills/_shared/domain-contract.md` §1 to detect the layout; this step reads only and writes nothing.

1. Glob the root for `GLOSSARY-MAP.md`, `GLOSSARY.md` and `docs/adr/[0-9][0-9][0-9][0-9]-*.md`.
2. Look for monorepo signals: `pnpm-workspace.yaml`, `turbo.json`, `nx.json`, `lerna.json`, `go.work`, `"workspaces"` in `package.json`, `[workspace]` in `Cargo.toml`.
3. Set the layout by that contract's §1: `map`, `single` or `absent`. In the map layout, read `GLOSSARY-MAP.md` for each context's glossary path, and Glob each `{context}/docs/adr/`.
4. Look for `CLAUDE.md`, then `AGENTS.md`, at the root. A file that already mentions `GLOSSARY.md` has the pointer: return no snippet. Exactly one found without it: return the instruction-file snippet of that contract's §3 with that file as its target; the orchestrator applies it, you never do. Both found: return the snippet and say the orchestrator must ask the user which file. Neither found: return no snippet.
5. If `CONTEXT.md` or `CONTEXT-MAP.md` exists and no glossary file does, add one line to the summary: legacy name found, renamed upstream to `GLOSSARY.md`, adopt it with `git mv`.
6. Create no domain file and edit no instruction file.

### Step 2: Initialize Persistence Backend

If mode resolves to `openspec`, create this directory structure:

```
openspec/
├── config.yaml              ← Project-specific SDD config
├── specs/                   ← Source of truth (empty initially)
└── changes/                 ← Active changes
    └── archive/             ← Completed changes
```

### Step 3: Generate Config (openspec mode)

Based on what you detected, create the config when in `openspec` mode:

```yaml
# openspec/config.yaml
schema: spec-driven

context: |
  Tech stack: {detected stack}
  Architecture: {detected patterns}
  Testing: {detected test framework}
  Style: {detected linting/formatting}
  Domain: {layout}; glossary {path | none}; ADRs {docs/adr/ | none}

rules:
  proposal:
    - Include rollback plan for risky changes
    - Identify affected modules/packages
  specs:
    - Use Given/When/Then format for scenarios
    - Use RFC 2119 keywords (MUST, SHALL, SHOULD, MAY)
  design:
    - Include sequence diagrams for complex flows
    - Document architecture decisions with rationale
  tasks:
    - Group tasks by phase (infrastructure, implementation, testing)
    - Use hierarchical numbering (1.1, 1.2, etc.)
    - Keep tasks small enough to complete in one session
  apply:
    - Follow existing code patterns and conventions
    - Load relevant coding skills for the project stack
  verify:
    - Run tests if test infrastructure exists
    - Compare implementation against every spec scenario
  archive:
    - Warn before merging destructive deltas (large removals)
```

### Step 4: Return Summary

Return a structured summary adapted to the resolved mode:

#### If mode is `engram`:

Persist project context following `skills/_shared/engram-convention.md` with title and topic_key `sdd-init/{project-name}`, including the domain layout block below.

Return:
```
## SDD Initialized

**Project**: {project name}
**Stack**: {detected stack}
**Persistence**: engram

### Context Saved
Project context persisted to Engram.
- **Engram ID**: #{observation-id}
- **Topic key**: sdd-init/{project-name}

### Domain
Domain layout: {map | single | absent}
Glossaries: {paths | none}
ADRs: {each ADR directory with its count | none}
Monorepo signals: {list | none}
Instruction file: {CLAUDE.md | AGENTS.md | both | none}; pointer: {present | snippet returned | n/a}
Snippet: {the snippet line and its target | none}

No project files created; any domain pointer snippet is returned for the orchestrator to apply (Step 1b).

### Next Steps
Ready for /sdd-explore <topic> or /sdd-new <change-name>.
```

#### If mode is `openspec`:
```
## SDD Initialized

**Project**: {project name}
**Stack**: {detected stack}
**Persistence**: openspec

### Structure Created
- openspec/config.yaml ← Project config with detected context
- openspec/specs/      ← Ready for specifications
- openspec/changes/    ← Ready for change proposals

### Next Steps
Ready for /sdd-explore <topic> or /sdd-new <change-name>.
```

#### If mode is `none`:
```
## SDD Initialized

**Project**: {project name}
**Stack**: {detected stack}
**Persistence**: none (ephemeral)

### Context Detected
{summary of detected stack and conventions}

### Domain
Domain layout: {map | single | absent}
Glossaries: {paths | none}
ADRs: {each ADR directory with its count | none}
Monorepo signals: {list | none}
Instruction file: {CLAUDE.md | AGENTS.md | both | none}; pointer: {present | snippet returned | n/a}
Snippet: {the snippet line and its target | none}

### Recommendation
Enable `engram` or `openspec` for artifact persistence across sessions. Without persistence, all SDD artifacts will be lost when the conversation ends.

### Next Steps
Ready for /sdd-explore <topic> or /sdd-new <change-name>.
```

## Rules

- NEVER create placeholder spec files - specs are created via sdd-spec during a change
- NEVER create GLOSSARY.md, GLOSSARY-MAP.md or docs/adr/ — the glossary is born when the first term is resolved, and the orchestrator writes it (`skills/_shared/domain-contract.md` §1)
- NEVER create the missing instruction file; return the snippet only for an existing CLAUDE.md or AGENTS.md
- When both CLAUDE.md and AGENTS.md exist, say the orchestrator must ask the user which to update
- ALWAYS detect the real tech stack, don't guess
- If the project already has an `openspec/` directory, report what exists and ask the orchestrator if it should be updated
- Keep config.yaml context CONCISE - no more than 10 lines
- Return the canonical envelope defined in `skills/_shared/sdd-status-contract.md` §2; `status` values come from §2 and every `next_recommended` value from the CLOSED §3 vocabulary — never invent a field, a status value, or a routing token
