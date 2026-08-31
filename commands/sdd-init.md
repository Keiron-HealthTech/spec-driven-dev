---
description: Initialize SDD context in current project
---

ROUTE: skills/sdd-init/SKILL.md

CONTRACT: `${CLAUDE_PLUGIN_ROOT}/skills/_shared/sdd-status-contract.md` — read it FIRST.

ARGUMENTS: `/sdd-init` takes none. `$ARGUMENTS` is ignored and the target is always the current
project; if something is passed, say it was ignored rather than acting on it. Never guess a
different project.

Launch the skill as a sub-agent per the orchestrator's launch template. It detects the stack and
conventions, then bootstraps whichever persistence backend the mode resolves to. Mode resolution
belongs to `skills/_shared/persistence-contract.md` — do not assume one here.
