#!/usr/bin/env bash
set -euo pipefail

SELF="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
cd "$(dirname "$0")/.."

CONTRACT=skills/_shared/domain-contract.md
PERSIST=skills/_shared/persistence-contract.md
STATUS=skills/_shared/sdd-status-contract.md

# The phase pointer is extracted from the canon at runtime; every other assertion checks a fixed
# anchor literal in a named file. These prove the rules are stated, never that they are obeyed.

FAILURES=""

fail() {
  FAILURES="${FAILURES}${FAILURES:+$'\n'}$1"
}

report() {
  if [ -n "$FAILURES" ]; then
    echo "check-domain: FAIL — $(printf '%s\n' "$FAILURES" | head -1)" >&2
    printf '%s\n' "$FAILURES" | tail -n +2 | sed 's/^/  also: /' >&2
    exit 1
  fi
}

section() { # file, section number — the body of "## {n}. ..." up to the next "## " outside a fence
  awk -v num="$2" '
    $0 ~ "^## " num "\\. " { f = 1; next }
    f && /^```/ { inf = !inf }
    f && !inf && /^## / { exit }
    f
  ' "$1"
}

heading_body() { # file, heading text — the body of "## {heading}" up to the next "## " outside a fence
  awk -v h="## $2" '
    $0 == h { f = 1; next }
    f && /^```/ { inf = !inf }
    f && !inf && /^## / { exit }
    f
  ' "$1"
}

has() { # fixed string, text on stdin
  grep -qF -- "$1"
}

# D1 — the canon exists, is not a skill, and carries its numbered sections.
if [ ! -f "$CONTRACT" ]; then
  fail "D1: $CONTRACT is missing; there is no canon to check"
  report
fi

if [ -d skills/domain-contract ]; then
  fail "D1: skills/domain-contract/ exists; the domain contract is a shared canon, not a skill"
fi

if grep -qE '^name:' "$CONTRACT"; then
  fail "D1: $CONTRACT carries a name: line; it must not claim to be a skill"
fi

if grep -qF 'TBD' "$CONTRACT"; then
  fail "D1: $CONTRACT is still marked TBD"
fi

for n in 1 2 3 4 5 6 7; do
  if ! grep -qE "^## $n\. " "$CONTRACT"; then
    fail "D1: $CONTRACT has no '## $n.' section"
  fi
done

sec1="$(section "$CONTRACT" 1)"
sec3="$(section "$CONTRACT" 3)"

# D2 — §1 names the three domain file locations.
for lit in 'GLOSSARY.md' 'GLOSSARY-MAP.md' 'docs/adr/' '{context}/docs/adr/'; do
  if ! printf '%s\n' "$sec1" | has "$lit"; then
    fail "D2: $CONTRACT §1 does not name $lit"
  fi
done

# D3 — the pointer line, read out of the first text fence of §3, is carried verbatim by exactly
# the expected phase skills.
pointer_block="$(
  printf '%s\n' "$sec3" |
    awk '/^```text/ { t++; next } /^```/ { if (t == 1) exit } t == 1'
)"
pointer_lines="$(printf '%s' "$pointer_block" | grep -c . || true)"

EXPECTED_POINTER="skills/sdd-apply/SKILL.md
skills/sdd-design/SKILL.md
skills/sdd-explore/SKILL.md
skills/sdd-spec/SKILL.md
skills/sdd-tasks/SKILL.md"

if [ "$pointer_lines" -ne 1 ]; then
  fail "D3: $CONTRACT §3's first text fence yielded $pointer_lines lines, not 1; the pointer extraction would be meaningless"
