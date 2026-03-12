# AI Agent Skills

This directory contains **Agent Skills** following the [Agent Skills open standard](https://agentskills.io). Skills provide domain-specific patterns, conventions, and guardrails that help AI coding assistants understand project-specific requirements.

## Setup

Run the setup script to configure skills for your AI coding assistant:

```bash
./skills/setup.sh
```

### Supported Tools

| Tool | How It Works |
|------|-------------|
| **Claude Code** | `setup.sh --claude` creates `.claude/skills/` symlink + `CLAUDE.md` copies |
| **Open Code** | Reads `AGENTS.md` and `skills/` natively — no setup needed |

## Available Skills

### Workflow Skills

| Skill | Description |
|-------|-------------|
| `skill-creator` | Create new AI agent skills |
| `skill-sync` | Sync skill metadata to AGENTS.md Auto-invoke sections |
| `issue-solver` | Analyze and implement GitHub issues |

### SDD (Spec-Driven Development)

| Skill | Description |
|-------|-------------|
| `sdd-orchestrator` | SDD workflow coordinator |
| `sdd-init` | Initialize SDD context in a project |
| `sdd-explore` | Investigate ideas before committing |
| `sdd-propose` | Create change proposals |
| `sdd-spec` | Write specifications with requirements and scenarios |
| `sdd-design` | Technical design with architecture decisions |
| `sdd-tasks` | Break down changes into implementation tasks |
| `sdd-apply` | Implement tasks following specs and design |
| `sdd-verify` | Validate implementation against specs |
| `sdd-archive` | Sync specs and archive completed changes |

## Directory Structure

```
skills/
├── {skill-name}/
│   ├── SKILL.md              # Required - main instruction and metadata
│   ├── assets/               # Optional - templates, schemas, resources
│   └── references/           # Optional - links to local docs
├── _shared/                  # Shared contracts for SDD persistence
├── setup.sh                  # AI assistant bootstrap script
└── README.md                 # This file
```

## Creating New Skills

Invoke the `skill-creator` skill for guidance, then run `skill-sync` to update AGENTS.md.

## Syncing Auto-invoke Tables

After creating or modifying skills:

```bash
./skills/skill-sync/assets/sync.sh
```
