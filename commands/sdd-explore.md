---
description: Think through an idea (no files created)
argument-hint: <topic>
---

ROUTE: skills/sdd-explore/SKILL.md

CONTRACT: `${CLAUDE_PLUGIN_ROOT}/skills/_shared/sdd-status-contract.md` — read it FIRST.

ARGUMENTS: `$ARGUMENTS` is the topic. If it is empty, ask the user what to explore and STOP —
there is no default topic and an active change is not one. If the exploration belongs to a named
change, say which one. Never guess.

Launch the skill as a sub-agent per the orchestrator's launch template. It researches and reports
back, and writes an artifact only when the exploration is tied to a named change. Show the user
the analysis and ask before turning any of it into a proposal.
