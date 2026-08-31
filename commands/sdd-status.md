---
description: Report the current SDD cycle state for a change, read-only
argument-hint: [change-name]
---

ROUTE: read-only

CONTRACT: `${CLAUDE_PLUGIN_ROOT}/skills/_shared/sdd-status-contract.md` — read it FIRST.

ARGUMENTS: `$ARGUMENTS` is the change name. If it is empty and exactly one active change
exists, select that change and say how it was selected. If it is empty or ambiguous with more
than one active change, ask the user to choose and STOP with `next_recommended: select-change`.
If no change exists at all, report `next_recommended: sdd-new`. Never guess.

Build the §4 projection by §7 enumeration of the artifact store — enumerate, never recall, and
read no cycle state out of the conversation. Report its five components: `artifacts`,
`taskProgress` (`total`, `completed`, `pending`, `allComplete`), `dependencies`,
`blockedReasons`, and `nextRecommended` — one §3 token, chosen by the ordered first-match
derivation table in §4.

READ-ONLY in every mode. In `engram` it calls no write tool — never `mem_save`, never
`mem_update`. In `openspec` it creates and modifies no file. In `none` it reports inline only.
It creates no `status` artifact of its own, and a run leaves the store byte-identical.
