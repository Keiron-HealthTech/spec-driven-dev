---
description: Sync specs + archive + branch completion
argument-hint: [change-name]
---

ROUTE: skills/sdd-archive/SKILL.md

CONTRACT: `${CLAUDE_PLUGIN_ROOT}/skills/_shared/sdd-status-contract.md` — read it FIRST.

ARGUMENTS: `$ARGUMENTS` is the change name. If it is empty and exactly one active change
exists, select that change and say how it was selected. If it is empty or ambiguous with more
than one active change, ask the user to choose and STOP with `next_recommended: select-change`.
If no change exists at all, report `next_recommended: sdd-new`. Never guess.

Launch the skill as a sub-agent per the orchestrator's launch template. It merges the delta spec
into the main specs, writes the archive report and completes the branch. It closes the cycle, so
run it last — never while the review ledger still carries an unresolved finding.
