#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

CONTRACT=skills/_shared/sdd-status-contract.md
STATUS_COMMAND=commands/sdd-status.md

# Every expected value is extracted from the canon at runtime. Nothing here hardcodes a list
# that could drift from the contract it guards.

# Failures accumulate instead of exiting at the first one: a single run then names every
# violated assertion, which is what makes a deliberate one-line mutation observable even when
# an unrelated assertion is already failing.
FAILURES=""

fail() {
  FAILURES="${FAILURES}${FAILURES:+$'\n'}$1"
}

report() {
  if [ -n "$FAILURES" ]; then
    echo "check-envelope: FAIL — $(printf '%s\n' "$FAILURES" | head -1)" >&2
    printf '%s\n' "$FAILURES" | tail -n +2 | sed 's/^/  also: /' >&2
    exit 1
  fi
}

section() { # file, section number — the body of "## {n}. ..." up to the next "## "
  awk -v num="$2" '
    $0 ~ "^## " num "\\. " { f = 1; next }
    f && /^## / { exit }
    f
  ' "$1"
}

# A1 — the canon exists. Nothing downstream means anything without it.
if [ ! -f "$CONTRACT" ]; then
  fail "$CONTRACT is missing; there is no canon to check"
  report
fi

if [ ! -f "$STATUS_COMMAND" ]; then
  fail "$STATUS_COMMAND is missing; the projection has no renderer to check"
  report
fi

sec1="$(section "$CONTRACT" 1)"
sec2="$(section "$CONTRACT" 2)"
sec3="$(section "$CONTRACT" 3)"
sec4="$(section "$CONTRACT" 4)"
sec5="$(section "$CONTRACT" 5)"
sec6="$(section "$CONTRACT" 6)"

# The routing vocabulary, read out of §3's table: first cell of every row that opens with a
# backticked token. A renamed heading empties this list, which A2 turns into a loud failure.
vocabulary="$(
  printf '%s\n' "$sec3" |
    grep -E '^\| `' |
    sed -E 's/^\|([^|]*)\|.*/\1/' |
    grep -oE '`[a-z][a-z-]*`' |
    tr -d '`' |
    sort -u || true
)"
token_count="$(printf '%s' "$vocabulary" | grep -c . || true)"

# A13 — the canon is complete. This runs first: when a section is still a stub, every other
# assertion reading it reports a symptom, and this reports the cause.
tbd="$(grep -n 'TBD' "$CONTRACT" | head -3 | sed 's/:.*//' | tr '\n' ' ' | sed 's/ *$//;s/ /, /g' || true)"
if [ -n "$tbd" ]; then
  fail "contract §2/§3/§5 still marked TBD (lines $tbd)"
fi

for field in status executive_summary detailed_report artifacts next_recommended risks; do
  if ! printf '%s\n' "$sec2" | grep -qF "\`$field\`"; then
    fail "§2 does not define the envelope field \`$field\`"
  fi
done

for value in done partial blocked; do
  if ! printf '%s\n' "$sec2" | grep -qF "$value"; then
    fail "§2 does not carry the status value \`$value\`"
  fi
done

if ! printf '%s\n' "$sec3" | grep -qF 'CLOSED'; then
  fail "§3 is not marked CLOSED"
fi

if [ "$token_count" -ne 13 ]; then
  fail "§3 defines $token_count routing tokens; the closed vocabulary is exactly 13"
fi

if ! printf '%s\n' "$sec5" | grep -qF 'partial'; then
  fail "§5 does not state the partial rule"
fi

# A2 — extraction tripwire. Below eight tokens the membership checks would pass vacuously.
if [ "$token_count" -lt 8 ]; then
  fail "§3 vocabulary extraction yielded $token_count tokens (fewer than 8); the heading or the token table moved and every membership check would pass vacuously"
fi

# A3 — the two enums have exactly one home. Any other tracked file restating either is drift.
scan_files="$(
  {
    find skills agents commands -type f -name '*.md' 2>/dev/null || true
    for f in README.md AGENTS.md; do
      if [ -f "$f" ]; then echo "$f"; fi
    done
  } | sort -u
)"

while IFS= read -r f; do
  if [ -z "$f" ] || [ "$f" = "$CONTRACT" ]; then
    continue
  fi
  if grep -qE 'done *\| *partial *\| *blocked' "$f"; then
    fail "$f restates the status enum; §2 is its only definition site"
  fi
  if grep -F 'select-change' "$f" | grep -qF 'resolve-review'; then
    fail "$f restates the routing vocabulary; §3 is its only definition site"
  fi
done <<EOF
$scan_files
EOF

# A14 — §1 resolves the contract to an absolute path and defers mode resolution.
if ! printf '%s\n' "$sec1" | grep -qF 'ABSOLUTE'; then
  fail "§1 does not require resolving this contract to an ABSOLUTE path"
fi

for mode in engram openspec none; do
  if ! printf '%s\n' "$sec1" | grep -qF "\`$mode\`"; then
    fail "§1 does not map the \`$mode\` mode"
  fi
done

if ! printf '%s\n' "$sec1" | grep -qF 'skills/_shared/persistence-contract.md'; then
  fail "§1 does not defer mode resolution to skills/_shared/persistence-contract.md by path"
fi

# A15 — the projection has five components, named identically in the canon and the renderer,
# and taskProgress carries its own derivation.
for component in artifacts taskProgress dependencies blockedReasons nextRecommended; do
  if ! printf '%s\n' "$sec4" | grep -qF "$component"; then
    fail "§4 does not name the projection component \`$component\`"
  fi
  if ! grep -qF "$component" "$STATUS_COMMAND"; then
    fail "$STATUS_COMMAND does not name the projection component \`$component\`"
  fi
done

for key in total completed pending allComplete; do
  if ! printf '%s\n' "$sec4" | grep -qF "$key"; then
    fail "§4's taskProgress does not name \`$key\`"
  fi
  if ! grep -qF "$key" "$STATUS_COMMAND"; then
    fail "$STATUS_COMMAND's taskProgress does not name \`$key\`"
  fi
done

if ! printf '%s\n' "$sec4" | grep -F '`total`' | grep -qF '`tasks`'; then
  fail "§4 does not derive taskProgress \`total\` from the \`tasks\` artifact"
fi

if ! printf '%s\n' "$sec4" | grep -F '`completed`' | grep -qF '`apply-progress`'; then
  fail "§4 does not derive taskProgress \`completed\` from the \`apply-progress\` artifact"
fi

# A16 — the routing decision is a table with an order, not a judgment call. The subsection
# heading is dropped from the extraction deliberately: it carries the words "derivation",
# "ORDERED" and "first match wins" itself, so an extraction that keeps it is answered by the
# heading alone and every row underneath could be deleted with each clause below still green.
derivation="$(printf '%s\n' "$sec4" | awk '/^### / { f = ($0 ~ /derivation/); next } f')"
if [ -z "$derivation" ]; then
  fail "§4 has no nextRecommended derivation subsection"
