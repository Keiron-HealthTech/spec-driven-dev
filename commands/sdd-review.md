---
description: Review implemented diff (triage → lenses → refute → fix; JD on request)
argument-hint: [change-name|target]
---

ROUTE: skills/sdd-review/SKILL.md

CONTRACT: `${CLAUDE_PLUGIN_ROOT}/skills/_shared/sdd-status-contract.md` — read it FIRST.

ARGUMENTS: `$ARGUMENTS` is the change name, or an ad-hoc target — a PR number, a branch, or a
stated scope. If it is empty and exactly one active change exists, select that change and say how
it was selected. If it is empty or ambiguous with more than one active change, ask the user to
choose and STOP with `next_recommended: select-change`. Never guess.

Load the skill at LEAD level with the Skill tool and follow it inline. Do NOT dispatch it as a
sub-agent: sub-agents cannot launch sub-agents, and every reviewer has to be its own Task call.
The skill owns the triage, the reviewers, the ledger, the severity floor and its own user gate.
