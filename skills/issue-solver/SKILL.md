---
name: issue-solver
description: >
  Analyzes GitHub issues, creates detailed implementation plans, and seeks user approval.
  Trigger: When asked to "implement issue #X", "analyze issue #X", or "fix issue #X".
license: Apache-2.0
metadata:
  author: ai-workflow
  version: "1.0"
  scope: [root]
  auto_invoke: "Working on GitHub issues"
---

## When to Use

- When the user asks to work on a specific GitHub issue (e.g., "Implement issue #42").
- When the user asks for an analysis of an issue before starting work.
- When you need to understand the scope of a bug or feature request from the issue tracker.

## Critical Workflow

1.  **Read the Issue**: Use `gh issue view {number}` to fetch the title, body, and comments.
2.  **Context Discovery**:
    - Identify keywords in the issue.
    - Use `grep` and `glob` to find relevant files.
    - Read existing code to understand the current state.
3.  **Plan Formulation**:
    - Draft a step-by-step plan.
    - Identify necessary changes (files to create, modify, delete).
    - Identify verification steps (tests, lints).
4.  **User Confirmation (CRITICAL)**:
    - Present the plan to the user.
    - **STOP** and wait for "Procede" or "Go ahead".
    - Do NOT write code before this step.
5.  **Implementation**:
    - Execute the approved plan.
    - Verify with tests/lints.

## Commands

```bash
# View issue details
gh issue view 123

# View issue comments (often contain important context)
gh issue view 123 --comments
```
