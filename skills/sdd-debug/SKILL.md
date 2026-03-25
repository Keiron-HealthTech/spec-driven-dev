---
name: sdd-debug
description: >
  Systematically investigate and fix unexpected failures using root-cause-first protocol with TDD integration.
  Trigger: When the orchestrator or sdd-apply encounters an unexpected failure during implementation or verification.
license: MIT
metadata:
  author: ai-workflow
  version: "1.0"
  scope: [root]
  auto_invoke: "Debugging unexpected failures"
---

## Purpose

You are a sub-agent responsible for DEBUGGING. You systematically investigate and fix unexpected failures. You can be invoked at any point -- during Apply, Verify, or standalone for bug fixes.

## What You Receive

From the orchestrator:

- Change name (if part of an active change)
- Error description / failing test output
- Artifact store mode (`engram | openspec | none`)

## Execution and Persistence Contract

Read and follow `skills/_shared/persistence-contract.md` for mode resolution rules.

- If mode is `engram`: Save debug findings to engram with topic key `sdd/{change-name}/debug/{description}`.
- If mode is `openspec`: Write debug findings to `openspec/changes/{change-name}/debug-report.md`.
- If mode is `none`: Return findings inline only. Do not write any project files.

## Iron Law

**NO FIXES WITHOUT ROOT CAUSE INVESTIGATION FIRST.**

Do not guess. Do not patch symptoms. Find the root cause, then fix it with TDD.

## What to Do

### Phase 1: Root Cause Investigation (MUST complete before ANY fix)

1. **Read the error** -- FULL error message and stack trace, every line
2. **Reproduce consistently** -- run failing test/steps multiple times
3. **Check recent changes** -- `git diff`, could any change have caused this?
4. **Gather evidence** -- add diagnostic logging if needed (temporary)
5. **Trace data flow** -- start at failure, trace BACKWARD through call chain

### Phase 2: Pattern Analysis

1. **Find working examples** -- similar code that WORKS, what differs?
2. **Compare against spec** -- what should happen vs. what actually happens?
3. **Categorize:** state bug, logic bug, integration bug, race condition, config bug

### Phase 3: Hypothesis Testing

1. **Form SPECIFIC hypothesis** -- "X returns null because Y is uninitialized" (not "something is wrong")
2. **Test one variable at a time** -- smallest change to confirm or refute
3. **If confirmed:** proceed to fix. **If not:** new hypothesis from new evidence.

### Phase 4: Fix with TDD

Read and follow `skills/_shared/tdd-protocol.md` for the TDD cycle.

1. **Write reproducing test** -- captures the bug, MUST fail (RED)
2. **Write the fix** -- fix ROOT CAUSE, smallest change possible
3. **Verify GREEN** -- new test passes, full suite passes
4. **Commit:** `fix: {what was broken} (root cause: {cause})`

## Escalation Rule

**If 3+ fix attempts fail: STOP.**

The problem is likely architectural, not local. When escalating:

1. Summarize what was tried and why each failed
2. State current best understanding of root cause
3. Present 2-3 potential paths forward for human to decide

Do NOT continue after escalation. Wait for human guidance.

## Return Summary

Return to the orchestrator:

```json
{
  "status": "ok | escalated",
  "executive_summary": "Bug: {description}. Root cause: {cause}. Fix: {what was done}.",
  "detailed_report": "(optional) Full investigation trace with evidence.",
  "artifacts": [
    {
      "name": "debug-context",
      "topic_key": "sdd/{change-name}/debug/{description}"
    }
  ],
  "next_recommended": ["resume sdd-apply"],
  "risks": ["related areas that might have similar issues"]
}
```

## Superpowers Integration

If `superpowers:systematic-debugging` is available in the session context, also follow its 4-phase root cause investigation protocol. This complements (does not replace) the protocol defined in this file. If superpowers is not installed, the protocols in this file are the complete and self-sufficient reference.

## Anti-Patterns (Reject All)

| Anti-Pattern                      | What to Do Instead          |
| --------------------------------- | --------------------------- |
| "Quick fix" without investigation | Investigate first, always   |
| "Add a null check" (band-aid)     | Find WHY it's null          |
| Change multiple things at once    | One change at a time        |
| "It works now, not sure why"      | Understand before moving on |
| Delete and rewrite from scratch   | Trace and fix surgically    |
| Retry the same failing approach   | New hypothesis or escalate  |

## Rules

- ALWAYS investigate root cause before attempting fixes
- ALWAYS write a reproducing test before fixing (TDD cycle from `skills/_shared/tdd-protocol.md`)
- NEVER change multiple things at once
- If 3+ fix attempts fail: STOP and escalate to orchestrator
- Follow any relevant coding skills for the project stack
- Return a structured envelope with: `status`, `executive_summary`, `detailed_report` (optional), `artifacts`, `next_recommended`, and `risks`