else
  pointer="$pointer_block"

  # A pointer, not a copy: it names none of the rules, and each rule it would have carried is
  # stated in the contract body outside the pointer fence.
  for anchor in 'glossary' 'ADR' 'silently' 'write' 'Domain Candidates' 'detailed_report'; do
    if printf '%s\n' "$pointer" | grep -qiF -- "$anchor"; then
      fail "D3: the domain pointer restates a contract rule ('$anchor'); it must only point at $CONTRACT"
    fi
  done
  sec3_body="$(printf '%s\n' "$sec3" | awk '/^```text/ { t++; if (t == 1) { s = 1; next } } s && /^```/ { s = 0; next } !s')"
  for lit in 'Before exploring, read' 'proceed silently'; do
    if ! section "$CONTRACT" 2 | has "$lit"; then
      fail "D3: $CONTRACT §2 does not state the rule the pointer leaves out ('$lit')"
    fi
  done
  for lit in 'read-only on domain files' '### Domain Candidates' 'detailed_report'; do
    if ! printf '%s\n' "$sec3_body" | has "$lit"; then
      fail "D3: $CONTRACT §3 does not state, outside the pointer, the rule the pointer leaves out ('$lit')"
    fi
  done

  carriers="$(grep -lxF -- "$pointer" skills/*/SKILL.md 2>/dev/null | sort || true)"
  extra="$(comm -13 <(printf '%s\n' "$EXPECTED_POINTER") <(printf '%s\n' "$carriers") | grep . | tr '\n' ' ' || true)"
  missing="$(comm -23 <(printf '%s\n' "$EXPECTED_POINTER") <(printf '%s\n' "$carriers") | grep . | tr '\n' ' ' || true)"
  if [ -n "$missing" ]; then
    fail "D3: the domain pointer line is missing from: ${missing% }"
  fi
  if [ -n "$extra" ]; then
    fail "D3: the domain pointer line is carried by files outside the expected set: ${extra% }"
  fi

  # D4 — in each carrier the pointer sits in the persistence section, where every phase reads
  # its contracts.
  while IFS= read -r f; do
    if [ -z "$f" ] || [ ! -f "$f" ]; then
      continue
    fi
    if ! heading_body "$f" 'Execution and Persistence Contract' | grep -qxF -- "$pointer"; then
      fail "D4: $f does not carry the domain pointer inside '## Execution and Persistence Contract'"
    fi
  done <<EOF
$EXPECTED_POINTER
EOF
fi

# D5 — the glossary format, the ADR offer test and the active discipline are stated, and
# sdd-design applies the offer test and returns its candidates in the report.
for lit in '_Avoid_' 'one term' 'implementation' 'PHI'; do
  if ! section "$CONTRACT" 4 | has "$lit"; then
    fail "D5: $CONTRACT §4 does not state '$lit'"
  fi
done

offer_passage="$(
  section "$CONTRACT" 5 |
    awk 'BEGIN { RS = "" } /Hard to reverse/ && /Surprising without context/ && /real trade-off/ && toupper($0) ~ /ALL THREE/'
)"
if [ -z "$offer_passage" ]; then
  for lit in 'Hard to reverse' 'Surprising without context' 'real trade-off'; do
    if ! section "$CONTRACT" 5 | has "$lit"; then
      fail "D5: $CONTRACT §5 does not state the offer condition '$lit'"
    fi
  done
  fail "D5: $CONTRACT §5 has no single passage joining Hard to reverse, Surprising without context and real trade-off under ALL THREE"
fi

# One anchor per rule, each found in no other rule of the section.
for lit in 'Challenge, immediately' 'Sharpen a vague or overloaded word' 'Stress-test the relationships' \
  'what the code does' 'one term per write' 'write only when the user explicitly asks' \
  'ask which context it belongs to'; do
  if ! section "$CONTRACT" 6 | has "$lit"; then
    fail "D5: $CONTRACT §6 does not state '$lit'"
  fi
done

# The candidates channel is cited by its one field; the other field names come from the status
# contract's §2 table, so this list cannot drift from the canon.
envelope_fields="$(section "$STATUS" 2 | sed -nE 's/^\| `([a-z_]+)` \|.*/\1/p' | sort -u)"
if [ "$(printf '%s' "$envelope_fields" | grep -c . || true)" -ne 6 ]; then
  fail "D5: $STATUS §2 did not yield 6 envelope field names; the one-field check would pass vacuously"
