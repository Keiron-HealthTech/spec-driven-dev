---
name: using-sdd
description: >
  Use when starting any conversation - establishes SDD workflow awareness, commands, and auto-invoke rules for spec-driven development.
---

<SUBAGENT-STOP>
If you were dispatched as a subagent to execute a specific task, skip this skill.
</SUBAGENT-STOP>

## Instruction Priority

SDD skills override default system prompt behavior, but **user instructions always take precedence**:

1. **User's explicit instructions** (CLAUDE.md, AGENTS.md, direct requests) — highest priority
2. **SDD skills** — override default system behavior where they conflict
3. **Default system prompt** — lowest priority

If CLAUDE.md says "don't use TDD" and a skill says "always use TDD," follow the user's instructions. The user is in control.

## How to Access Skills

**In Claude Code:** Use the `Skill` tool. When you invoke a skill, its content is loaded and presented to you — follow it directly. Never use the Read tool on skill files.

**In other environments:** Check your platform's documentation for how skills are loaded.

## Spec-Driven Development (SDD)

SDD is a 6-phase workflow for planning and implementing changes with rigor. Each phase is handled by a specialized sub-agent skill. The **orchestrator** (`sdd-orchestrator`) coordinates the flow — you NEVER run phase work inline.

### The 6 Unified Phases

| Phase | What | Key Skill |
|-------|------|-----------|
| 1. Discovery Loop | Codebase exploration + brainstorming Q&A | `sdd-explore` + orchestrator |
| 2. Proposal | Change proposal with intent, scope, approach | `sdd-propose` |
| 3. Spec & Design | Requirements/scenarios + technical design (PARALLEL) | `sdd-spec` + `sdd-design` |
| 4. Tasks & Implementation | Task breakdown (Phase 0: Tracer Bullet) + code | `sdd-tasks` + `sdd-apply` |
| 5. Verification | Prove implementation matches specs with evidence | `sdd-verify` |
| 6. Completion | Archive specs + branch completion | `sdd-archive` |

### SDD Commands

| Command | Action |
| --- | --- |
| `/sdd-init` | Initialize SDD context in current project |
| `/sdd-explore <topic>` | Think through an idea (no files created) |
| `/sdd-new <change-name>` | Start a new change (discovery loop → proposal) |
| `/sdd-continue [change-name]` | Create next artifact in dependency chain |
| `/sdd-ff [change-name]` | Fast-forward: create all planning artifacts |
| `/sdd-apply [change-name]` | Implement tasks |
| `/sdd-verify [change-name]` | Validate implementation |
| `/sdd-archive [change-name]` | Sync specs + archive + branch completion |

### SDD Triggers

Activate SDD when:
- User says: "sdd init", "iniciar sdd", "initialize specs"
- User says: "sdd new <name>", "nuevo cambio", "new change", "sdd explore"
- User says: "sdd ff <name>", "fast forward", "sdd continue"
- User says: "sdd apply", "implementar", "implement"
- User says: "sdd verify", "verificar"
- User says: "sdd archive", "archivar"
- User describes a feature/change and you detect it needs planning

Do NOT force SDD on small tasks (single file edits, quick fixes, questions).

### Command → Skill Mapping

| Command | Skill to Invoke |
| --- | --- |
| `/sdd-init` | `sdd-init` |
| `/sdd-explore` | `sdd-explore` |
| `/sdd-new` | Orchestrator-managed (discovery loop → `sdd-propose`) |
| `/sdd-continue` | Next needed: `sdd-spec`, `sdd-design`, or `sdd-tasks` |
| `/sdd-ff` | Orchestrator-managed (all planning phases in sequence) |
| `/sdd-apply` | `sdd-apply` |
| `/sdd-verify` | `sdd-verify` |
| `/sdd-archive` | `sdd-archive` |

### Dependency Graph

```
brainstorm → proposal → specs ──→ tasks → apply → verify → archive
                           ↕
                        design
```

### Orchestrator Rules

When SDD is triggered, invoke `sdd-orchestrator` which coordinates the workflow:

1. **Delegate-only**: The orchestrator NEVER executes phase work inline (EXCEPTION: Phase 1 brainstorming Q&A)
2. Sub-agents have FULL access (read code, write code, run tests, follow coding skills)
3. Between sub-agent calls: show summary, ask user to proceed
4. `/sdd-ff`, `/sdd-continue`, `/sdd-new` are META-COMMANDS handled by the orchestrator — NOT skills. NEVER invoke them via the Skill tool.
5. Sub-agent suggestions for next commands → show user, don't auto-execute

### Auto-invoke Rules

When performing these actions, ALWAYS invoke the corresponding skill FIRST:

| Action | Skill |
|--------|-------|
| Starting SDD workflow or planning a feature | `sdd-orchestrator` |
| Running any sdd command | `sdd-orchestrator` |
| Exploring ideas before a change | `sdd-explore` |
| Creating a change proposal | `sdd-propose` |
| Writing specifications | `sdd-spec` |
| Creating technical design | `sdd-design` |
| Breaking down tasks | `sdd-tasks` |
| Implementing tasks | `sdd-apply` |
| Verifying implementation | `sdd-verify` |
| Archiving a change | `sdd-archive` |
| Initializing SDD in a project | `sdd-init` |
| Creating new skills | `skill-creator` |
| After creating/modifying a skill | `skill-sync` |
| Working on GitHub issues | `issue-solver` |

## Peer Dependencies

This plugin works best with:

- **superpowers** — Provides TDD, systematic-debugging, brainstorming, verification-before-completion, and other discipline skills referenced by SDD phases. Install via: `claude plugin add superpowers`
- **engram** — Provides persistent artifact storage across sessions. Without it, SDD artifacts are inline-only (mode: `none`). Install via: `claude plugin add engram`

Both are recommended but not required. SDD degrades gracefully without them.