else
  # The rows are the derivation. They are read by the order number in their first cell, which is
  # also what makes their sequence checkable rather than merely asserted in prose.
  order_numbers="$(printf '%s\n' "$derivation" | sed -nE 's/^\|[[:space:]]*([0-9]+)[[:space:]]*\|.*/\1/p' || true)"
  row_count="$(printf '%s\n' "$order_numbers" | grep -c . || true)"

  if [ "$row_count" -ne 7 ]; then
    fail "§4's derivation table yielded $row_count numbered rows of 7; §4 declares the ordered rows exhaustive and a heading is not a row"
  fi

  if [ "$row_count" -gt 0 ] && [ "$order_numbers" != "$(seq 1 "$row_count")" ]; then
    fail "§4's derivation rows are numbered $(printf '%s' "$order_numbers" | tr '\n' ' ' | sed 's/ *$//') instead of 1..$row_count ascending; first-match evaluation has no order to follow"
  fi

  hollow="$(
    printf '%s\n' "$derivation" |
      awk -F'|' '
        /^\|[[:space:]]*[0-9]+[[:space:]]*\|/ {
          cond = $3
          outcome = $(NF - 1)
          gsub(/[[:space:]]/, "", cond)
          gsub(/[[:space:]]/, "", outcome)
          if (cond == "" || outcome == "") { printf "%s%d", (n++ ? ", " : ""), $2 + 0 }
        }
        END { if (n) printf "\n" }
      '
  )"
  if [ -n "$hollow" ]; then
    fail "§4's derivation row(s) $hollow state no condition or no outcome; a row that decides nothing cannot be first-match evaluated"
  fi

  # Every outcome the rows name is a §3 member, read out of §3 instead of listed here. Only the
  # outcome cell is scanned: the condition cells legitimately name artifact types and other files.
  outcomes="$(
    printf '%s\n' "$derivation" |
      awk -F'|' '/^\|[[:space:]]*[0-9]+[[:space:]]*\|/ { print $(NF - 1) }' |
      grep -oE '`[a-z][a-z-]*`' |
      tr -d '`' |
      sort -u || true
  )"
  outcome_count="$(printf '%s' "$outcomes" | grep -c . || true)"

  if [ "$outcome_count" -lt 5 ]; then
    fail "§4's derivation rows yielded $outcome_count outcome tokens (fewer than 5); the outcome cells moved and the membership check below would pass vacuously"
  fi

  while IFS= read -r outcome; do
    if [ -z "$outcome" ]; then
      continue
    fi
    if ! printf '%s\n' "$vocabulary" | grep -qxF "$outcome"; then
      fail "§4's derivation table routes to \"$outcome\", which is not in §3's closed vocabulary"
    fi
  done <<EOF
$outcomes
EOF

  # The prose rules, now that the heading can no longer answer for them. §4's body states the
  # first-match rule as "STOP at the first whose condition holds", which is the same rule.
  if ! printf '%s\n' "$derivation" | grep -qiE 'first match|first-match|first whose condition|stop at the first'; then
    fail "§4's derivation states no first-match rule"
  fi
  if ! printf '%s\n' "$derivation" | grep -qiE 'in the order|ordered|evaluation order'; then
    fail "§4's derivation states no explicit evaluation order"
  fi
  hedges="$(printf '%s\n' "$derivation" | grep -icE 'consider|may choose|if appropriate|at your discretion' || true)"
  if [ "$hedges" -gt 0 ]; then
    fail "§4's derivation path hedges on $hedges line(s) (consider / may choose / if appropriate / at your discretion); the decision is a table, not a judgment call"
  fi
fi

# A17 — the projection is read-only in every mode, in the canon and in the renderer.
read_only="$(
  awk '
    /^### / { f = ($0 ~ /[Rr]ead-[Oo]nly/) ; if (f) next }
    /^## / { f = 0 }
    f
  ' "$CONTRACT"
)"

if [ -z "$read_only" ]; then
  fail "$CONTRACT has no read-only section for the projection"
fi

for mode in engram openspec none; do
  if [ -n "$read_only" ] && ! printf '%s\n' "$read_only" | grep -qF "\`$mode\`"; then
    fail "$CONTRACT's read-only section does not cover the \`$mode\` mode"
  fi
  if ! grep -qF "\`$mode\`" "$STATUS_COMMAND"; then
    fail "$STATUS_COMMAND does not state the read-only rule for the \`$mode\` mode"
  fi
done

# A write verb may appear only inside an explicit prohibition — never as an instruction.
WRITE_VERBS='mem_save|mem_update|Write|Edit|persist|upsert'
PROHIBITION='never|no |not |nothing|NOT|read-only|READ-ONLY'

writes="$(grep -nE "$WRITE_VERBS" "$STATUS_COMMAND" | grep -vE "$PROHIBITION" | head -3 | tr '\n' ' ' || true)"
if [ -n "$writes" ]; then
  fail "$STATUS_COMMAND carries a write operation as an instruction: $writes"
fi

if [ -n "$read_only" ]; then
  writes="$(printf '%s\n' "$read_only" | grep -nE "$WRITE_VERBS" | grep -vE "$PROHIBITION" | head -3 | tr '\n' ' ' || true)"
  if [ -n "$writes" ]; then
    fail "$CONTRACT's read-only section carries a write operation as an instruction: $writes"
  fi
fi

# A18 — partial comes from a countable signal or not at all.
for type in tasks apply-progress review-ledger; do
  if ! printf '%s\n' "$sec5" | grep -qF "\`$type\`"; then
    fail "§5 does not name the countable type \`$type\`"
  fi
done

for type in explore brainstorm proposal spec design verify-report archive-report; do
  if ! printf '%s\n' "$sec5" | grep -qF "\`$type\`"; then
    fail "§5 does not list the binary type \`$type\`"
  fi
done

if ! printf '%s\n' "$sec5" | grep -F 'MUST NOT' | grep -qi 'prose'; then
  fail "§5 does not prohibit inferring completeness from prose in MUST NOT form"
fi

if ! printf '%s\n' "$sec5" | grep -F 'MUST NOT' | grep -qF 'taskProgress'; then
  fail "§5 does not state that artifact state and taskProgress MUST NOT be conflated"
fi

# A19 — dependency states cover every phase of the graph, and only the graph.
for phase in brainstorm proposal spec design tasks apply review verify archive; do
  if ! printf '%s\n' "$sec6" | grep -qF "\`$phase\`"; then
    fail "§6 does not report the \`$phase\` phase"
  fi
done

dep_keys="$(
  printf '%s\n' "$sec4" |
    awk '/^dependencies:/ { f = 1; next } f && /^[a-zA-Z]/ { exit } f' |
    tr '/' '\n' |
    tr -d ' ' |
    grep -E '^[a-z-]+$' |
    sort -u || true
)"

for phase in brainstorm proposal spec design tasks apply review verify archive; do
  if ! printf '%s\n' "$dep_keys" | grep -qx "$phase"; then
    fail "§4's dependencies key list omits the \`$phase\` phase"
  fi