fi
other_fields="$(printf '%s\n' "$envelope_fields" | grep -vxF detailed_report || true)"
alone() { # id and label, text on stdin — every line naming detailed_report names no other field
  local label="$1" line field
  while IFS= read -r line; do
    for field in $other_fields; do
      if printf '%s\n' "$line" | grep -qE "(^|[^A-Za-z0-9_./-])$field([^A-Za-z0-9_-]|\$)"; then
        fail "$label names another envelope field ('$field') beside detailed_report: $line"
      fi
    done
  done < <(grep -F detailed_report || true)
}

if ! printf '%s\n' "$sec3" | has 'read-only'; then
  fail "D5: $CONTRACT §3 does not say sub-agents are read-only"
fi
# The read-only rule names every location §1 gives a domain file, or a sub-agent may read the
# one it omits as writable.
readonly_bullet="$(printf '%s\n' "$sec3" | awk '/^- / { f = ($0 ~ /read-only on domain files/) } /^$/ { f = 0 } f')"
for lit in '`GLOSSARY.md`' '`GLOSSARY-MAP.md`' '`docs/adr/`' '`{context}/docs/adr/`'; do
  if ! printf '%s\n' "$readonly_bullet" | has "$lit"; then
    fail "D5: $CONTRACT §3's read-only rule does not name $lit, a location §1 gives domain files"
  fi
done
alone "D5: $CONTRACT §3" <<<"$sec3"

DESIGN=skills/sdd-design/SKILL.md
if ! has 'ADR candidate' < "$DESIGN"; then
  fail "D5: $DESIGN has no 'ADR candidate' line in its decision template"
fi
design_rules="$(heading_body "$DESIGN" 'Rules')"
for lit in 'domain-contract.md' 'Domain Candidates'; do
  if ! printf '%s\n' "$design_rules" | has "$lit"; then
    fail "D5: $DESIGN '## Rules' does not name '$lit'"
  fi
done
if ! printf '%s\n' "$design_rules" | has 'detailed_report'; then
  fail "D5: $DESIGN '## Rules' does not name detailed_report as the candidates channel"
fi
alone "D5: $DESIGN" < "$DESIGN"

# D6 — the persistence contract carves domain files out of its base rules, and the base rules
# acknowledge the carve-out.
domain_files="$(heading_body "$PERSIST" 'Domain Files')"
if ! grep -qxF '## Domain Files' "$PERSIST"; then
  fail "D6: $PERSIST has no '## Domain Files' section"
else
  if ! printf '%s\n' "$domain_files" | has 'domain-contract.md'; then
    fail "D6: $PERSIST 'Domain Files' does not cite domain-contract.md"
  fi
  if ! printf '%s\n' "$domain_files" | grep -E '^\| `none` \|' | has 'explicit'; then
    fail "D6: $PERSIST 'Domain Files' does not gate none-mode writes on an explicit request"
  fi
  # Every location §1 gives a domain file must be inside the carve-out, or the base ban still
  # covers it in engram and none.
  for lit in '`docs/adr/`' '`{context}/docs/adr/`' 'per-context glossaries'; do
    if ! printf '%s\n' "$domain_files" | has "$lit"; then
      fail "D6: $PERSIST 'Domain Files' does not cover $lit, a location $CONTRACT §1 gives domain files"
    fi
  done
fi

common_rules="$(heading_body "$PERSIST" 'Common Rules')"
for mode in engram none; do
  if ! printf '%s\n' "$common_rules" | grep -F -- "- If mode is \`$mode\`" | has 'Domain Files'; then
    fail "D6: $PERSIST Common Rules bullet for \`$mode\` does not point at Domain Files"
  fi
done

