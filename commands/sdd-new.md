---
description: Start a new change (discovery loop → proposal)
argument-hint: <change-name>
---

ROUTE: orchestrator meta-command

CONTRACT: `${CLAUDE_PLUGIN_ROOT}/skills/_shared/sdd-status-contract.md` — read it FIRST.

ARGUMENTS: `$ARGUMENTS` is the change name. If it is empty, ask the user to name the change and
STOP — a change that does not exist yet has no name to infer, and an unrelated active change is
not a default. Never guess.

You handle this yourself: the discovery loop (codebase analysis delegated to sdd-explore, the
brainstorming Q&A run by you), a readiness gate, then sdd-propose. Never invoke it through the
Skill tool — it is a meta-command, not a skill. Launch one Task call per sub-agent phase and show
the user what came back between them.
