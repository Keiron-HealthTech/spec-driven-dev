---
name: skill-sync
description: >
  Syncs skill metadata to .claude/rules/ Auto-invoke sections.
  Trigger: When updating skill metadata (metadata.scope/metadata.auto_invoke), regenerating Auto-invoke tables, or running ./scripts/sync.sh (including --dry-run/--scope).
license: Apache-2.0
metadata:
  author: ai-workflow
  version: "2.0"
  scope: [root]
  auto_invoke:
    - "After creating/modifying a skill"
    - "Regenerate .claude/rules/ Auto-invoke tables (sync.sh)"
    - "Troubleshoot why a skill is missing from auto-invoke"
allowed-tools: Read, Edit, Write, Glob, Grep, Bash
---

## Purpose

Keeps `.claude/rules/{scope}-agents.md` files in sync with skill metadata. Claude Code reads `.claude/rules/` automatically, so this is the canonical location for auto-invoke tables.

## Output

The sync script generates one file per scope:

```
.claude/rules/
├── root-agents.md      ← skills with scope: [root]
├── client-agents.md    ← skills with scope: [client]
└── server-agents.md    ← skills with scope: [server]
```

Each file contains:
- **Available Skills** table (all skills for that scope)
- **Auto-invoke Skills** table (action → skill mapping)

## Required Skill Metadata

Each skill that should appear in Auto-invoke sections needs these fields in `metadata`.

`auto_invoke` can be either a single string **or** a list of actions:

```yaml
metadata:
  author: ai-workflow
  version: "1.0"
  scope: [client] # Which rules file: client, server, root

  # Option A: single action
  auto_invoke: "Creating/modifying components"

  # Option B: multiple actions
  # auto_invoke:
  #   - "Creating/modifying components"
  #   - "Refactoring component folder placement"
```

### Scope Values

| Scope    | Generates                          |
| -------- | ---------------------------------- |
| `root`   | `.claude/rules/root-agents.md`     |
| `client` | `.claude/rules/client-agents.md`   |
| `server` | `.claude/rules/server-agents.md`   |

Skills can have multiple scopes: `scope: [client, server]`

---

## Usage

### After Creating/Modifying a Skill

```bash
./scripts/sync.sh
```

### What It Does

1. Reads all `skills/*/SKILL.md` files
2. Extracts `metadata.scope`, `metadata.auto_invoke`, and `description`
3. Generates Available Skills + Auto-invoke tables per scope
4. Writes `.claude/rules/{scope}-agents.md` for each scope

---

## Example

Given this skill metadata:

```yaml
# skills/my-skill/SKILL.md
metadata:
  author: ai-workflow
  version: "1.0"
  scope: [client]
  auto_invoke: "Creating/modifying React components"
```

The sync script generates `.claude/rules/client-agents.md`:

```markdown
# Agent Skills (client)

## Available Skills

| Skill | Description | Path |
| --- | --- | --- |
| `my-skill` | My skill description | [SKILL.md](skills/my-skill/SKILL.md) |

## Auto-invoke Skills

When performing these actions, ALWAYS invoke the corresponding skill FIRST:

| Action                              | Skill           |
| ----------------------------------- | --------------- |
| Creating/modifying React components | `my-skill` |
```

---

## Commands

```bash
# Sync all scopes
./scripts/sync.sh

# Dry run (show what would change)
./scripts/sync.sh --dry-run

# Sync specific scope only
./scripts/sync.sh --scope client
```

---

## Checklist After Modifying Skills

- [ ] Added `metadata.scope` to new/modified skill
- [ ] Added `metadata.auto_invoke` with action description
- [ ] Ran `./scripts/sync.sh`
- [ ] Verified `.claude/rules/{scope}-agents.md` updated correctly
