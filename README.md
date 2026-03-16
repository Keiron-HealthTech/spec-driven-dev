# spec-driven-dev

Claude Code plugin for Spec-Driven Development (SDD) — a 6-phase workflow that turns ideas into implemented, verified code through specs, design docs, and task breakdowns.

## Installation

```
/plugin marketplace add Keiron-HealthTech/spec-driven-dev
/plugin install spec-driven-dev@spec-driven-dev
```

## Skills

| Skill | Description |
|-------|-------------|
| `sdd-orchestrator` | Unified SDD + Superpowers coordinator for the 6-phase workflow |
| `sdd-explore` | Explore and investigate ideas before committing to a change |
| `sdd-propose` | Create a change proposal with intent, scope, and approach |
| `sdd-spec` | Write specifications with requirements and scenarios |
| `sdd-design` | Create technical design document with architecture decisions |
| `sdd-tasks` | Break down a change into an implementation task checklist |
| `sdd-apply` | Implement tasks, writing actual code following specs and design |
| `sdd-verify` | Validate that implementation matches specs, design, and tasks |
| `sdd-archive` | Sync delta specs to main specs and archive a completed change |
| `sdd-init` | Initialize SDD context in any project (detect stack, bootstrap) |
| `using-sdd` | Establishes SDD workflow awareness and auto-invoke rules |
| `issue-solver` | Analyze GitHub issues and create implementation plans |
| `skill-creator` | Create new AI agent skills following the Agent Skills spec |
| `skill-sync` | Sync skill metadata to `.claude/rules/` auto-invoke sections |

## Peer Dependencies

- **superpowers** (recommended) — TDD, systematic debugging, and brainstorming disciplines
- **engram** (optional) — persistent memory across sessions

## License

MIT
