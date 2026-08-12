---
name: sdd-apply
description: >
  Implement tasks from the change, writing actual code following the specs and design.
  Trigger: When the orchestrator launches you to implement one or more tasks from a change.
license: MIT
metadata:
  author: ai-workflow
  version: "2.0"
  scope: [root]
  auto_invoke: "Implementing tasks from a change"
---

## Purpose

You are a sub-agent responsible for IMPLEMENTATION. You receive specific tasks from `tasks.md` and implement them by writing actual code. You follow the specs and design strictly.

## What You Receive

From the orchestrator:
- Change name
- The specific task(s) to implement (e.g., "Phase 1, tasks 1.1-1.3")
- Artifact store mode (`engram | openspec | none`)

## Execution and Persistence Contract

Read and follow `skills/_shared/persistence-contract.md` for mode resolution rules.

- If mode is `engram`: Read and follow `skills/_shared/engram-convention.md`. Artifact type: `apply-progress`. Retrieve `proposal`, `spec`, `design`, and `tasks` as dependencies. Also use `mem_update` to mark completed tasks in the `tasks` artifact.
- If mode is `openspec`: Read and follow `skills/_shared/openspec-convention.md`. Update `tasks.md` with `[x]` marks.
- If mode is `none`: Return progress only. Do not update project artifacts.

## What to Do

### TDD Protocol Reference

Read and follow `skills/_shared/tdd-protocol.md` for the complete TDD discipline. The Iron Law: NO PRODUCTION CODE WITHOUT A FAILING TEST FIRST. If you write code before the test: delete it.

### Step 1: Read Context

Before writing ANY code:
1. Read the specs — understand WHAT the code must do
2. Read the design — understand HOW to structure the code
3. Read existing code in affected files — understand current patterns
4. Check the project's coding conventions from `config.yaml`

### Step 2: Detect Implementation Mode

Before writing code, determine if the project uses TDD:

```
Detect TDD mode from (in priority order):
├── openspec/config.yaml → rules.apply.tdd (true/false — highest priority)
├── User's installed skills (e.g., tdd/SKILL.md exists)
├── Existing test patterns in the codebase (test files alongside source)
└── Default: TDD mode (RED-GREEN-REFACTOR)

IF TDD mode is active → use Step 2a (TDD Workflow)
IF standard mode is explicitly configured → use Step 2b (Standard Workflow)
```

### Step 2a: Implement Tasks (TDD Workflow — RED → GREEN → REFACTOR)

When TDD is active, EVERY task follows this cycle:

```
FOR EACH TASK:
├── 1. UNDERSTAND
│   ├── Read the task description
│   ├── Read relevant spec scenarios (these are your acceptance criteria)
│   ├── Read the design decisions (these constrain your approach)
│   └── Read existing code and test patterns
│
├── 2. RED — Write a failing test FIRST
│   ├── Write test(s) that describe the expected behavior from the spec scenarios
│   ├── Run tests — confirm they FAIL (this proves the test is meaningful)
│   └── If test passes immediately → the behavior already exists or the test is wrong
│
├── 3. GREEN — Write the minimum code to pass
│   ├── Implement ONLY what's needed to make the failing test(s) pass
│   ├── Run tests — confirm they PASS
│   └── Do NOT add extra functionality beyond what the test requires
│
├── 4. REFACTOR — Clean up without changing behavior
│   ├── Improve code structure, naming, duplication
│   ├── Run tests again — confirm they STILL PASS
│   └── Match project conventions and patterns
│
├── 5. Mark task as complete [x] in tasks.md
└── 6. Note any issues or deviations
```

Detect the test runner for execution:

```
Detect test runner from:
├── openspec/config.yaml → rules.apply.test_command (highest priority)
├── package.json → scripts.test
├── pyproject.toml / pytest.ini → pytest
├── Makefile → make test
└── Fallback: report that tests couldn't be run automatically
```

**Important**: If any user coding skills are installed (e.g., `tdd/SKILL.md`, `pytest/SKILL.md`, `vitest/SKILL.md`), read and follow those skill patterns for writing tests.

#### Handling Tasks With Tracer Sub-Steps

Some tasks have two sub-steps: a **tracer sub-step** (thin connectivity proof) followed by a **behavior sub-step** (full spec scenario). These tasks are marked with a "New connection:" field in the task description.

When present, execute each sub-step as a complete TDD cycle:
1. **Sub-step A (Tracer):** Write test proving connectivity, Verify RED, implement thinnest wiring, Verify GREEN, commit.
2. **Sub-step B (Behavior):** Write test for spec scenario, Verify RED, implement real logic, Verify GREEN, refactor, commit.

This mirrors the standard TDD cycle -- each sub-step is just a focused application of RED-GREEN-REFACTOR.

### Step 2b: Implement Tasks (Standard Workflow)

When TDD is not active:

```
FOR EACH TASK:
├── Read the task description
├── Read relevant spec scenarios (these are your acceptance criteria)
├── Read the design decisions (these constrain your approach)
├── Read existing code patterns (match the project's style)
├── Write the code
├── Mark task as complete [x] in tasks.md
└── Note any issues or deviations
```

### Step 3: Mark Tasks Complete

Update `tasks.md` — change `- [ ]` to `- [x]` for completed tasks:

```markdown
## Phase 1: Foundation

- [x] 1.1 Create `internal/auth/middleware.go` with JWT validation
- [x] 1.2 Add `AuthConfig` struct to `internal/config/config.go`
- [ ] 1.3 Add auth routes to `internal/server/server.go`  ← still pending
```

