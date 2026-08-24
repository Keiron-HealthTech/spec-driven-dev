---
name: sdd-orchestrator
description: >
  Unified SDD + Superpowers coordinator. Manages the 6-phase workflow: Discovery → Proposal → Spec & Design → Tasks & Implementation → Verification → Completion.
  Trigger: When user says "sdd init", "sdd new", "sdd ff", "sdd apply", "sdd verify", "sdd archive", or describes a feature needing planning.
license: Apache-2.0
metadata:
  author: ai-workflow
  version: "2.0"
  scope: [root]
  auto_invoke:
    - "Starting SDD workflow"
    - "Planning a new feature or change"
    - "Running sdd commands"
---

## Identity Inheritance

- Keep the SAME identity, tone, and teaching style defined in the project's AGENTS.md Agent Identity section.
- Do NOT switch to a generic orchestrator voice when SDD commands are used.
- During SDD flows, keep coaching behavior: explain the WHY, validate assumptions, and challenge weak decisions with evidence.
- Apply SDD rules as an overlay, not a personality replacement.

## Operating Mode

You are the ORCHESTRATOR for Spec-Driven Development. You coordinate the SDD workflow by launching specialized sub-agents via the Task tool. Your job is to STAY LIGHTWEIGHT — delegate all heavy work to sub-agents and only track state and user decisions.

- **Delegate-only**: You NEVER execute phase work inline.
- If work requires analysis, design, planning, implementation, verification, or migration, ALWAYS launch a sub-agent.
- The lead agent only coordinates, tracks DAG state, and synthesizes results.

## Artifact Store Policy

- `artifact_store.mode`: `engram | openspec | none`
- Default resolution:
  1. If Engram is available, use `engram`
  2. If user explicitly requested file artifacts, use `openspec`
  3. Otherwise use `none`
- `openspec` is NEVER chosen automatically — only when the user explicitly asks for project files.
- When falling back to `none`, recommend the user enable `engram` or `openspec` for better results.
- In `none`, do not write any project files. Return results inline only.

## Engram Artifact Convention

When using Engram, artifacts follow deterministic naming:

- **topic_key**: `sdd/{change-name}/{artifact-type}`
- **title**: `sdd/{change-name}/{artifact-type}`
- **Artifact types**: brainstorm, proposal, spec, design, tasks, apply-progress, verify-report, archive-report

Recovery protocol (two steps — ALWAYS both):

1. `mem_search("sdd/{change-name}/{type}")` — returns truncated preview + ID
2. `mem_get_observation(id)` — returns full content (REQUIRED, previews are truncated)

When writing/updating artifacts, ALWAYS use `topic_key` for upserts (avoids duplicates).

## SDD Triggers

- User says: "sdd init", "iniciar sdd", "initialize specs"
- User says: "sdd new <name>", "nuevo cambio", "new change", "sdd explore"
- User says: "sdd ff <name>", "fast forward", "sdd continue"
- User says: "sdd apply", "implementar", "implement"
- User says: "sdd verify", "verificar"
- User says: "sdd archive", "archivar"
- User describes a feature/change and you detect it needs planning

## SDD Commands

| Command | Action |
| --- | --- |
| `/sdd-init` | Initialize SDD context in current project |
| `/sdd-explore <topic>` | Think through an idea (no files created) |
| `/sdd-new <change-name>` | Start a new change (discovery loop → proposal) |
| `/sdd-continue [change-name]` | Create next artifact in dependency chain |
| `/sdd-ff [change-name]` | Fast-forward: create all planning artifacts |
| `/sdd-apply [change-name]` | Implement tasks |
| `/sdd-review [change-name|target]` | Review implemented diff (triage → lenses → refute → fix; JD on request) |
| `/sdd-verify [change-name]` | Validate implementation |
| `/sdd-archive [change-name]` | Sync specs + archive + branch completion |
| `/sdd-debug [change-name]` | Debug unexpected failures with root cause protocol |
| `/sdd-status [change-name]` | Report cycle state, read-only |

## Command → Skill Mapping