done

if ! printf '%s\n' "$sec6" | grep -qE 'blocked *\| *ready *\| *all_done'; then
  fail "§6 does not enumerate the dependency states blocked | ready | all_done"
fi

if ! printf '%s\n' "$sec6" | grep -F 'sdd-debug' | grep -qiE 'not a|outside'; then
  fail "§6 does not state that sdd-debug sits outside the dependency graph"
fi

# The six field names and the status enum, read out of §2 so nothing below can drift from the
# canon it guards.
fields="$(
  printf '%s\n' "$sec2" |
    sed -nE 's/^\| `([a-z_]+)` \|.*/\1/p' |
    sort -u || true
)"
field_count="$(printf '%s' "$fields" | grep -c . || true)"
field_list="$(printf '%s' "$fields" | tr '\n' ' ')"

status_enum="$(
  printf '%s\n' "$sec2" |
    grep -F '| `status` |' |
    sed -E 's/.*enum `([^`]*)`.*/\1/' |
    tr '|' '\n' |
    tr -d ' \\' |
    grep -E '^[a-z]+$' |
    sort -u || true
)"
status_count="$(printf '%s' "$status_enum" | grep -c . || true)"

# Extraction tripwires, in the spirit of A2: a renamed or reshaped §2 table would empty either
# list and let every membership and restatement check below pass vacuously.
if [ "$field_count" -ne 6 ]; then
  fail "§2's field-name extraction yielded $field_count of 6; the schema table moved and the inline-restatement check would pass vacuously"
fi

if [ "$status_count" -ne 3 ]; then
  fail "§2's status enum extraction yielded $status_count of 3; the status membership check would pass vacuously"
fi

member() { # value, newline-separated set
  printf '%s\n' "$2" | grep -qxF "$1"
}

# A5 — the envelope-producing sites cite the canon by path. There are TWELVE: the ten executors,
# the orchestrator's launch template, and the lead-level review skill. The executor set below is
# ten; the citing set is twelve, and they are deliberately not the same array.
EXECUTORS="skills/sdd-explore/SKILL.md
skills/sdd-propose/SKILL.md
skills/sdd-spec/SKILL.md
skills/sdd-design/SKILL.md
skills/sdd-tasks/SKILL.md
skills/sdd-apply/SKILL.md
skills/sdd-verify/SKILL.md
skills/sdd-archive/SKILL.md
skills/sdd-debug/SKILL.md
skills/sdd-init/SKILL.md"

CITING_SITES="$EXECUTORS
skills/sdd-orchestrator/SKILL.md
skills/sdd-review/SKILL.md"

site_count="$(printf '%s\n' "$CITING_SITES" | grep -c . || true)"
uncited=""
while IFS= read -r f; do
  if [ -z "$f" ]; then
    continue
  fi
  if [ ! -f "$f" ] || ! grep -qF "$CONTRACT" "$f"; then
    uncited="${uncited}${uncited:+, }$f"
  fi
done <<EOF
$CITING_SITES
EOF

if [ -n "$uncited" ]; then
  fail "$site_count envelope-producing sites must cite $CONTRACT by path; missing in: $uncited"
fi

while IFS= read -r f; do
  if [ -z "$f" ] || [ ! -f "$f" ]; then
    continue
  fi
  for ref in '§2' '§3'; do
    if ! grep -qF "$ref" "$f"; then
      fail "$f does not cite $ref; an executor names both the envelope section and the routing section"
    fi
  done
done <<EOF
$EXECUTORS
EOF

LEGACY='Return a structured envelope with:'

while IFS= read -r f; do
  if [ -z "$f" ] || [ "$f" = "$CONTRACT" ]; then
    continue
  fi

  # A4 — no inline restatement of the envelope, in either shape: the legacy bullet verbatim, or
  # any line naming three or more of the six fields.
  if grep -qF "$LEGACY" "$f"; then
    fail "$f restates the envelope inline (\"$LEGACY\"); §2 is its only definition site"
  fi

  inline="$(
    awk -v fields="$field_list" -v file="$f" '
      BEGIN { n = split(fields, F, " +") }
      {
        c = 0
        for (i = 1; i <= n; i++) {
          if (F[i] != "" && match($0, "(^|[^A-Za-z0-9_./-])" F[i] "([^A-Za-z0-9_-]|$)")) c++
        }
        if (c >= 3) {
          printf "%s:%d enumerates %d envelope field names on one line; cite §2 by path instead\n", file, FNR, c
          exit
        }
      }
    ' "$f"
  )"
  if [ -n "$inline" ]; then
    fail "$inline"
  fi

  # A6 — every routing literal is a §3 member and every status literal a §2 member, repo-wide,
  # with no per-file exemption.
  tokens="$(
    {
      grep -oE '`next_recommended: [a-z][a-z-]*`' "$f" | sed -E 's/^`next_recommended: //; s/`$//' || true
      grep -oE '"next_recommended" *: *\[[^]]*\]' "$f" |
        sed -E 's/.*\[//; s/\].*//' |
        tr ',' '\n' |
        sed -E 's/^[[:space:]]*"?//; s/"?[[:space:]]*$//' || true
    } | grep -v '^$' | sort -u || true
  )"
  while IFS= read -r t; do
    if [ -z "$t" ]; then
      continue
    fi
    if ! member "$t" "$vocabulary"; then
      fail "$f assigns next_recommended the value \"$t\", which is not in §3's closed vocabulary"
    fi
  done <<EOF
$tokens
EOF

  statuses="$(
    {
      grep -oE '"status" *: *"[^"]*"' "$f" | sed -E 's/.*: *"//; s/"$//' | tr '|' '\n' || true
      grep -oE '`status: [^`]*`' "$f" | sed -E 's/^`status: //; s/`$//' | tr '|' '\n' || true
    } | sed -E 's/^[[:space:]]*//; s/[[:space:]]*$//' | grep -v '^$' | sort -u || true
  )"
  while IFS= read -r s; do
    if [ -z "$s" ]; then
      continue
    fi
    if ! member "$s" "$status_enum"; then
      fail "$f assigns status the value \"$s\", which is not in §2's enum"
    fi
  done <<EOF
$statuses
EOF

  # A7 — a line mentioning next_recommended either states its value in §3 citation form or names
  # no value at all. A bare backticked token beside the mention is drift A6 cannot see, because
  # A6 only reads values that are already in citation form.
  stray="$(
    awk -v fields="$field_list" -v file="$f" '
      /next_recommended/ {
        line = $0
        gsub(/`next_recommended: [a-z][a-z-]*`/, "", line)
        gsub(/"next_recommended"[[:space:]]*:[[:space:]]*\[[^]]*\]/, "", line)
        n = split(fields, F, " +")
        for (i = 1; i <= n; i++) {
          if (F[i] != "") gsub("`" F[i] "`", "", line)
        }
        toks = ""
        delete seen
        while (match(line, /`[a-z][a-z-]*`/)) {
          t = substr(line, RSTART + 1, RLENGTH - 2)
          if (!(t in seen)) {
            seen[t] = 1
            toks = toks (toks == "" ? "" : ", ") t
          }
          line = substr(line, RSTART + RLENGTH)
        }
        if (toks != "") {
          printf "%s:%d mentions next_recommended beside the backticked token(s) %s, which are not in §3 citation form\n", file, FNR, toks
          exit
        }
      }
    ' "$f"
  )"
  if [ -n "$stray" ]; then
    fail "$stray"
  fi
