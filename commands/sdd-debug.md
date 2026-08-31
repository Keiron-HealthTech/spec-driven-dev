---
description: Debug unexpected failures with root cause protocol
argument-hint: [change-name]
---

ROUTE: skills/sdd-debug/SKILL.md

CONTRACT: `${CLAUDE_PLUGIN_ROOT}/skills/_shared/sdd-status-contract.md` — read it FIRST.

ARGUMENTS: `$ARGUMENTS` is the change name. If it is empty and exactly one active change
exists, select that change and say how it was selected. If it is empty or ambiguous with more
than one active change, ask the user to choose and STOP with `next_recommended: select-change`.
If no change exists at all, report `next_recommended: sdd-new`. Never guess.

Launch the skill as a sub-agent per the orchestrator's launch template. It can run at any point
and belongs to no phase of the dependency graph, so it never advances the cycle by itself. Show
the user the root cause before any fix is accepted.