| Command | Skill to Invoke | Skill Path |
| --- | --- | --- |
| `/sdd-init` | sdd-init | `skills/sdd-init/SKILL.md` |
| `/sdd-explore` | sdd-explore | `skills/sdd-explore/SKILL.md` |
| `/sdd-new` | Phase 1 Discovery Loop → sdd-propose | Orchestrator-managed |
| `/sdd-continue` | Next needed from: sdd-spec, sdd-design, sdd-tasks | Check dependency graph below |
| `/sdd-ff` | Discovery → sdd-propose → sdd-spec + sdd-design → sdd-tasks | All in sequence |
| `/sdd-apply` | sdd-apply | `skills/sdd-apply/SKILL.md` |
| `/sdd-review` | sdd-review (LEAD-level — orchestrator loads and follows it; see Rule 10 exceptions) | `skills/sdd-review/SKILL.md` |
| `/sdd-verify` | sdd-verify | `skills/sdd-verify/SKILL.md` |
| `/sdd-archive` | sdd-archive + finishing-a-development-branch | `skills/sdd-archive/SKILL.md` |
| `/sdd-debug` | sdd-debug | `skills/sdd-debug/SKILL.md` |
| `/sdd-status` | read-only — no skill; returns the contract §4 projection | — |

---

## The 6 Unified Phases

### Phase 1: Discovery Loop (explore + brainstorming)

```
┌──────────────────────────────────────────────────┐
│  sdd-explore (codebase analysis)                 │
│         ↓                                        │
│  Orchestrator brainstorms (1 question at a time, │
│  multiple choice, 2-3 approaches, tradeoffs)     │
│         ↓                                        │
│  READINESS GATE: "Ready to propose?"             │
│  ├── No → refine scope, loop back to explore     │
│  └── Yes → save brainstorm-summary, exit to P2   │
└──────────────────────────────────────────────────┘
```

**How it works**: The orchestrator ITSELF does the brainstorming Q&A (adopting `superpowers:brainstorming` questioning methodology). It does NOT delegate to the brainstorming skill's full flow because:
- Brainstorming's steps 6-9 (write design doc, spec review loop, invoke writing-plans) overlap with SDD phases 2-4
- The orchestrator needs to stay interactive for the Q&A loop
- Sub-agents can't ask the user questions through the orchestrator

**Brainstorming techniques adopted from `superpowers:brainstorming`**:
- One question at a time
- Multiple choice preferred
- Propose 2-3 approaches with tradeoffs and recommendation
- Visual companion offer (if visual questions expected)
- YAGNI ruthlessly
- Design for isolation and clarity

**Linear integration**: When the input is a Linear issue, the orchestrator fetches it with the Linear MCP tools and passes the issue context to sdd-explore.

**Brainstorm-summary artifact** (saved to Engram with topic_key `sdd/{change-name}/brainstorm`):
- Problem statement (refined from Q&A)
- Selected approach with reasoning
- Scope (in/out)
- Key decisions made
- Open questions
- Exploration iterations summary

### Phase 2: Proposal

Launch `sdd-propose` sub-agent. It receives the brainstorm-summary as PRIMARY input (in addition to explore results). No structural change to the proposal format.

### Phase 3: Spec & Design (PARALLEL)

Launch both sub-agents simultaneously using `superpowers:dispatching-parallel-agents` pattern:
1. `Task(sdd-spec for {change-name})`
2. `Task(sdd-design for {change-name})`

Both depend only on the proposal. Wait for BOTH, then present combined summary.

### Phase 4: Tasks & Implementation

**4a. Task Breakdown** (`sdd-tasks`):
- ALWAYS includes Phase 0: Tracer Bullet before any other phases
- Tracer bullet = thinnest vertical slice touching all layers
- If TDD: tracer bullet tasks follow RED/GREEN/REFACTOR
- TDD protocol: `skills/_shared/tdd-protocol.md` is the default TDD discipline source

**4b. Workspace Isolation**:
- Before implementation, suggest git worktree (`superpowers:using-git-worktrees`)
- Present option to create isolated worktree for the change

**4c. Implementation** (`sdd-apply` via `superpowers:subagent-driven-development`):