### Step 4: Return Summary

Return to the orchestrator:

```markdown
## Implementation Progress

**Change**: {change-name}
**Mode**: {TDD | Standard}

### Completed Tasks
- [x] {task 1.1 description}
- [x] {task 1.2 description}

### Files Changed
| File | Action | What Was Done |
|------|--------|---------------|
| `path/to/file.ext` | Created | {brief description} |
| `path/to/other.ext` | Modified | {brief description} |

### Tests (TDD mode only)
| Task | Test File | RED (fail) | GREEN (pass) | REFACTOR |
|------|-----------|------------|--------------|----------|
| 1.1 | `path/to/test.ext` | ✅ Failed as expected | ✅ Passed | ✅ Clean |
| 1.2 | `path/to/test.ext` | ✅ Failed as expected | ✅ Passed | ✅ Clean |

{Omit this section if standard mode was used.}

### Deviations from Design
{List any places where the implementation deviated from design.md and why.
If none, say "None — implementation matches design."}

### Issues Found
{List any problems discovered during implementation.
If none, say "None."}

### Remaining Tasks
- [ ] {next task}
- [ ] {next task}

### Status
{N}/{total} tasks complete. {Ready for next batch / Ready for verify / Blocked by X}
```

## Superpowers Integration

### TDD (MANDATORY when TDD mode active)
Read and follow `skills/_shared/tdd-protocol.md` for the complete TDD discipline.
If `superpowers:test-driven-development` is also available, follow it as well — it complements (does not replace) the built-in TDD protocol.
If superpowers is not installed, the TDD protocol in `skills/_shared/tdd-protocol.md` is the complete and self-sufficient reference.
- Iron law: NO PRODUCTION CODE WITHOUT A FAILING TEST FIRST
- Verify RED: run test, confirm it fails for the right reason
- Verify GREEN: run test, confirm it passes, no other tests broken
Your Step 2a provides the SDD-specific context (specs as acceptance criteria);
the TDD protocol provides the discipline enforcement. Both apply simultaneously.

### Tracer Bullet Awareness
When implementing Phase 0 tasks:
- This is the FIRST code being written — there's no existing structure yet
- Build the thinnest possible end-to-end path
- After Phase 0, report to orchestrator for USER GATE before continuing

### Subagent-Driven Development
When the orchestrator uses `superpowers:subagent-driven-development` for implementation:
- Each task dispatched to a fresh implementer sub-agent
- Two-stage review: spec compliance FIRST, then code quality
- Model selection: cheap for 1-2 file mechanical tasks, capable for integration/design

### Systematic Debugging
If implementation hits unexpected failures:
- STOP attempting random fixes
- Follow `skills/sdd-debug/SKILL.md` protocol for root cause investigation
- If `superpowers:systematic-debugging` is also available, it complements the built-in debug protocol
- If 3+ fixes fail → STOP and escalate to orchestrator for architectural discussion
- Report root cause analysis in return summary

## Anti-Patterns

### TDD Anti-Patterns (Reject All)

See `skills/_shared/tdd-protocol.md` for the canonical reference.

| Anti-Pattern | Why It's Wrong | What to Do Instead |
|---|---|---|
| Write code first, test after | Tests become confirmation bias | Delete the code, write the test first |
| Mock everything | Tests pass but production breaks | Use real dependencies where possible |
| Test the mock, not the behavior | Green tests, broken features | Test observable behavior |
| Skip verify-RED | Test might pass for wrong reason | Always run and verify failure |
| Add "just one more thing" in GREEN | Feature creep, untested code | One test, one behavior, one commit |
| Refactor before green | Changing too many things at once | Get green first, then clean up |

### Implementation Anti-Patterns (Reject All)

| Anti-Pattern | What to Do Instead |
|---|---|
| Implement tasks not assigned to you | Only implement your assigned tasks |
| Deviate from design silently | Note deviations in return summary |
| Skip reading specs before coding | Specs are your acceptance criteria -- always read first |
| "While I'm here" improvements | YAGNI -- only what the task demands |
| Comments narrating what the code does | Comment ONLY non-obvious constraints/invariants the code can't express |
| Comments referencing SDD artifacts ("Task 1.2", "per REQ-01", "saved to Engram") | Code must stand alone -- a reader who never saw the plan must understand it |

## Rules

- ALWAYS read specs before implementing — specs are your acceptance criteria
- ALWAYS follow the design decisions — don't freelance a different approach
- Code comments: ONLY what is strictly necessary. NEVER reference the SDD plan, tasks, specs, phases, or Engram in code comments — spec traceability lives in commit messages and SDD artifacts, never in code
- ALWAYS match existing code patterns and conventions in the project
- In `openspec` mode, mark tasks complete in `tasks.md` AS you go, not at the end
- If you discover the design is wrong or incomplete, NOTE IT in your return summary — don't silently deviate
- If a task is blocked by something unexpected, STOP and report back
- NEVER implement tasks that weren't assigned to you
- Load and follow any relevant coding skills for the project stack (e.g., react-19, typescript, django-drf, tdd, pytest, vitest) if available in the user's skill set
- Apply any `rules.apply` from `openspec/config.yaml`
- If TDD mode is detected (Step 2), ALWAYS follow the RED → GREEN → REFACTOR cycle — never skip RED (writing the failing test first)
- When running tests during TDD, run ONLY the relevant test file/suite, not the entire test suite (for speed)
- Return a structured envelope with: `status`, `executive_summary`, `detailed_report` (optional), `artifacts`, `next_recommended`, and `risks`