done <<EOF
$scan_files
EOF

# A6 — the three known offenders are migrated, positively. Membership alone cannot see a value
# that was deleted rather than corrected.
if grep -qF 'resume sdd-apply' skills/sdd-debug/SKILL.md; then
  fail "skills/sdd-debug/SKILL.md still carries the free-text routing value \"resume sdd-apply\""
fi

if ! grep -qF '`next_recommended: resolve-review`' skills/sdd-archive/SKILL.md; then
  fail "skills/sdd-archive/SKILL.md's blocked-archive path does not set \`next_recommended: resolve-review\`"
fi

for token in verify resolve-review; do
  if ! grep -qF "\`next_recommended: $token\`" skills/sdd-review/SKILL.md; then
    fail "skills/sdd-review/SKILL.md does not route \`next_recommended: $token\`"
  fi
done

# The two guard shapes are told apart by their exact opening line, matched whole-line and
# fixed-string. A mutated marker is a different guard, which is what keeps the negative
# assertion below unambiguous.
STD_MARKER='> **ORCHESTRATOR GATE** — If you loaded this file with the Skill tool, you are the'
INV_MARKER='> **LEAD-LEVEL SKILL** — this skill is the ONE exception to the executor gate that guards'
OVERRIDE_HEADING='## Executor Override'
REVIEW_SKILL=skills/sdd-review/SKILL.md
USING_SDD=skills/using-sdd/SKILL.md
SUBAGENT_STOP='<SUBAGENT-STOP>'

executor_count="$(printf '%s\n' "$EXECUTORS" | grep -c . || true)"
all_skills="$(find skills -mindepth 2 -maxdepth 2 -name 'SKILL.md' | sort)"

# A8 — every executor opens with the standard gate and carries the override that releases the
# launched sub-agent from it. One without the other leaves a skill nobody may execute.
no_gate=""
no_override=""
while IFS= read -r f; do
  if [ -z "$f" ]; then
    continue
  fi
  if [ ! -f "$f" ] || ! grep -qxF "$STD_MARKER" "$f"; then
    no_gate="${no_gate}${no_gate:+, }$f"
  fi
  if [ ! -f "$f" ] || ! grep -qxF "$OVERRIDE_HEADING" "$f"; then
    no_override="${no_override}${no_override:+, }$f"
  fi
done <<EOF
$EXECUTORS
EOF

if [ -n "$no_gate" ]; then
  fail "$executor_count executor skills must open with the standard gate line; missing in: $no_gate"
fi

if [ -n "$no_override" ]; then
  fail "$executor_count executor skills must carry an \"$OVERRIDE_HEADING\" section; missing in: $no_override"
fi

# A9 — and nowhere else. Without this a standard guard could enter the lead-level skill under a
# mutated marker, where only A11's fixed string would ever see it.
while IFS= read -r f; do
  if [ -z "$f" ] || member "$f" "$EXECUTORS"; then
    continue
  fi
  if grep -qxF "$STD_MARKER" "$f"; then
    fail "$f carries the standard executor gate; it belongs in exactly the $executor_count executor skills"
  fi
  if grep -qxF "$OVERRIDE_HEADING" "$f"; then
    fail "$f carries an \"$OVERRIDE_HEADING\" section; it belongs in exactly the $executor_count executor skills"
  fi
done <<EOF
$all_skills
EOF

# A10 — the lead-level skill carries the inverted guard instead, and cites the rule that makes it
# the one exception.
if ! grep -qxF "$INV_MARKER" "$REVIEW_SKILL"; then
  fail "$REVIEW_SKILL must carry the inverted lead-level guard; its opening line is absent"
fi

if ! grep -qF 'Rule 10 exception (b)' "$REVIEW_SKILL"; then
  fail "$REVIEW_SKILL's guard does not cross-reference orchestrator Rule 10 exception (b)"
fi

# A11 — NEGATIVE, and mandatory. A presence-only sweep over the executors would silently reward
# the one regression that matters: the lead-level skill acquiring the executor gate. §13's
# editorial rule keeps the literal out of this file, which is what makes a plain fixed-string
# search safe here.
if grep -qF 'ORCHESTRATOR GATE' "$REVIEW_SKILL"; then
  fail "$REVIEW_SKILL contains the literal ORCHESTRATOR GATE; the lead-level skill must never carry the executor gate (§13 editorial rule)"
fi

if grep -qxF "$OVERRIDE_HEADING" "$REVIEW_SKILL"; then
  fail "$REVIEW_SKILL carries an \"$OVERRIDE_HEADING\" section; the lead-level skill is not an executor"
fi

# A12 — the third shape is left alone. Skip-on-dispatch is a different mechanism for a different
# purpose, and it stays in the one always-on skill.
if ! grep -qF "$SUBAGENT_STOP" "$USING_SDD"; then
  fail "$USING_SDD no longer carries its $SUBAGENT_STOP block"
fi

while IFS= read -r f; do
  if [ -z "$f" ] || [ "$f" = "$USING_SDD" ]; then
    continue
  fi
  if grep -qF "$SUBAGENT_STOP" "$f"; then
    fail "$f adopted $SUBAGENT_STOP; that block belongs to $USING_SDD alone"
  fi
done <<EOF
$all_skills
EOF

# The gatekeeper section, the validator agent and the archive sync are checked against the canon
# they cite: the five check names, the dispatch mapping, the precedence ordering, the gate
# identities and the main-spec topic form are all extracted, never restated here.
ORCHESTRATOR=skills/sdd-orchestrator/SKILL.md
VALIDATOR=agents/phase-validator.md
ARCHIVE_SKILL=skills/sdd-archive/SKILL.md
CONVENTION=skills/_shared/engram-convention.md
README=README.md
GATE_HEADING='## Automatic Mode Gatekeeper'
CYCLE_HEADING='## Cycle State'
LEGACY_STATE='## State Tracking'

sec7="$(section "$CONTRACT" 7)"
sec8="$(section "$CONTRACT" 8)"
sec9="$(section "$CONTRACT" 9)"
sec11="$(section "$CONTRACT" 11)"
sec12="$(section "$CONTRACT" 12)"

heading_body() { # file, exact "## " heading line — its body up to the next "## "
  awk -v h="$2" '$0 == h { f = 1; next } f && /^## / { exit } f' "$1"
}

