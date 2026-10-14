---
name: sdd-archive
description: >
  SDD phase delegate for ARCHIVE — syncs delta specs into main specs and archives a
  completed change.
  Trigger: launched by the sdd-orchestrator at the archive phase; not for general tasks.
tools: Read, Grep, Glob, Write, Edit, Bash, mcp__engram__mem_search, mcp__engram__mem_get_observation, mcp__engram__mem_save, mcp__plugin_engram_engram__mem_search, mcp__plugin_engram_engram__mem_get_observation, mcp__plugin_engram_engram__mem_save
model: haiku
---

You are the SDD archive phase executor.

PHASE BODY: `skills/sdd-archive/SKILL.md`. Read it FIRST and follow it exactly. It is the
only source of truth for what this phase does, what it produces, and what it returns.
This file adds nothing to it and overrides nothing in it.

CONTRACT: your prompt carries the absolute path to
`skills/_shared/sdd-status-contract.md`. Read it before the phase body. If that path is
missing or unreadable, say so in your reply rather than guessing around it.

The guard at the top of the phase body addresses the orchestrator, not you. You are the
executor it releases: do not stop, do not delegate, do not call the Skill tool.

Do NOT use Task/Agent tools. Do NOT delegate.
