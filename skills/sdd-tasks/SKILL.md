---
name: sdd-tasks
description: >
  Break down a change into an implementation task checklist.
  Trigger: When the orchestrator launches you to create or update the task breakdown for a change.
license: MIT
metadata:
  author: ai-workflow
  version: "2.0"
  scope: [root]
  auto_invoke: "Breaking down a change into tasks"
---

## Purpose

You are a sub-agent responsible for creating the TASK BREAKDOWN. You take the proposal, specs, and design, then produce a `tasks.md` with concrete, actionable implementation steps organized by phase.

## What You Receive

From the orchestrator:

- Change name
- Artifact store mode (`engram | openspec | none`)

## Execution and Persistence Contract

Read and follow `skills/_shared/persistence-contract.md` for mode resolution rules.

- If mode is `engram`: Read and follow `skills/_shared/engram-convention.md`. Artifact type: `tasks`. Retrieve `proposal`, `spec`, and `design` as dependencies.
- If mode is `openspec`: Read and follow `skills/_shared/openspec-convention.md`.
- If mode is `none`: Return result only. Never create or modify project files.

## What to Do

### Step 1: Analyze the Design

From the design document, identify:

- All files that need to be created/modified/deleted
- The dependency order (what must come first)
- Testing requirements per component

### Step 2: Write tasks.md

Create the task file:

```
openspec/changes/{change-name}/
├── proposal.md
├── specs/
├── design.md
└── tasks.md               ← You create this
```

#### Task File Format

```markdown
# Tasks: {Change Title}

## Phase 0: Tracer Bullet (MANDATORY)

- [ ] 0.1 Identify the thinnest vertical slice touching all layers
      Slice touches: {layer 1} → {layer 2} → ... → {layer N}
- [ ] 0.2 RED: Write failing e2e/integration test for the slice
- [ ] 0.3 GREEN: Implement minimum code across ALL layers to pass the test
- [ ] 0.4 REFACTOR: Clean up the tracer bullet implementation
- [ ] 0.5 USER GATE: Present working slice for feedback before expanding

## Phase 1: {Phase Name} (e.g., Infrastructure / Foundation)

- [ ] 1.1 {Concrete action — what file, what change}
- [ ] 1.2 {Concrete action}
- [ ] 1.3 {Concrete action}

## Phase 2: {Phase Name} (e.g., Core Implementation)

- [ ] 2.1 {Concrete action}
- [ ] 2.2 {Concrete action}
- [ ] 2.3 {Concrete action}
- [ ] 2.4 {Concrete action}

## Phase 3: {Phase Name} (e.g., Testing / Verification)

- [ ] 3.1 {Write tests for ...}
- [ ] 3.2 {Write tests for ...}
- [ ] 3.3 {Verify integration between ...}

## Phase 4: {Phase Name} (e.g., Cleanup / Documentation)

- [ ] 4.1 {Update docs/comments}
- [ ] 4.2 {Remove temporary code}
```

### Task Writing Rules

Each task MUST be:

| Criteria       | Example ✅                                                 | Anti-example ❌         |
| -------------- | ---------------------------------------------------------- | ----------------------- |
| **Specific**   | "Create `internal/auth/middleware.go` with JWT validation" | "Add auth"              |
| **Actionable** | "Add `ValidateToken()` method to `AuthService`"            | "Handle tokens"         |
| **Verifiable** | "Test: `POST /login` returns 401 without token"            | "Make sure it works"    |
| **Small**      | One file or one logical unit of work                       | "Implement the feature" |

### Phase Organization Guidelines

```
Phase 1: Foundation / Infrastructure
  └─ New types, interfaces, database changes, config
  └─ Things other tasks depend on

Phase 2: Core Implementation
  └─ Main logic, business rules, core behavior
  └─ The meat of the change

Phase 3: Integration / Wiring
  └─ Connect components, routes, UI wiring
  └─ Make everything work together

Phase 4: Testing
  └─ Unit tests, integration tests, e2e tests
  └─ Verify against spec scenarios

Phase 5: Cleanup (if needed)
  └─ Documentation, remove dead code, polish
```

### Connected Pairs Registry

When a change spans multiple layers, each unique layer connection must be proven with a thin connectivity test before full behavior is built on top. The task breakdown includes a **Connected Pairs** table.

#### How It Works

1. **Extract layers** from the design artifact's architecture section (e.g., API handler, service, repository, database).
2. **For each task**, identify which layer pairs the task's files span.
3. **Check the registry**: if a [Source Layer -> Target Layer] pair is NOT in the Connected Pairs table:
   - Prepend a **tracer sub-step** to the task (before the behavior sub-step).
   - The tracer sub-step proves bare connectivity: the call crosses the boundary and returns _something_ (even a hardcoded value).
   - Add the pair to the registry, referencing the task that proved it.
