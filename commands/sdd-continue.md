---
description: Create next artifact in dependency chain
argument-hint: [change-name]
---

ROUTE: orchestrator meta-command

CONTRACT: `${CLAUDE_PLUGIN_ROOT}/skills/_shared/sdd-status-contract.md` — read it FIRST.

ARGUMENTS: `$ARGUMENTS` is the change name. If it is empty and exactly one active change
exists, select that change and say how it was selected. If it is empty or ambiguous with more
than one active change, ask the user to choose and STOP with `next_recommended: select-change`.
If no change exists at all, report `next_recommended: sdd-new`. Never guess.

You handle this yourself: reconstruct the cycle state, take the one artifact the dependency
states report as ready, and launch that single sub-agent. Never invoke it through the Skill tool
— it is a meta-command, not a skill. Stop after one artifact and show the user.