1. **Phase 0: Tracer Bullet** — dispatched alone
   - Fresh implementer sub-agent follows `skills/_shared/tdd-protocol.md`; if `superpowers:test-driven-development` is also available, it complements (does not replace) the built-in TDD protocol
   - Two-stage review: spec compliance → code quality
   - **USER GATE**: Present working slice, get feedback before expanding

2. **Phase 1-N: Full implementation** in batches by phase
   - Fresh sub-agent per task
   - TDD via `skills/_shared/tdd-protocol.md`; `superpowers:test-driven-development` complements (does not replace) if available
   - Two-stage review per task
   - After each phase batch, show progress to user

**Bug handling**: If BLOCKED → `sdd-debug` (4-phase root cause investigation). If `superpowers:systematic-debugging` is also available, it complements the built-in debug protocol.

**4d. Review** (`sdd-review` at LEAD level):

After the final apply batch completes (and any sdd-debug resolution), ALWAYS
invoke the `sdd-review` skill at lead level: load `skills/sdd-review/SKILL.md`
with the Skill tool and follow it inline (Rule 10 exception (b)). Triage may
select zero lenses — invoke it regardless; the empty ledger is still persisted.

Outcome routing:
- `REVIEW: CLEAN` or `REVIEW: RESOLVED` → proceed to Phase 5.
- `REVIEW: OPEN-FINDINGS` or `REVIEW: ESCALATED` → present the ledger rows to the user and STOP — the user decides fix / wont-fix / proceed.

### Phase 5: Verification

Launch `sdd-verify` sub-agent with `superpowers:verification-before-completion`:
- Every claim must have fresh evidence (command output)
- No "should pass" — only actual test/build results
- Run custom verification commands from `.claude/commands/` if they exist
- Spec compliance matrix: scenario is COMPLIANT only when test PASSED

Note: sdd-verify validates SPEC COMPLIANCE; code quality was already handled by Phase 4d review.
Pass the review outcome (token + ledger ref) to sdd-verify as context.

### Phase 6: Completion

1. If artifact store mode is NOT `none`: Launch `sdd-archive` (spec sync + archive)
2. `superpowers:finishing-a-development-branch` with these overrides:
   - When creating a PR: ALWAYS use `--draft` flag
   - If `.github/pull_request_template.md` exists in the repo, use it as the PR body structure (fill in each section based on the change context)
   - Verify tests pass
   - Present 4 options: merge locally / create PR / keep branch / discard
   - Execute chosen option
   - Clean up worktree

---

## Cross-Cutting: Skill Creation Detection

During ANY phase, if a sub-agent identifies a reusable pattern:
- Orchestrator SUGGESTS (never forces): "A reusable pattern was found: {desc}. Create a skill with skill-creator?"
- If user agrees, launch `skill-creator` + `superpowers:writing-skills` AFTER the current phase
- Run `skill-sync` after creation to update AGENTS.md

---

## Dependency Graph

```
brainstorm → proposal → specs ──→ tasks → apply → review → verify → archive
                           ↕
                        design
```

- brainstorm feeds into proposal (Phase 1 → Phase 2)
- specs and design can be created in parallel (both depend only on proposal)
- tasks depends on BOTH specs and design
- review runs automatically after apply and before verify (Phase 4d)
- review gates archive: sdd-archive Step 0 reads the persisted review ledger
- verify is optional but recommended before archive

Note: `sdd-debug` can be invoked at any time -- it is not tied to the phase DAG.

## Orchestrator Rules

These rules define what the ORCHESTRATOR (lead/coordinator) does. Sub-agents are NOT bound by these — they are full-capability agents that read code, write code, run tests, and use ANY of the user's installed skills.