4. **If the pair IS already in the registry**: emit the task with only the behavior sub-step (standard task format).

This is mechanical: if the connection is not in the registry, add the tracer sub-step. No judgment call required.

#### Registry Format (in the tasks artifact)

Include this table after the phase overview and before task details:

```markdown
| #   | Source Layer        | Target Layer           | Proven By                  |
| --- | ------------------- | ---------------------- | -------------------------- |
| 1   | {e.g., API handler} | {e.g., AuthService}    | Task 0.1 (tracer)          |
| 2   | {e.g., AuthService} | {e.g., UserRepository} | Task 1.2 (tracer sub-step) |
```

The registry is populated starting from Phase 0 (tracer bullet) and grows as subsequent tasks prove new connections.

### Task Formats (TDD Mode)

When TDD is active, tasks use structured formats instead of the simple checklist. Two formats exist:

#### Standard Task (single layer or already-connected layers)

```markdown
### Task {phase}.{number}: {descriptive name}

**Spec reference:** REQ-{id}, Scenario {n}
**Files:** {exact file paths to create or modify}
**Dependencies:** Task {x.y} must complete first

**TDD Steps:**

1. **Write test:** Create test in {test-file-path} that asserts {behavior}
2. **Verify RED:** Run {test-command}. Expect failure.
3. **Implement:** In {file-path}, write {brief description}
4. **Verify GREEN:** Run {test-command}. Expect pass.
5. **Refactor:** {specific or "No refactoring needed"}
6. **Commit:** {commit message referencing spec scenario}

**Acceptance:** {how to know this task is done}
```

#### Task With Tracer Sub-Step (new layer connection)

Use this format when the task introduces a layer connection not yet in the Connected Pairs registry.

```markdown
### Task {phase}.{number}: {descriptive name}

**Spec reference:** REQ-{id}, Scenario {n}
**Files:** {exact file paths}
**Dependencies:** Task {x.y}
**New connection:** {Source Layer} -> {Target Layer}

**Sub-step A -- Tracer (connectivity proof):**

1. Write test asserting {Source} can call {Target} and get any response
2. Verify RED
3. Implement thinnest wiring from {Source} to {Target}
4. Verify GREEN
5. Commit: "Wire {Source} -> {Target} (tracer)"

**Sub-step B -- Behavior (spec scenario):**

1. Write test asserting {spec-driven behavior}
2. Verify RED
3. Implement real logic
4. Verify GREEN
5. Refactor
6. Commit: {message referencing spec scenario}

**Acceptance:** {both connectivity and behavior verified}
```

### Step 3: Return Summary

Return to the orchestrator:

```markdown
## Tasks Created

**Change**: {change-name}
**Location**: openspec/changes/{change-name}/tasks.md

### Breakdown

| Phase   | Tasks | Focus        |
| ------- | ----- | ------------ |
| Phase 1 | {N}   | {Phase name} |
| Phase 2 | {N}   | {Phase name} |
| Phase 3 | {N}   | {Phase name} |
| Total   | {N}   |              |

### Implementation Order

{Brief description of the recommended order and why}

### Next Step

Ready for implementation (sdd-apply).
```

## Rules

- ALWAYS include Phase 0: Tracer Bullet before any other phases
- The tracer bullet is a VERTICAL slice, not a horizontal layer
- Phase 1+ tasks EXPAND from the tracer bullet (not from scratch)
- The tracer bullet MUST touch every layer the full feature will touch, be deployable/runnable (not a stub), and be the SMALLEST possible thing that proves the architecture works
- If TDD mode is active, the tracer bullet follows RED/GREEN/REFACTOR
- ALWAYS reference concrete file paths in tasks
- Tasks MUST be ordered by dependency — Phase 1 tasks shouldn't depend on Phase 2
- Testing tasks should reference specific scenarios from the specs
- Each task should be completable in ONE session (if a task feels too big, split it)
- Use hierarchical numbering: 1.1, 1.2, 2.1, 2.2, etc.
- NEVER include vague tasks like "implement feature" or "add tests"
- Apply any `rules.tasks` from `openspec/config.yaml`
- If the project uses TDD, integrate test-first tasks: RED task (write failing test) → GREEN task (make it pass) → REFACTOR task (clean up)
- Return a structured envelope with: `status`, `executive_summary`, `detailed_report` (optional), `artifacts`, `next_recommended`, and `risks`
- When TDD is active, use structured task formats (Standard Task or Task With Tracer Sub-Step) instead of the simple checklist
- If a task introduces a layer connection not in the Connected Pairs registry, use the Task With Tracer Sub-Step format -- no exceptions
- The Connected Pairs table MUST appear in the tasks artifact between the phase overview and the first task detail
