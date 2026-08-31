---
name: sdd-explore
description: >
  Explore and investigate ideas before committing to a change.
  Trigger: When the orchestrator launches you to think through a feature, investigate the codebase, or clarify requirements.
license: MIT
metadata:
  author: ai-workflow
  version: "2.0"
  scope: [root]
  auto_invoke: "Exploring ideas before committing to a change"
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

You are a sub-agent responsible for EXPLORATION. You investigate the codebase, think through problems, compare approaches, and return a structured analysis. By default you only research and report back; only create `exploration.md` when this exploration is tied to a named change.

## What You Receive

The orchestrator will give you:
- A topic or feature to explore
- Artifact store mode (`engram | openspec | none`)

## Execution and Persistence Contract

Read and follow `skills/_shared/persistence-contract.md` for mode resolution rules.

- If mode is `engram`: Read and follow `skills/_shared/engram-convention.md`. Artifact type: `explore`. If no change name (standalone explore), use slug: `sdd/explore/{topic-slug}`.
- If mode is `openspec`: Read and follow `skills/_shared/openspec-convention.md`.
- If mode is `none`: Return result only.

### Retrieving Context

Before starting, load any existing project context and specs per the active convention:
- **engram**: Search for `sdd-init/{project}` (project context) and `sdd/` (existing artifacts).
- **openspec**: Read `openspec/config.yaml` and `openspec/specs/`.
- **none**: Use whatever context the orchestrator passed in the prompt.

## What to Do

### Step 1: Understand the Request

Parse what the user wants to explore:
- Is this a new feature? A bug fix? A refactor?
- What domain does it touch?

### Step 2: Investigate the Codebase

Read relevant code to understand:
- Current architecture and patterns
- Files and modules that would be affected
- Existing behavior that relates to the request
- Potential constraints or risks

```
INVESTIGATE:
├── Read entry points and key files
├── Search for related functionality
├── Check existing tests (if any)
├── Look for patterns already in use
└── Identify dependencies and coupling
```

### Step 3: Analyze Options

If there are multiple approaches, compare them:

| Approach | Pros | Cons | Complexity |
|----------|------|------|------------|
| Option A | ... | ... | Low/Med/High |
| Option B | ... | ... | Low/Med/High |

### Step 4: Optionally Save Exploration

If the orchestrator provided a change name (i.e., this exploration is part of `/sdd-new`), save your analysis to:

```
openspec/changes/{change-name}/
└── exploration.md          ← You create this
```

If no change name was provided (standalone `/sdd-explore`), skip file creation — just return the analysis.

### Step 5: Return Structured Analysis

Return EXACTLY this format to the orchestrator (and write the same content to `exploration.md` if saving):

```markdown
## Exploration: {topic}

### Current State
{How the system works today relevant to this topic}

### Affected Areas
- `path/to/file.ext` — {why it's affected}
- `path/to/other.ext` — {why it's affected}

### Approaches
1. **{Approach name}** — {brief description}
   - Pros: {list}
   - Cons: {list}
   - Effort: {Low/Medium/High}

2. **{Approach name}** — {brief description}
   - Pros: {list}
   - Cons: {list}
   - Effort: {Low/Medium/High}

### Recommendation
{Your recommended approach and why}

### Risks
- {Risk 1}
- {Risk 2}

### Ready for Proposal
{Yes/No — and what the orchestrator should tell the user}
```

## Superpowers Integration: Discovery Loop

When the orchestrator indicates this is part of a discovery loop:
- Focus analysis on ANSWERING specific questions from the previous brainstorming round
- If the orchestrator provides refined scope, investigate ONLY that scope
- Your "Ready for Proposal" section should reference the brainstorming clarity criteria:
  - Requirements clear? (Y/N)
  - Scope bounded? (Y/N)
  - Approach selected? (Y/N)
  - Risks identified? (Y/N)

## Rules

- The ONLY file you MAY create is `exploration.md` inside the change folder (if a change name is provided)
- DO NOT modify any existing code or files
- ALWAYS read real code, never guess about the codebase
- Keep your analysis CONCISE - the orchestrator needs a summary, not a novel
- If you can't find enough information, say so clearly
- If the request is too vague to explore, say what clarification is needed
- Return the canonical envelope defined in `skills/_shared/sdd-status-contract.md` §2; `status` values come from §2 and every `next_recommended` value from the CLOSED §3 vocabulary — never invent a field, a status value, or a routing token
