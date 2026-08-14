#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

CONTRACT=skills/_shared/sdd-status-contract.md
REGISTRY=skills/_shared/engram-convention.md
ORCHESTRATOR=skills/sdd-orchestrator/SKILL.md
USING=skills/using-sdd/SKILL.md

fail() {
  echo "check-commands: FAIL — $1" >&2
  exit 1
}

# The roster is never hardcoded here: it is extracted from the consumer tables at runtime,
# so renaming a heading empties a set and fails loudly instead of passing vacuously.
table_commands() { # file, exact heading line
  awk -v h="$2" '$0 == h {f = 1; next} f && /^#/ {exit} f' "$1" |
    grep -oE '^\| `/sdd-[a-z-]+' |
    grep -oE '/sdd-[a-z-]+' |
    sort -u || true
}

TABLE_NAMES=(
  "using-sdd SDD Commands"
  "using-sdd Command → Skill Mapping"
  "sdd-orchestrator SDD Commands"
  "sdd-orchestrator Command → Skill Mapping"
)
TABLE_SETS=(
  "$(table_commands "$USING" "### SDD Commands")"
  "$(table_commands "$USING" "### Command → Skill Mapping")"
  "$(table_commands "$ORCHESTRATOR" "## SDD Commands")"
  "$(table_commands "$ORCHESTRATOR" "## Command → Skill Mapping")"
)

# B1 — the four consumer tables agree with each other and carry every command file.
for i in "${!TABLE_NAMES[@]}"; do
  if [ -z "${TABLE_SETS[$i]}" ]; then
    fail "${TABLE_NAMES[$i]}: extraction yielded no commands; the table or its heading moved"
  fi
done

if [ ! -d commands ]; then
  fail "commands/ directory is missing"
fi

command_names="$(find commands -maxdepth 1 -name '*.md' -exec basename {} .md \; | sed 's|^|/|' | sort -u || true)"

# A membership check over an empty directory proves nothing, so emptiness is itself a failure.
if [ -z "$command_names" ]; then
  fail "commands/ contains no command files; the roster check would be vacuous"
fi

# The roster is the union of every source, so an entry missing from ALL the tables — the shape
# a newly added command file takes — is still reported against each of them.
roster="$(printf '%s\n%s\n%s\n%s\n%s\n' "${TABLE_SETS[@]}" "$command_names" | grep -E '^/sdd-' | sort -u || true)"

drift=""
for i in "${!TABLE_NAMES[@]}"; do
  missing="$(comm -23 <(echo "$roster") <(echo "${TABLE_SETS[$i]}") | tr '\n' ' ' | sed 's/ *$//;s/ /, /g')"
  if [ -n "$missing" ]; then
    drift="${drift:+$drift; }${TABLE_NAMES[$i]} is missing $missing"
  fi
done

if [ -n "$drift" ]; then
  fail "command roster drift: $drift"
fi

for f in commands/*.md; do
  # B2 — the route resolves to a real skill, a meta-command, or a read-only command.
  route="$(sed -n 's/^ROUTE: //p' "$f" | head -1)"
  case "$route" in
    "")
      fail "$f: no ROUTE: line"
      ;;
    read-only | "orchestrator meta-command") ;;
    skills/*/SKILL.md)
      if [ ! -f "$route" ]; then
        fail "$f: ROUTE names $route, which does not exist"
      fi
      ;;
    *)
      fail "$f: ROUTE value '$route' is none of skills/{name}/SKILL.md, 'orchestrator meta-command', 'read-only'"
      ;;
  esac

  # B3 — a command routes and never restates; the line ceiling is the practical proxy.
  line_count="$(wc -l < "$f" | tr -d ' ')"
  if [ "$line_count" -gt 25 ]; then
    fail "$f: $line_count lines exceeds the 25-line router ceiling"
  fi

  if grep -qF 'Return a structured envelope with:' "$f"; then
    fail "$f: restates the envelope; cite the contract instead"
  fi

  if grep -qE 'done *\| *partial *\| *blocked' "$f"; then
    fail "$f: restates the status enum; cite the contract instead"
  fi

  if grep -n 'select-change' "$f" | grep -q 'resolve-review'; then
    fail "$f: restates the routing vocabulary; cite the contract instead"
  fi

  # B4 — front-matter is a closed fence carrying a description.
  if ! awk 'NR == 1 && $0 == "---" {inb = 1; next} inb && $0 == "---" {ok = 1; exit} END {exit !ok}' "$f"; then
    fail "$f: front-matter is not opened on line 1 and closed"
  fi

  if ! awk 'NR == 1 && $0 == "---" {inb = 1; next} inb && $0 == "---" {exit} inb' "$f" | grep -qE '^description:'; then
    fail "$f: front-matter has no description: key"
  fi