trim() { printf '%s' "$1" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//'; }

# A statement may name a forbidden path only to forbid it. These are the words that turn a
# mention into a prohibition; a line naming one of those paths without one of these is a claim.
NEGATION='never|not |no |none|nothing|cannot|neither|without'

unnegated() { # text, pattern — the first lines stating the pattern without negating it
  printf '%s\n' "$1" | grep -inE "$2" | grep -viE "$NEGATION" | head -2 | tr '\n' ' ' || true
}

gate="$(heading_body "$ORCHESTRATOR" "$GATE_HEADING")"
cycle="$(heading_body "$ORCHESTRATOR" "$CYCLE_HEADING")"

# The gate's vocabulary, read out of §8: the five check names and the per-boundary dispatch
# mapping. A renamed check or a moved table empties these lists, which the counts below turn
# into a loud failure instead of a vacuous pass.
check_names="$(printf '%s\n' "$sec8" | sed -nE 's/^\| [1-5] \| ([^|]*[^|[:space:]])[[:space:]]*\|.*/\1/p' || true)"
check_name_count="$(printf '%s' "$check_names" | grep -c . || true)"

inline_boundaries="$(
  printf '%s\n' "$sec8" |
    awk -F'|' '$3 ~ /inline/ && $2 ~ /`/ { print $2 }' |
    grep -oE '`[a-z-]+`' | tr -d '`' | sort -u || true
)"
delegated_boundaries="$(
  printf '%s\n' "$sec8" |
    awk -F'|' '$3 ~ /phase-validator/ { print $2 }' |
    grep -oE '`[a-z-]+`' | tr -d '`' | sort -u || true
)"
inline_count="$(printf '%s' "$inline_boundaries" | grep -c . || true)"
delegated_count="$(printf '%s' "$delegated_boundaries" | grep -c . || true)"

if [ "$check_name_count" -ne 5 ]; then
  fail "§8's check table yielded $check_name_count of 5 check names; the gatekeeper's naming check would pass vacuously"
fi

if [ "$inline_count" -lt 4 ] || [ "$delegated_count" -ne 2 ]; then
  fail "§8's dispatch table yielded $inline_count inline and $delegated_count delegated boundaries; the hybrid-split check would pass vacuously"
fi

# A20 — the gatekeeper NAMES the five checks and maps every boundary. Naming is not defining:
# §8 stays the only definition site, and every name below is read out of it.
if [ -z "$gate" ]; then
  fail "$ORCHESTRATOR has no \"$GATE_HEADING\" section; the phase gate has no procedure"
else
  while IFS= read -r name; do
    if [ -z "$name" ]; then
      continue
    fi
    if ! printf '%s\n' "$gate" | grep -qiF "$name"; then
      fail "the $GATE_HEADING section does not name §8 check \"$name\""
    fi
  done <<EOF
$check_names
EOF

  for boundary in $inline_boundaries; do
    if ! printf '%s\n' "$gate" | grep -qF "\`$boundary\`"; then
      fail "the $GATE_HEADING section does not map the \`$boundary\` boundary that §8 validates inline"
    fi
  done

  for boundary in $delegated_boundaries; do
    if ! printf '%s\n' "$gate" | grep -qF "\`$boundary\`"; then
      fail "the $GATE_HEADING section does not map the \`$boundary\` boundary that §8 sends to a fresh-context validator"
    fi
  done

  if ! printf '%s\n' "$gate" | grep -qF 'spec-driven-dev:phase-validator'; then
    fail "the $GATE_HEADING section does not dispatch the validator by its namespaced spec-driven-dev:phase-validator name"
  fi

  if ! printf '%s\n' "$gate" | grep -i 'judgment' | grep -qi 'predicate'; then
    fail "the $GATE_HEADING section does not label checks 3-5 as judgments applied by an agent rather than mechanical predicates"
  fi

  if ! printf '%s\n' "$gate" | grep -qiF 'enforced by tooling'; then
    fail "the $GATE_HEADING section does not state that none of the five checks is enforced by tooling"
  fi

  claimed="$(unnegated "$gate" 'enforced by tooling')"
  if [ -n "$claimed" ]; then
    fail "the $GATE_HEADING section claims tool enforcement for a gate check: $claimed"
  fi

  # A21 — one re-run, then a report. The budget is absolute and no third path exists.
  if ! printf '%s\n' "$gate" | grep -qF 'EXACTLY ONCE'; then
    fail "the $GATE_HEADING section does not bound the re-run at EXACTLY ONCE"
  fi

  if ! printf '%s\n' "$gate" | grep -qi 'corrective feedback'; then
    fail "the $GATE_HEADING section does not pass the failed checks back as corrective feedback"
  fi

  # The STOP outcome is one statement, not three scattered words. Checking the three parts
  # separately would let the precedence string at the foot of the section satisfy "STOP" on its
  # own, so they are required together, on one line.
  if ! printf '%s\n' "$gate" | grep -F 'STOP' | grep -F '`status: blocked`' | grep -qF 'blockedReasons[]'; then
    fail "the $GATE_HEADING section does not state the STOP outcome as \`status: blocked\` with blockedReasons[] on one line"
  fi

  # And the consequence is stated as a prohibition. "before any dependent phase starts" names
  # dependent phases without forbidding anything, so a negation is required.
  halted="$(printf '%s\n' "$gate" | grep -iE 'dependent phase' | grep -icE "$NEGATION" || true)"
  if [ "$halted" -eq 0 ]; then
    fail "the $GATE_HEADING section never states that NO dependent phase advances after a STOP"
  fi

  third="$(unnegated "$gate" 'attempt 3|third attempt|third run|retry with|different prompt|escalate.{0,14}retry|try again')"
  if [ -n "$third" ]; then
    fail "the $GATE_HEADING section opens a path beyond the second attempt: $third"
  fi

  if ! printf '%s\n' "$gate" | grep -qiE 'approval|approve|permission'; then
    fail "the $GATE_HEADING section does not state that the gate never asks the user for approval"
  fi

  asks="$(unnegated "$gate" 'ask[a-z]* (the user )?(for )?(approval|permission)|request approval|approval request')"
  if [ -n "$asks" ]; then
    fail "the $GATE_HEADING section turns a gate failure into an approval request: $asks"
  fi
fi

# A22 — the validator is structurally unable to write, persist or delegate, and it is not a
# reviewer. Review vocabulary may appear only inside the explicit disclaimer that denies it.
if [ ! -f "$VALIDATOR" ]; then
  fail "$VALIDATOR is missing; the design and apply boundaries have no fresh-context validator"
