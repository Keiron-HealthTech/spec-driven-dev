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

# A16 — the routing decision is a table with an order, not a judgment call.
derivation="$(printf '%s\n' "$sec4" | awk '/^### / { f = ($0 ~ /derivation/) } f')"
if [ -z "$derivation" ]; then
  fail "§4 has no nextRecommended derivation subsection"
else
  if ! printf '%s\n' "$derivation" | grep -qiE 'first match|first-match'; then
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

report

echo "check-envelope: OK — canon complete, $token_count tokens extracted, single definition site, $site_count sites cite it"
