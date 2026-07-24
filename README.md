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
| `sdd-review` | Coordinate multi-agent code review of an implemented diff (lead-level) |
| `sdd-verify` | Validate that implementation matches specs, design, and tasks |
| `sdd-archive` | Sync delta specs to main specs and archive a completed change |
| `sdd-init` | Initialize SDD context in any project (detect stack, bootstrap) |
| `using-sdd` | Establishes SDD workflow awareness and auto-invoke rules |
| `issue-solver` | Analyze GitHub issues and create implementation plans |
| `skill-creator` | Create new AI agent skills following the Agent Skills spec |
| `skill-sync` | Sync skill metadata to `.claude/rules/` auto-invoke sections |

## Agents

The review system ships 8 dedicated agents (auto-discovered from `agents/`, dispatched as `spec-driven-dev:{agent-name}`):

| Agent | Role | Tools |
|-------|------|-------|
| `review-risk` | R1 lens — security, authorization, data exposure | Read, Grep, Glob |
| `review-readability` | R2 lens — naming, complexity, dead code | Read, Grep, Glob |
| `review-reliability` | R3 lens — tests, contracts, determinism | Read, Grep, Glob |
| `review-resilience` | R4 lens — error handling, fallbacks, observability | Read, Grep, Glob |
| `jd-judge-a` | Blind Judge A for Judgment Day dual review | Read, Grep, Glob |
| `jd-judge-b` | Blind Judge B — generated from Judge A, never hand-edited | Read, Grep, Glob |
| `review-refuter` | Batch adversarial verifier for BLOCKER/CRITICAL candidates | Read, Grep, Glob |
| `jd-fix-agent` | The only writer — applies fixes for confirmed ledger IDs | Read, Grep, Glob, Edit, Write, Bash |

## Review Workflow

`/sdd-review [change-name|target]` reviews an implemented diff — automatically after apply (Phase 4d, before verify) or ad-hoc against any PR, branch, or diff.

- **Deterministic triage**: trivial diff → 0 lenses (empty ledger still persisted); standard diff → exactly one lens by dominant risk; hot path (auth/security/payments) or over the line budget → full 4R (all four lenses); large pure-docs diff → readability only.
- **Bounded loop**: findings land in a canonical review ledger (`skills/_shared/review-ledger-contract.md`); BLOCKER/CRITICAL candidates face adversarial refutation; a single-writer fix agent resolves confirmed findings in at most 2 rounds, with a user gate before fixes.
- **Judgment Day** (explicit request only): two blind judges replace the lenses; only convergent findings are fixable, and contradictions escalate to the human.
- **Archive gate**: `sdd-archive` refuses to archive while the ledger has open BLOCKER/CRITICAL rows.

## Attribution

The multi-agent review system (4R lenses, Judgment Day judges, refuter, fix agent) is adapted from [gentle-ai](https://github.com/Gentleman-Programming/gentle-ai) by Gentleman Programming, MIT licensed.

## Peer Dependencies

- **superpowers** (recommended) — TDD, systematic debugging, and brainstorming disciplines
- **engram** (optional) — persistent memory across sessions

## License

MIT