done

# B5 — the review ledger is a registered artifact type with its topic form documented.
if ! grep -qE '^\| `review-ledger` \| *sdd-review' "$REGISTRY"; then
  fail "engram-convention.md: no review-ledger row in the Artifact Types table"
fi

if ! grep -qF 'sdd/{change-name}/review-ledger' "$REGISTRY"; then
  fail "engram-convention.md: the review-ledger topic form sdd/{change-name}/review-ledger is not documented"
fi

# B6 — the ad-hoc ledger destination, marked as the no-active-change case.
if ! grep -qF 'review/{target-slug}/ledger' "$REGISTRY"; then
  fail "engram-convention.md: the ad-hoc ledger form review/{target-slug}/ledger is not documented"
fi

if ! grep -F 'review/{target-slug}/ledger' "$REGISTRY" | grep -qi 'no active change'; then
  fail "engram-convention.md: review/{target-slug}/ledger is not marked as the no-active-change case"
fi

# B7 — the main-spec destination, marked domain-scoped.
if ! grep -qF 'sdd/specs/' "$REGISTRY"; then
  fail "engram-convention.md: the main-spec convention sdd/specs/{domain} is not documented"
fi

if ! grep -F 'sdd/specs/' "$REGISTRY" | grep -qi 'domain-scoped'; then
  fail "engram-convention.md: sdd/specs/{domain} is not marked domain-scoped"
fi

# B8 — the registry and the status projection map describe the same change-scoped types.
if [ ! -f "$CONTRACT" ]; then
  fail "$CONTRACT is missing; the registry has no projection map to agree with"
fi

registry_types="$(
  awk '/^### Artifact Types/ {f = 1; next} f && /^#/ {exit} f' "$REGISTRY" |
    grep -E '^\| `' |
    sed -E 's/^\| `([a-z-]+)`.*/\1/' |
    sort -u || true
)"

contract_types="$(
  awk '/^## 4\. / {f = 1; next} f && /^## / {exit} f' "$CONTRACT" |
    sed -n '/^artifacts:$/,/^artifactRefs:$/p' |
    grep -E '^  [a-z]' |
    sed -E 's/:.*$//' |
    tr '/' '\n' |
    tr -d ' ' |
    grep -E '^[a-z-]+$' |
    sort -u || true
)"

if [ -z "$registry_types" ]; then
  fail "engram-convention.md: the Artifact Types table yielded no types; extraction is broken"
fi

if [ -z "$contract_types" ]; then
  fail "$CONTRACT: the §4 artifacts map yielded no types; extraction is broken"
fi

only_registry="$(comm -23 <(echo "$registry_types") <(echo "$contract_types") | tr '\n' ' ' | sed 's/ *$//;s/ /, /g')"
only_contract="$(comm -13 <(echo "$registry_types") <(echo "$contract_types") | tr '\n' ' ' | sed 's/ *$//;s/ /, /g')"

if [ -n "$only_registry" ] || [ -n "$only_contract" ]; then
  fail "artifact type drift: registry-only: ${only_registry:-none}; projection-only: ${only_contract:-none}"
fi

echo "check-commands: OK — roster frozen at $(echo "$roster" | wc -l | tr -d ' ') across four tables; registry complete"