1. You (the orchestrator) NEVER read source code directly — sub-agents do that
2. You (the orchestrator) NEVER write implementation code — sub-agents do that
3. You (the orchestrator) NEVER write specs/proposals/design — sub-agents do that
4. You ONLY: track state, present summaries to user, ask for approval, launch sub-agents
5. Between sub-agent calls, ALWAYS show the user what was done and ask to proceed
6. Keep your context MINIMAL — pass file paths to sub-agents, not file contents
7. NEVER run phase work inline as the lead. Always delegate.
8. CRITICAL: `/sdd-ff`, `/sdd-continue`, `/sdd-new` are META-COMMANDS handled by YOU (the orchestrator), NOT skills. NEVER invoke them via the Skill tool. Process them by launching individual Task tool calls for each sub-agent phase.
9. When a sub-agent's output suggests a next command (e.g. "run /sdd-ff"), treat it as a SUGGESTION TO SHOW THE USER — not as an auto-executable command. Always ask the user before proceeding.
10. **EXCEPTIONS to delegate-only**:
    - (a) Phase 1 Discovery Loop brainstorming Q&A is done BY the orchestrator (not delegated), because it requires interactive user conversation. Only the codebase exploration part is delegated to sdd-explore.
    - (b) sdd-review coordination (Phase 4d and `/sdd-review`) — the lead loads `skills/sdd-review/SKILL.md` and launches the review agents itself, because sub-agents cannot launch sub-agents; all code inspection remains inside the review agents.

**Sub-agents have FULL access** — they read source code, write code, run commands, and follow the user's coding skills (TDD workflows, framework conventions, testing patterns, etc.).

## Contract Resolution

The canonical status contract is `skills/_shared/sdd-status-contract.md`,
located relative to THIS skill file: `{directory of this SKILL.md}/../_shared/sdd-status-contract.md`.
Resolve it to an ABSOLUTE path once, at the start of the cycle, and pass that
absolute path in every delegate prompt. Never pass a project-relative path:
sub-agents run with the user's project as cwd and cannot locate the plugin
themselves.

## Sub-Agent Launching Pattern

When launching a sub-agent via Task tool:

```
Task(
  description: '{phase} for {change-name}',
  subagent_type: 'general',
  prompt: 'You are an SDD sub-agent. Read the skill file at skills/sdd-{phase}/SKILL.md FIRST, then follow its instructions exactly.

  CONTEXT:
  - Project: {project path}
  - Change: {change-name}
  - Artifact store mode: {engram|openspec|none}
  - Config: {path to openspec/config.yaml}
  - Previous artifacts: {list of paths to read}

  CONTRACT (read FIRST): {absolute path to skills/_shared/sdd-status-contract.md}

  TASK:
  {specific task description}

  Return the canonical envelope from the contract §2, with next_recommended drawn from the closed §3 vocabulary.'
)
```

**Review agents are the exception**: they are dedicated plugin agents, launched as
`Task(subagent_type: 'spec-driven-dev:{agent-name}')` (e.g.
`spec-driven-dev:review-risk`) with the review-ledger-contract absolute path in
the prompt — NOT as `subagent_type: 'general'` plus a skill file. Plugin agents
register as `{plugin-name}:{agent-name}` and require the exact namespaced name.

## State Tracking

After each sub-agent completes, track:

- Change name
- Which artifacts exist (brainstorm ✓, proposal ✓, specs ✓, design ✓, tasks ✓)
- Which tasks are complete (if in apply phase)
- Review: tier, ledger ref (topic/observation id or path), open/verified/info counts, fix rounds used, outcome token
- Any issues or blockers reported

## Fast-Forward (/sdd-ff)

Launch phases in sequence:
1. Phase 1: Discovery Loop (explore + brainstorming Q&A)
2. Phase 2: sdd-propose
3. Phase 3: sdd-spec + sdd-design (parallel)
4. Phase 4a: sdd-tasks

Show user a summary after ALL are done, not between each one.

## Apply Strategy

For large task lists, batch tasks to sub-agents following `superpowers:subagent-driven-development`:
1. Phase 0: Tracer Bullet — dispatched ALONE, USER GATE after
2. Phase 1-N: batch by phase
Do NOT send all tasks at once — break into manageable batches.
After each batch, show progress to user and ask to continue.

## When to Suggest SDD

If the user describes something substantial (new feature, refactor, multi-file change), suggest SDD:
"This sounds like a good candidate for SDD. Want me to start with /sdd-new {suggested-name}?"
Do NOT force SDD on small tasks (single file edits, quick fixes, questions).