else
  if ! grep -qxF 'name: phase-validator' "$VALIDATOR"; then
    fail "$VALIDATOR does not declare \`name: phase-validator\`; the namespaced dispatch would not resolve"
  fi

  # The whole declaration, not its first line: an inline comma list and a YAML block sequence
  # are both read, and the MCP namespace prefix is stripped before the verb test, so
  # `mcp__engram__mem_save` is a write grant while `mcp__engram__mem_search` is not.
  if ! grep -qE '^tools:' "$VALIDATOR"; then
    fail "$VALIDATOR declares no \`tools:\` line; an unrestricted validator can write what it is meant to check"
  else
    granted="$(
      awk '
        !seen && /^tools:/ {
          seen = 1
          value = $0
          sub(/^tools:[ \t]*/, "", value)
          if (value != "") { print value; exit }
          block = 1
          next
        }
        block && /^[ \t]*-[ \t]+[^ \t]/ { sub(/^[ \t]*-[ \t]+/, ""); print; next }
        block { exit }
      ' "$VALIDATOR" |
        tr -d "\"'[]" |
        tr ',' '\n' |
        sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//' |
        grep -v '^$' || true
    )"

    if [ -z "$granted" ]; then
      fail "$VALIDATOR declares an empty \`tools:\` value; the write boundary would be scanned vacuously"
    fi

    while IFS= read -r tool; do
      if [ -z "$tool" ]; then
        continue
      fi
      if ! printf '%s\n' "$tool" | grep -qE '^[A-Za-z][A-Za-z0-9_.:-]*$'; then
        fail "$VALIDATOR declares the unparseable \`tools:\` entry \"$tool\"; the write boundary would be scanned vacuously"
        continue
      fi
      for t in Edit Write Bash Task mem_save mem_update; do
        case "${tool##*__}" in
          "$t"*)
            fail "$VALIDATOR grants the $t tool as \"$tool\"; the validator must be structurally unable to write, persist or delegate"
            ;;
        esac
      done
    done <<EOF
$granted
EOF
  fi

  if ! grep -qiE '^## .*not adversarial review' "$VALIDATOR"; then
    fail "$VALIDATOR has no explicit \"NOT adversarial review\" disclaimer section; review vocabulary has nowhere legitimate to sit"
  fi

  leaked="$(
    awk '
      /^## / { inside = (tolower($0) ~ /not adversarial review/) }
      { line = tolower($0) }
      !inside && line ~ /lens|refuter|judgment day|4r|blocker|severity/ {
        printf "%s%d", (n++ ? ", " : ""), FNR
      }
      END { if (n) printf "\n" }
    ' "$VALIDATOR"
  )"
  if [ -n "$leaked" ]; then
    fail "$VALIDATOR carries review vocabulary outside its NOT-adversarial-review disclaimer (line(s) $leaked); it validates artifacts, not diffs"
  fi

  if grep -qE 'spec-driven-dev:(review|jd)-' "$VALIDATOR"; then
    fail "$VALIDATOR dispatches a review agent; it opens no review budget and cannot delegate"
  fi
fi

# A23 — the three gates are identified with owner and kind in both places, and both carry the
# same precedence ordering, extracted from §11.
ordering="$(printf '%s\n' "$sec11" | grep -oE '`[^`]*G3 STOP[^`]*`' | head -1 | tr -d '`' || true)"
if [ -z "$ordering" ]; then
  fail "§11 states no precedence ordering containing G3 STOP; the ordering check would pass vacuously"
fi

gate_rows="$(printf '%s\n' "$sec11" | awk -F'|' '$2 ~ /^ *G[123] *$/ { print $4 "~" $5 }' || true)"
gate_row_count="$(printf '%s' "$gate_rows" | grep -c . || true)"
if [ "$gate_row_count" -ne 3 ]; then
  fail "§11's gate table yielded $gate_row_count of 3 gates; G1, G2 and G3 must each carry a kind and an owner"
fi

if [ -n "$gate" ]; then
  # Each gate needs its own row. A bare mention would be satisfied by the section's closing
  # sentence, and G1 and G2 share a kind and an owner, so a deleted G1 row would otherwise leave
  # every clause here green.
  for g in G1 G2 G3; do
    if ! printf '%s\n' "$gate" | grep -qE "^\| $g \|"; then
      fail "the $GATE_HEADING section has no $g row; §11's three gates are each identified with a kind and an owner in both places"
    fi
  done

  while IFS= read -r row; do
    if [ -z "$row" ]; then
      continue
    fi
    kind="$(trim "${row%%~*}")"
    owner="$(trim "${row##*~}")"
    for value in "$kind" "$owner"; do
      if [ -n "$value" ] && ! printf '%s\n' "$gate" | grep -qF "$value"; then
        fail "the $GATE_HEADING section omits the §11 gate attribute \"$value\"; each gate is documented with its kind and its owner"
      fi
    done
  done <<EOF
$gate_rows
EOF

  if [ -n "$ordering" ] && ! printf '%s\n' "$gate" | grep -qF "$ordering"; then
    fail "the $GATE_HEADING section does not state the precedence order \"$ordering\""
  fi
fi

# A24 — the limitation is disclosed where it is claimed, as a first-class numbered section that
# names the authority this plugin does not have.
SELF_POLICING='self-policing'
for f in "$CONTRACT" "$ORCHESTRATOR" "$README"; do
  if ! grep -qF "$SELF_POLICING" "$f"; then
    fail "$f does not disclose that the gate is $SELF_POLICING"
  fi
done

if [ -n "$gate" ] && ! printf '%s\n' "$gate" | grep -qF "$SELF_POLICING"; then
  fail "the $GATE_HEADING section does not open by admitting the gate is $SELF_POLICING"
fi

unnumbered="$(
  awk -v pat="$SELF_POLICING" '
    /^## / { h = $0 }
    index($0, pat) && h !~ /^## [0-9]+\. / { printf "%s%d", (n++ ? ", " : ""), FNR }
    END { if (n) printf "\n" }
  ' "$CONTRACT"
)"
if [ -n "$unnumbered" ]; then
  fail "$CONTRACT discloses $SELF_POLICING outside a numbered \"## {N}.\" section (line(s) $unnumbered); the limitation is not a footnote"
fi

if ! printf '%s\n' "$sec12" | grep -qF "$SELF_POLICING"; then
  fail "$CONTRACT §12 does not carry the $SELF_POLICING disclosure"
fi

for machinery in 'attempt ledger' 'receipts' 'reviewTransaction' 'allowedEditRoots'; do
  if ! printf '%s\n' "$sec12" | grep -qF "$machinery"; then
    fail "$CONTRACT §12 does not name the absent machinery \"$machinery\"; the limits section must say what is not ported"
  fi
done

# A29 — the derivation row keyed on a gate STOP has somewhere to read that STOP from. A row
# whose condition nothing can ever satisfy is a dead row in a table §4 calls exhaustive, and the
# phase whose artifact never cleared the gate would then read back as done.
stop_record="$(awk '/^### Gate STOP Record/ { f = 1; next } f && /^#/ { exit } f' "$CONVENTION")"
stop_topic="$(printf '%s\n' "$stop_record" | grep -oE 'sdd/\{change-name\}/[a-z-]+' | head -1 || true)"
stop_type="${stop_topic##*/}"

if [ -z "$stop_topic" ]; then
  fail "$CONVENTION documents no gate STOP record topic; §4's derivation row keyed on a recorded STOP would have no recording site and every clause below would pass vacuously"