# D7 — the orchestrator is named the only writer, its delegate-only rules make room for that,
# and its Phase 1 points at the discipline instead of copying it.
ORCH=skills/sdd-orchestrator/SKILL.md
orch_rules="$(heading_body "$ORCH" 'Orchestrator Rules')"
rule3="$(printf '%s\n' "$orch_rules" | grep -E '^3\. ' || true)"
rule10="$(printf '%s\n' "$orch_rules" | awk '/^10\. / { f = 1 } f && /^$/ { exit } f')"
phase1="$(
  awk '
    /^### Phase 1:/ { f = 1; next }
    f && /^```/ { inf = !inf }
    f && !inf && /^##+ / { exit }
    f
  ' "$ORCH"
)"

if ! printf '%s\n' "$rule3" | has 'NEVER write specs/proposals/design'; then
  fail "D7: $ORCH Rule 3 no longer forbids writing specs, proposals and design"
fi
if ! printf '%s\n' "$rule3" | has '10(c)'; then
  fail "D7: $ORCH Rule 3 does not point at the domain-file exception 10(c)"
fi
for lit in '(c)' 'skills/_shared/domain-contract.md' 'only writer' 'detailed_report'; do
  if ! printf '%s\n' "$rule10" | has "$lit"; then
    fail "D7: $ORCH Rule 10 does not state '$lit' in its domain-file exception"
  fi
done
alone "D7: $ORCH Rule 10" <<<"$rule10"
if ! grep -F '**Sub-agents have FULL access**' "$ORCH" | has 'Rule 10(c)'; then
  fail "D7: $ORCH 'Sub-agents have FULL access' does not name the domain-file limit, Rule 10(c)"
fi
if ! heading_body "$ORCH" 'Artifact Store Policy' | grep -F -- '- In `none`' | has 'explicitly asks'; then
  fail "D7: $ORCH Artifact Store Policy \`none\` line does not except a Domain File the user explicitly asks for"
fi
if ! printf '%s\n' "$phase1" | has 'domain-contract.md'; then
  fail "D7: $ORCH Phase 1 does not cite domain-contract.md"
fi
for anchor in 'challenge' 'overloaded' 'sharpen' 'stress-test' 'immediately'; do
  if printf '%s\n' "$phase1" | grep -qiF -- "$anchor"; then
    fail "D7: $ORCH Phase 1 restates the active discipline ('$anchor'); it must only point at $CONTRACT"
  fi
done
for lit in 'only writer' 'Rule 10(c)' 'detailed_report'; do
  if ! printf '%s\n' "$sec3" | has "$lit"; then
    fail "D7: $CONTRACT §3 does not state '$lit'"
  fi
done

# D8 — sdd-init detects the layout, returns the instruction-file snippet instead of applying it,
# and never creates a domain file or a missing instruction file.
INIT=skills/sdd-init/SKILL.md
block_from() { # file, line prefix — from that line to the next heading of any level outside a fence
  awk -v p="$2" '
    index($0, p) == 1 { f = 1; next }
    f && /^```/ { inf = !inf }
    f && !inf && /^#+ / { exit }
    f
  ' "$1"
}
step1b="$(block_from "$INIT" '### Step 1b')"
init_rules="$(heading_body "$INIT" 'Rules')"

if [ -z "$step1b" ]; then
  fail "D8: $INIT has no '### Step 1b' detecting the domain layout"
else
  for lit in 'domain-contract.md' 'reads only and writes nothing' 'GLOSSARY-MAP.md' 'GLOSSARY.md' \
    'CLAUDE.md' 'AGENTS.md' 'snippet' 'layout'; do
    if ! printf '%s\n' "$step1b" | has "$lit"; then
      fail "D8: $INIT Step 1b does not name '$lit'"
    fi
  done
  # Character offsets, not line numbers: both names can share one line.
  before_claude="${step1b%%CLAUDE.md*}"
  before_agents="${step1b%%AGENTS.md*}"
  if [ "${#before_claude}" -gt "${#before_agents}" ]; then
    fail "D8: $INIT Step 1b looks for AGENTS.md before CLAUDE.md"
  fi
fi

placeholder='- NEVER create placeholder spec files - specs are created via sdd-spec during a change'
if ! printf '%s\n' "$init_rules" | grep -qxF -- "$placeholder"; then
  fail "D8: $INIT Rules no longer carry the placeholder-spec rule unchanged"
elif ! printf '%s\n' "$init_rules" | grep -A1 -xF -- "$placeholder" | tail -1 |
  grep -qF -- '- NEVER create GLOSSARY.md, GLOSSARY-MAP.md or docs/adr/'; then
  fail "D8: $INIT Rules do not follow the placeholder rule with 'NEVER create GLOSSARY.md, GLOSSARY-MAP.md or docs/adr/'"
