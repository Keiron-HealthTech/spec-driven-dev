---
description: Implement tasks
argument-hint: [change-name]
---

ROUTE: skills/sdd-apply/SKILL.md

CONTRACT: `${CLAUDE_PLUGIN_ROOT}/skills/_shared/sdd-status-contract.md` — read it FIRST.

ARGUMENTS: `$ARGUMENTS` is the change name. If it is empty and exactly one active change
exists, select that change and say how it was selected. If it is empty or ambiguous with more
than one active change, ask the user to choose and STOP with `next_recommended: select-change`.
If no change exists at all, report `next_recommended: sdd-new`. Never guess.

Launch the skill as a sub-agent per the orchestrator's launch template, one batch of tasks at a
time: Phase 0 alone with a user gate after it, then phase by phase. Never hand over the whole
task list at once. Show progress after each batch and ask before starting the next.