else
  # The row itself, found by its condition rather than by its position, so a renumbered table is
  # still checked and a deleted row is still missed.
  stop_row="$(printf '%s\n' "$derivation" | awk -F'|' '/^\|[[:space:]]*[0-9]+[[:space:]]*\|/ && $3 ~ /STOP/ { print; exit }')"
  if [ -z "$stop_row" ]; then
    fail "§4's derivation table has no row conditioned on a gate STOP; the gate's STOP outcome would route nowhere"
  elif ! printf '%s\n' "$stop_row" | grep -qi 'unresolved'; then
    fail "§4's derivation row for a gate STOP does not key on an UNRESOLVED record; a cleared STOP would keep routing to it forever"
  fi

  # The record is enumerated, in both durable modes, by the topic form the convention defines.
  if ! printf '%s\n' "$sec7" | grep -qF "$stop_topic"; then
    fail "§7 does not enumerate $stop_topic; a STOP recorded there would never be read back and the derivation row would stay dead"
  fi

  if ! printf '%s\n' "$sec7" | grep -qF "${stop_type}.md"; then
    fail "§7 names no ${stop_type}.md path for the \`openspec\` mode; the record would be enumerable in one durable store only"
  fi

  # And it is written, durably, with a way out. A record nothing clears blocks the change forever.
  if ! printf '%s\n' "$sec9" | grep -F "$stop_type" | grep -qi 'record'; then
    fail "§9 does not record the STOP in the $stop_type record; a reported STOP dies with the session that reported it"
  fi

  if ! printf '%s\n' "$sec9" | grep -qi 'survives a compaction'; then
    fail "§9 does not state that the STOP record survives a compaction; durability is the whole point of recording it"
  fi

  if ! printf '%s\n' "$sec9" | grep -qiE 'cleared|clears'; then
    fail "§9 states no way to clear a recorded STOP; the change would route to the blocked outcome permanently"
  fi

  # The blockedReasons shape §4 constrains and the shape §9 produces are the same shape, stated
  # on one line so the two halves cannot drift apart across a paragraph.
  if ! printf '%s\n' "$sec9" | grep -F 'blockedReasons' | grep -qi 'artifact type'; then
    fail "§9's STOP entries do not name a registered artifact type; §4 requires that of every blockedReasons entry, so the STOP's own entries would violate it"
  fi

  # Registered types belong in the §4 map; this record is deliberately not one of them, and §5
  # forbids anything else appearing there.
  if printf '%s\n' "$sec4" | sed -n '/^artifacts:$/,/^artifactRefs:$/p' | grep -qF "$stop_type"; then
    fail "§4's artifacts map carries $stop_type; the STOP record is not a registered artifact type and §5 forbids it in the map"
  fi

  # The actor that produces a STOP is the actor that has to write it down.
  if [ -n "$gate" ] && ! printf '%s\n' "$gate" | grep -qF "$stop_type"; then
    fail "the $GATE_HEADING section never writes the $stop_type record; the canon would define a recording site nothing records to"
  fi
fi

# A25 — cycle state is reconstructed, never recalled, and the prose the orchestrator used to
# hold in its own context window is gone.
if [ -z "$cycle" ]; then
  fail "$ORCHESTRATOR has no \"$CYCLE_HEADING\" section; cycle state has no definition site to cite"
else
  if ! printf '%s\n' "$cycle" | grep -qF "$CONTRACT"; then
    fail "the $CYCLE_HEADING section does not cite $CONTRACT by path"
  fi
  # Not a fixed string: /sdd-status is a substring of the contract's own file name, so a plain
  # search here is answered by the path citation on the line above.
  if ! printf '%s\n' "$cycle" | grep -qE '(^|[^A-Za-z0-9_-])/sdd-status'; then
    fail "the $CYCLE_HEADING section does not name /sdd-status as the way to recover cycle state"
  fi
  if ! printf '%s\n' "$cycle" | grep -qiE 'never recall|not a source of state'; then
    fail "the $CYCLE_HEADING section does not forbid recalling cycle state from context"
  fi
fi

if grep -qxF "$LEGACY_STATE" "$ORCHESTRATOR"; then
  fail "$ORCHESTRATOR still carries its \"$LEGACY_STATE\" section; cycle state is the §4 projection, not prose held in context"
fi

for bullet in 'Which artifacts exist' 'Which tasks are complete' 'Review: tier, ledger ref' 'Any issues or blockers reported'; do
  if grep -qF "$bullet" "$ORCHESTRATOR"; then
    fail "$ORCHESTRATOR still instructs tracking \"$bullet\" in its own context; that state is reconstructed by /sdd-status"
  fi
done

# A26 — the archive knows how to merge a delta spec into the main specs in the engram store,
# with the topic forms read out of the artifact-type registry.
topic_prefix="$(grep -oE 'sdd/\{change-name\}/\{artifact-type\}' "$CONVENTION" | head -1 | sed 's/{artifact-type}//' || true)"
main_spec_topic="$(grep -F 'Main specs' "$CONVENTION" | grep -oE '`sdd/[^`]*`' | head -1 | tr -d '`' || true)"

if [ -z "$topic_prefix" ] || [ -z "$main_spec_topic" ]; then
  fail "$CONVENTION no longer yields the change-scoped topic form or the main-spec topic form; the archive sync check would pass vacuously"
else
  step1="$(awk '/^### Step 1:/ { f = 1; next } f && /^### / { exit } f' "$ARCHIVE_SKILL")"
  if [ -z "$step1" ]; then
    fail "$ARCHIVE_SKILL has no \"### Step 1:\" section; the spec sync has no home"
  else
    if ! printf '%s\n' "$step1" | grep -qF '`engram`'; then
      fail "$ARCHIVE_SKILL Step 1 has no \`engram\` branch; it syncs specs for filesystem paths only"
    fi
    # Every clause below reads the engram branch alone. Scanning the whole step would let the
    # filesystem branch's own merge rules answer for rules the engram branch never states.
    step1="$(printf '%s\n' "$step1" | awk '/^#### / { f = ($0 ~ /`engram`/) } f')"
    if ! printf '%s\n' "$step1" | grep -qF "${topic_prefix}spec"; then
      fail "$ARCHIVE_SKILL Step 1 does not name the delta source topic ${topic_prefix}spec"
    fi
    if ! printf '%s\n' "$step1" | grep -qF "$main_spec_topic"; then
      fail "$ARCHIVE_SKILL Step 1 does not name the main-spec destination topic $main_spec_topic"
    fi
    for rule in ADDED MODIFIED REMOVED; do
      if ! printf '%s\n' "$step1" | grep -qF "$rule"; then
        fail "$ARCHIVE_SKILL Step 1's merge rules omit $rule"
      fi
    done
    if ! printf '%s\n' "$step1" | grep -qi 'one upsert per domain'; then
      fail "$ARCHIVE_SKILL Step 1 does not require one upsert per domain"
    fi
    if ! printf '%s\n' "$step1" | grep -qi 'domain header'; then
      fail "$ARCHIVE_SKILL Step 1 does not split a multi-domain delta on its domain headers"
    fi
    if ! printf '%s\n' "$step1" | grep -qiE 'preserv'; then
      fail "$ARCHIVE_SKILL Step 1 does not preserve the requirements a delta never mentions"
    fi
  fi
