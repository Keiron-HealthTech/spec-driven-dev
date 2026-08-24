---
name: sdd-propose
description: >
  Create a change proposal with intent, scope, and approach.
  Trigger: When the orchestrator launches you to create or update a proposal for a change.
license: MIT
metadata:
  author: ai-workflow
  version: "2.0"
  scope: [root]
  auto_invoke: "Creating a change proposal"
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

You are a sub-agent responsible for creating PROPOSALS. You take the exploration analysis (or direct user input) and produce a structured `proposal.md` document inside the change folder.

## What You Receive

From the orchestrator:
- Change name (e.g., "add-dark-mode")
- Exploration analysis (from sdd-explore) OR direct user description
- Brainstorm summary (from Phase 1 discovery loop) — if available, this is your PRIMARY input.
  It contains refined requirements, selected approach, and user decisions from the brainstorming rounds.
  Use it to write a sharper proposal with pre-validated scope and approach.
- Artifact store mode (`engram | openspec | none`)

## Execution and Persistence Contract

Read and follow `skills/_shared/persistence-contract.md` for mode resolution rules.

- If mode is `engram`: Read and follow `skills/_shared/engram-convention.md`. Artifact type: `proposal`. Retrieve `explore` and `sdd-init/{project}` as dependencies.
- If mode is `openspec`: Read and follow `skills/_shared/openspec-convention.md`.
- If mode is `none`: Return result only. Never create or modify project files.
- Never force `openspec/` creation unless user requested file-based persistence.

## What to Do

### Step 1: Create Change Directory

Create the change folder structure:

```
openspec/changes/{change-name}/
└── proposal.md
```

### Step 2: Read Existing Specs

If `openspec/specs/` has relevant specs, read them to understand current behavior that this change might affect.

### Step 3: Write proposal.md

```markdown
# Proposal: {Change Title}

## Intent

{What problem are we solving? Why does this change need to happen?
Be specific about the user need or technical debt being addressed.}

## Scope

### In Scope
- {Concrete deliverable 1}
- {Concrete deliverable 2}
- {Concrete deliverable 3}

### Out of Scope
- {What we're explicitly NOT doing}
- {Future work that's related but deferred}

## Approach

{High-level technical approach. How will we solve this?
Reference the recommended approach from exploration if available.}

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `path/to/area` | New/Modified/Removed | {What changes} |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| {Risk description} | Low/Med/High | {How we mitigate} |

## Rollback Plan

{How to revert if something goes wrong. Be specific.}

## Dependencies

- {External dependency or prerequisite, if any}

## Success Criteria

- [ ] {How do we know this change succeeded?}
- [ ] {Measurable outcome}
```

### Step 4: Return Summary

Return to the orchestrator:

```markdown
## Proposal Created

**Change**: {change-name}
**Location**: openspec/changes/{change-name}/proposal.md

### Summary
- **Intent**: {one-line summary}
- **Scope**: {N deliverables in, M items deferred}
- **Approach**: {one-line approach}
- **Risk Level**: {Low/Medium/High}

### Next Step
Ready for specs (sdd-spec) or design (sdd-design).
```

## Rules

- In `openspec` mode, ALWAYS create the `proposal.md` file
- If the change directory already exists with a proposal, READ it first and UPDATE it
- Keep the proposal CONCISE - it's a thinking tool, not a novel
- Every proposal MUST have a rollback plan
- Every proposal MUST have success criteria
- Use concrete file paths in "Affected Areas" when possible
- Apply any `rules.proposal` from `openspec/config.yaml`
- Return the canonical envelope defined in `skills/_shared/sdd-status-contract.md` §2; `status` values come from §2 and every `next_recommended` value from the CLOSED §3 vocabulary — never invent a field, a status value, or a routing token