fi
for lit in 'NEVER create the missing instruction file' 'must ask the user which'; do
  if ! printf '%s\n' "$init_rules" | has "$lit"; then
    fail "D8: $INIT Rules do not state '$lit'"
  fi
done

# Each "project files" statement says where the snippet goes, so none reads as an unqualified ban
# beside the orchestrator applying it.
while IFS= read -r line; do
  if ! printf '%s\n' "$line" | has 'Step 1b'; then
    fail "D8: $INIT states a project-files rule without reconciling it with Step 1b: $line"
  fi
done < <(grep -iF 'project files' "$INIT" || true)

config_context="$(awk '/^context: \|$/ { f = 1; next } f && /^$/ { exit } f' "$INIT")"
if ! printf '%s\n' "$config_context" | grep -qE '^  Domain: '; then
  fail "D8: $INIT config.yaml context has no 'Domain:' line"
fi
if [ "$(printf '%s\n' "$config_context" | grep -c .)" -gt 10 ]; then
  fail "D8: $INIT config.yaml context exceeds its 10-line cap"
fi
for mode in engram none; do
  if ! block_from "$INIT" "#### If mode is \`$mode\`:" | has 'Domain layout:'; then
    fail "D8: $INIT Step 4 \`$mode\` summary does not report the domain layout"
  fi
done

snippet_block="$(
  printf '%s\n' "$sec3" |
    awk '/^```text/ { t++; next } /^```/ { if (t == 2) exit } t == 2'
)"
if [ "$(printf '%s' "$snippet_block" | grep -c . || true)" -ne 1 ]; then
  fail "D8: $CONTRACT §3's second text fence is not the one-line instruction-file snippet"
fi

# D9 — sdd-archive says domain files survive archiving, in its verification and its summary,
# and keeps them out of the review gate and the spec sync.
ARCHIVE=skills/sdd-archive/SKILL.md
archive_step3="$(block_from "$ARCHIVE" '### Step 3:')"
archive_step4="$(block_from "$ARCHIVE" '### Step 4:')"
for lit in '`docs/adr/`' '`{context}/docs/adr/`' 'survive archiving' 'skills/_shared/domain-contract.md'; do
  if ! printf '%s\n' "$archive_step3" | has "$lit"; then
    fail "D9: $ARCHIVE Step 3 does not state that domain files survive archiving ('$lit')"
  fi
done
if ! printf '%s\n' "$archive_step4" | grep -A1 -xF '### Domain Files' | grep -qE '^Left in place: '; then
  fail "D9: $ARCHIVE Step 4 summary has no '### Domain Files' block reporting what was left in place"
fi
if ! heading_body "$ARCHIVE" 'Rules' | has '- NEVER move, copy or delete domain files'; then
  fail "D9: $ARCHIVE Rules do not state 'NEVER move, copy or delete domain files'"
fi
for step in 'Step 0' 'Step 1'; do
  if awk -v p="### $step:" 'index($0, p) == 1 { f = 1; next } f && /^### / { exit } f' "$ARCHIVE" |
    grep -qF 'docs/adr'; then
    fail "D9: $ARCHIVE $step names docs/adr; domain files belong to Step 3 and the summary only"
  fi
done

# D10 — the README credits the upstream of the domain discipline, in one paragraph of its
# Attribution section that says the material is adapted under MIT and carries the copyright line.
credit="$(
  heading_body README.md 'Attribution' |
    awk 'BEGIN { RS = "" } /mattpocock\/skills/'
)"
for lit in 'mattpocock/skills' 'Matt Pocock' 'adapted' 'MIT' 'Copyright (c) 2026 Matt Pocock'; do
  if ! printf '%s\n' "$credit" | has "$lit"; then
    fail "D10: README.md '## Attribution' has no paragraph crediting mattpocock/skills that states '$lit'"
  fi
done

# This script must not reference the sdd-init agent file. The literal is split so the
# guard does not match itself.
if [ ! -r "$SELF" ]; then
  fail "D8: cannot read $SELF to check that it leaves the sdd-init agent file alone"
elif grep -qF "agents/sdd-init"".md" "$SELF"; then
  fail "D8: $SELF references the sdd-init agent file; its grant is out of scope"
fi

report
echo "check-domain: OK"