fi

# A27 — the README is the plugin's only user-facing surface, and every count in it is compared
# against the tree instead of against a literal. A hardcoded expectation would go stale the next
# time an agent or a command is added, which is the drift that left it advertising eight agents.
if [ ! -f "$README" ]; then
  fail "$README is missing; the plugin has no user-facing description to check"
else
  # `self-policing` is A24's clause above, so the four remaining literals are checked here.
  for literal in 'gentle-ai' 'MIT' 'phase-validator'; do
    if ! grep -qF "$literal" "$README"; then
      fail "$README does not name \"$literal\"; the reader learns nothing about it from the plugin's front page"
    fi
  done

  # Not a fixed string: /sdd-status is a substring of sdd-status-contract.md, so a plain search
  # here would be answered by any line that merely cites the contract by path.
  if ! grep -qE '(^|[^A-Za-z0-9_-])/sdd-status' "$README"; then
    fail "$README does not name /sdd-status; the one command this change adds is undocumented"
  fi

  agent_files="$(find agents -maxdepth 1 -name '*.md' -exec basename {} .md \; 2>/dev/null | sort -u || true)"
  agent_file_count="$(printf '%s\n' "$agent_files" | grep -c . || true)"
  agent_rows="$(
    heading_body "$README" '## Agents' |
      grep -oE '^\| `[a-z][a-z0-9-]*`' |
      grep -oE '`[a-z][a-z0-9-]*`' |
      tr -d '`' |
      sort -u || true
  )"

  if [ "$agent_file_count" -eq 0 ]; then
    fail "agents/ yielded no agent files; the README's agent roster would be compared against nothing"
  elif [ -z "$agent_rows" ]; then
    fail "$README's \"## Agents\" table yielded no rows; the heading or the table moved and the agent roster check would pass vacuously"
  else
    undocumented="$(comm -23 <(printf '%s\n' "$agent_files") <(printf '%s\n' "$agent_rows") | tr '\n' ' ' | sed 's/ *$//;s/ /, /g')"
    phantom="$(comm -13 <(printf '%s\n' "$agent_files") <(printf '%s\n' "$agent_rows") | tr '\n' ' ' | sed 's/ *$//;s/ /, /g')"
    if [ -n "$undocumented" ] || [ -n "$phantom" ]; then
      fail "$README's agents table has drifted from agents/: undocumented: ${undocumented:-none}; not on disk: ${phantom:-none}"
    fi
  fi

  # The advertised number is a second copy of the same fact, so it is compared with the directory
  # rather than with the table it sits above.
  claimed_agents="$(grep -oE 'ships [0-9]+ dedicated agents' "$README" | grep -oE '[0-9]+' | head -1 || true)"
  if [ -z "$claimed_agents" ]; then
    fail "$README never states how many dedicated agents it ships; there is no count to compare with agents/"
  elif [ "$claimed_agents" -ne "$agent_file_count" ]; then
    fail "$README advertises $claimed_agents dedicated agents; agents/ holds $agent_file_count"
  fi

  command_files="$(find commands -maxdepth 1 -name '*.md' -exec basename {} .md \; 2>/dev/null | sed 's|^|/|' | sort -u || true)"
  command_file_count="$(printf '%s\n' "$command_files" | grep -c . || true)"
  readme_commands="$(
    heading_body "$README" '## Commands' |
      grep -oE '^\| `/sdd-[a-z-]+' |
      grep -oE '/sdd-[a-z-]+' |
      sort -u || true
  )"

  if [ "$command_file_count" -eq 0 ]; then
    fail "commands/ yielded no command files; the README's roster would be compared against nothing"
  elif [ -z "$readme_commands" ]; then
    fail "$README's \"## Commands\" table yielded no rows; the roster it is supposed to document is absent or its heading moved"
  else
    unlisted="$(comm -23 <(printf '%s\n' "$command_files") <(printf '%s\n' "$readme_commands") | tr '\n' ' ' | sed 's/ *$//;s/ /, /g')"
    invented="$(comm -13 <(printf '%s\n' "$command_files") <(printf '%s\n' "$readme_commands") | tr '\n' ' ' | sed 's/ *$//;s/ /, /g')"
    if [ -n "$unlisted" ] || [ -n "$invented" ]; then
      fail "$README's commands table has drifted from commands/: unlisted: ${unlisted:-none}; not on disk: ${invented:-none}"
    fi
  fi

  attribution="$(heading_body "$README" '## Attribution')"
  if [ -z "$attribution" ]; then
    fail "$README has no \"## Attribution\" section; the gentle-ai credit has no home"
  else
    for credited in 'review' 'status contract' 'gatekeeper'; do
      if ! printf '%s\n' "$attribution" | grep -qiF "$credited"; then
        fail "$README's \"## Attribution\" section does not credit gentle-ai for the $credited; this change adapted more than the review system"
      fi
    done
    if ! printf '%s\n' "$attribution" | grep -qiF 'partial'; then
      fail "$README's \"## Attribution\" section does not say the port is partial; the part of gentle-ai's contract that needs its Go binary is deliberately absent"
    fi
  fi
fi

# A28 — one release, one version. Both manifests carry the number and v1.2.0 shipped with
# marketplace.json left behind, so the value is asserted in each file rather than compared
# between them: two files agreeing on the wrong number is still a mis-release.
PLUGIN_MANIFEST=.claude-plugin/plugin.json
MARKETPLACE_MANIFEST=.claude-plugin/marketplace.json
# The only expectation in this script that is not extracted from the tree, because no file can be
# its own source of truth for the number it is being bumped to. It moves with the next release.
TARGET_VERSION=1.3.0

for f in "$PLUGIN_MANIFEST" "$MARKETPLACE_MANIFEST"; do
  if [ ! -f "$f" ]; then
    fail "$f is missing; the release has no version to check"
    continue
  fi
  declared="$(grep -oE '"version"[[:space:]]*:[[:space:]]*"[^"]*"' "$f" | sed -E 's/.*"([^"]*)"$/\1/' | sort -u || true)"
  declared_count="$(printf '%s\n' "$declared" | grep -c . || true)"
  if [ "$declared_count" -ne 1 ]; then
    fail "$f declares $declared_count distinct version fields; exactly one is expected and the release version would be ambiguous"
  elif [ "$declared" != "$TARGET_VERSION" ]; then
    fail "$f is at version $declared; this release is $TARGET_VERSION and both manifests move together"
  fi
done

report

echo "check-envelope: OK — canon complete, $token_count tokens extracted, single definition site, $site_count sites cite it, standard guard in $executor_count"
