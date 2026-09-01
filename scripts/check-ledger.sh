#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

LEDGER=skills/_shared/review-ledger-contract.md
STATUS=skills/_shared/sdd-status-contract.md
ARCHIVE_SKILL=skills/sdd-archive/SKILL.md
REVIEW_SKILL=skills/sdd-review/SKILL.md
ORCHESTRATOR=skills/sdd-orchestrator/SKILL.md
README=README.md

# Every expected value is extracted from the canon at runtime. Nothing here hardcodes a set
# that could drift from the contract it guards.

# Failures accumulate instead of exiting at the first one, so a single run names every violated
# clause. The one exception is the vacuity guard below: every clause after it reads the set it
# extracts, so a broken extraction there has to stop the run instead of silencing the rest.
FAILURES=""

fail() {
  FAILURES="${FAILURES}${FAILURES:+$'\n'}$1"
}

report() {
  if [ -n "$FAILURES" ]; then
    echo "check-ledger: FAIL — $(printf '%s\n' "$FAILURES" | head -1)" >&2
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

member() { # value, newline-separated set
  printf '%s\n' "$2" | grep -qxF "$1"
}

# Reflow-proof bullet extraction: join a bullet with its indented continuation lines and
# squeeze whitespace, so a comparison against the joined body does not depend on where the
# canon happens to wrap. The keyword is tested BEFORE the squeeze, so a finder phrase must lie
# wholly within one physical line; a reflow that splits one empties the extraction, which the
# per-clause emptiness guards turn into a loud failure rather than a silent pass.
bullet_body() { # keyword on $1; body on stdin
  awk -v kw="$1" '
    function flush() { if (buf != "" && index(buf, kw) > 0) print buf; buf = "" }
    /^- / { flush(); buf = $0; next }
    /^[[:space:]]/ && buf != "" { buf = buf " " $0; next }
    { flush() }
    END { flush() }
  ' | tr -s " "
}

tokens() { grep -oE '`[a-z][a-z-]*`' | tr -d '`' | sort -u; }

if [ ! -f "$LEDGER" ]; then
  fail "$LEDGER is missing; there is no review canon to check"
  report
fi

sec2="$(section "$LEDGER" 2)"
sec5="$(section "$LEDGER" 5)"
sec7="$(section "$LEDGER" 7)"
sec9="$(section "$LEDGER" 9)"
sec11="$(section "$LEDGER" 11)"
status5="$(section "$STATUS" 5)"

# L1 — vacuity guard. The floor is a floor, not a count: an eighth status value added later is
# legal, and an exact count would be a second copy of the enum's size. Reported immediately
# because every clause below reads $enum.
# The two anchors are the `## 2.` section NUMBER and the '`status` — one of' lead-in. The
# heading's title is not one of them: retitling the section leaves the extraction intact,
# renumbering it empties the extraction.
enum="$(
  printf '%s\n' "$sec2" |
    grep -F '`status` — one of' |
    sed -E 's/.*one of `([^`]*)`.*/\1/' |
    tr '|' '\n' |
    tr -d ' ' |
    grep -E '^[a-z-]+$' |
    sort -u || true
)"
enum_count="$(printf '%s' "$enum" | grep -c . || true)"
enum_list="$(printf '%s' "$enum" | tr '\n' ' ' | sed 's/ *$//')"

if [ "$enum_count" -lt 6 ]; then
  fail "§2's status enum extraction yielded $enum_count values, below the floor of 6; the \`## 2.\` section number or the \"\`status\` — one of\" lead-in moved, and every clause below would read an empty set and pass vacuously"
  report
fi

# L2 — the seventh value exists where the schema is defined. §9 and §11 name statuses; only §2
# declares them, so a state defined anywhere else is not in the enum.
if ! member deferred "$enum"; then
  fail "§2's status enum does not carry \`deferred\` (extracted: $enum_list); the schema bullet is the enum's only definition site"
fi

# L3 — the definition site carries the transition. §2 declares a status; §9's arrow block is
# where it becomes reachable. The shape is pinned to the start of a line inside the fenced
# block, which no paragraph about deferring findings can produce.
arrow_count="$(printf '%s\n' "$sec9" | grep -cE '^open +→ +deferred' || true)"

if [ "$arrow_count" -ne 1 ]; then
  fail "§9's transition block carries $arrow_count \`open → deferred\` rows, expected exactly 1; a value in §2's enum with no transition in §9 is declared but never defined"
fi

# L4, L5 and L6 all read one bullet — §9's `deferred` rule — located by its own opening words,
# so prose elsewhere in the section cannot answer for it.
deferred_rule="$(printf '%s\n' "$sec9" | bullet_body '`deferred` REQUIRES' || true)"

if [ -z "$deferred_rule" ]; then
  fail "§9 carries no bullet opening \"\`deferred\` REQUIRES\"; the state has no evidence form, no mandatory destination and no user-only clause for L4, L5 and L6 to read"
else
  # L4 — the form is exact. A row can only be checked against a form that is stated literally.
  for literal in 'user decision' 'YYYY-MM-DD' 'deferred — user decision (YYYY-MM-DD)'; do
    if ! printf '%s\n' "$deferred_rule" | grep -qF "$literal"; then
      fail "§9's \`deferred\` evidence form does not carry the literal \"$literal\"; a paraphrase of a form is not a form"
    fi
  done

  # L5 — the mandatory destination is the only structural difference from `wont-fix`, so it is
  # the one thing required rather than recommended. This defends the PRESENCE of that rule and
  # never its strength: a reword keeping all three words while weakening the rule still passes.
  for literal in destination MANDATORY tracker-agnostic; do
    if ! printf '%s\n' "$deferred_rule" | grep -qF "$literal"; then
      fail "§9's \`deferred\` rule does not carry \"$literal\"; without it the destination is a suggestion and \`deferred\` is \`wont-fix\` under a longer name"
    fi
  done

  # L6 — user-only, in the wording `wont-fix` already uses, so drift in one twin shows against
  # the other.
  for literal in 'NEVER sets deferred on its own' 'only the user authorizes'; do
    if ! printf '%s\n' "$deferred_rule" | grep -qF "$literal"; then
      fail "§9's \`deferred\` rule does not state \"$literal\"; a status an agent may assign itself is not a user decision"
    fi
  done
fi

# L7 — §9 defines the closed states, §11 states the archive pass set, and the two are one set or
# CI says which value differs. Both sides are token sets computed from the two normative
# bullets, so no wording can make two different sets equal. The floor of 3 is a floor: it stops
# an emptied extraction from reaching `comm`, where an empty side names every value as drift.
closed9="$(printf '%s\n' "$sec9" | bullet_body 'only CLOSED states' | tokens || true)"
pass11="$(printf '%s\n' "$sec11" | bullet_body 'archive pass set' | tokens || true)"
closed9_count="$(printf '%s' "$closed9" | grep -c . || true)"
pass11_count="$(printf '%s' "$pass11" | grep -c . || true)"

if [ "$closed9_count" -lt 3 ]; then
  fail "§9's closed-state bullet extracted $closed9_count values, below the floor of 3; the bullet naming \"only CLOSED states\" moved or reflowed, so §9 no longer states the set §11 claims to copy"
fi

if [ "$pass11_count" -lt 3 ]; then
  fail "§11's \"archive pass set\" bullet extracted $pass11_count values, below the floor of 3; neither §9's closed set nor $ARCHIVE_SKILL's mirror has anything left to be compared against"
fi

if [ "$closed9_count" -ge 3 ] && [ "$pass11_count" -ge 3 ]; then
  only_closed9="$(comm -23 <(printf '%s\n' "$closed9") <(printf '%s\n' "$pass11") | tr '\n' ' ' | sed 's/ *$//;s/ /, /g')"
  only_pass11="$(comm -13 <(printf '%s\n' "$closed9") <(printf '%s\n' "$pass11") | tr '\n' ' ' | sed 's/ *$//;s/ /, /g')"

  if [ -n "$only_closed9" ] || [ -n "$only_pass11" ]; then
    fail "§9's closed states and §11's archive pass set disagree: only in §9: ${only_closed9:-none}; only in §11: ${only_pass11:-none}"
  fi
fi

# L2, second half — every value the archive gate lets through has to be a declared status. The
# membership half above catches `deferred` dropped from §2 while §9 still names it; this half
# catches the same drift from the other side, and it needs the pass set, so it sits after L7.
if [ "$pass11_count" -ge 3 ]; then
  while IFS= read -r pass_value; do
    if [ -z "$pass_value" ]; then
      continue
    fi
    if ! member "$pass_value" "$enum"; then
      fail "§11's archive pass set carries \`$pass_value\`, which is not in §2's status enum (extracted: $enum_list); the gate would pass a status the schema never declared"
    fi
  done <<EOF
$pass11
EOF
fi

# L8 — sdd-archive Step 0's pass set is a MIRROR of §11 and CI asserts the two set-equal. The
# label makes the bullet findable; the set comparison is the assertion.
step0="$(awk '/^### Step 0/ { f = 1; next } f && /^### / { exit } f' "$ARCHIVE_SKILL")"

if [ -z "$step0" ]; then
  fail "$ARCHIVE_SKILL has no \"### Step 0\" section; the archive gate's mirror has no home"
fi

arch_set="$(printf '%s\n' "$step0" | bullet_body 'MIRROR' | tokens || true)"

if [ -z "$arch_set" ]; then
  fail "$ARCHIVE_SKILL Step 0 carries no MIRROR-labelled pass-set bullet; L8's set comparison has nothing to read"
fi

if [ "$pass11_count" -ge 3 ] && [ -n "$arch_set" ]; then
  only_11="$(comm -23 <(printf '%s\n' "$pass11") <(printf '%s\n' "$arch_set") | tr '\n' ' ' | sed 's/ *$//;s/ /, /g')"
  only_arch="$(comm -13 <(printf '%s\n' "$pass11") <(printf '%s\n' "$arch_set") | tr '\n' ' ' | sed 's/ *$//;s/ /, /g')"

  if [ -n "$only_11" ] || [ -n "$only_arch" ]; then
    fail "pass-set drift between §11 and $ARCHIVE_SKILL Step 0: only in §11: ${only_11:-none}; only in the mirror: ${only_arch:-none}"
  fi

  mirror_bullet="$(printf '%s\n' "$step0" | bullet_body 'MIRROR' || true)"
  if ! printf '%s\n' "$mirror_bullet" | grep -qF 'review-ledger-contract.md'; then
    fail "$ARCHIVE_SKILL Step 0's mirror bullet does not name review-ledger-contract.md; a mirror that does not say what it mirrors reads as an independent statement"
  fi
  if ! printf '%s\n' "$mirror_bullet" | grep -qF '§11'; then
    fail "$ARCHIVE_SKILL Step 0's mirror bullet does not cite §11; the section it mirrors has to be named for a reader to resolve the copy"
  fi
fi

# L9 — sdd-review's `REVIEW: RESOLVED` row is the second mirror of §11, and CI asserts the two
# set-equal. Line-scoping is legitimate here and only here: a markdown table row is one line by
# construction, so no reflow can split it. The MIRROR label makes the row findable; the set
# comparison is the assertion, so a reworded label empties the extraction and hits the guard
# rather than turning the clause green.
rev_set="$(grep -F 'REVIEW: RESOLVED' "$REVIEW_SKILL" | grep -F 'MIRROR' | tokens || true)"

if [ -z "$rev_set" ]; then
  fail "$REVIEW_SKILL carries no MIRROR-labelled \`REVIEW: RESOLVED\` row; the second copy of the pass set is unasserted, and defending one copy while stranding the other is the partial fix that reads as complete"
fi

if [ "$pass11_count" -ge 3 ] && [ -n "$rev_set" ]; then
  only_11_rev="$(comm -23 <(printf '%s\n' "$pass11") <(printf '%s\n' "$rev_set") | tr '\n' ' ' | sed 's/ *$//;s/ /, /g')"
  only_rev="$(comm -13 <(printf '%s\n' "$pass11") <(printf '%s\n' "$rev_set") | tr '\n' ' ' | sed 's/ *$//;s/ /, /g')"

  if [ -n "$only_11_rev" ] || [ -n "$only_rev" ]; then
    fail "pass-set drift between §11 and $REVIEW_SKILL's \`REVIEW: RESOLVED\` row: only in §11: ${only_11_rev:-none}; only in the mirror: ${only_rev:-none}"
  fi

  if ! grep -F 'REVIEW: RESOLVED' "$REVIEW_SKILL" | grep -F 'MIRROR' | grep -qF '§11'; then
    fail "$REVIEW_SKILL's \`REVIEW: RESOLVED\` row is labelled a MIRROR without citing §11; the section it mirrors has to be named for a reader to resolve the copy"
  fi
fi

# L10 — the audited dead end. A deferred row is never cleared inside the change that defers it, so
# the archive report IS the entire record that the obligation exists: Step 0 has to list those rows
# and the report template has to carry a field for them. `**Deferred rows**` is a template field,
# not prose — a paragraph about auditing deferrals cannot produce it.
audit_bullet="$(printf '%s\n' "$step0" | bullet_body 'Audit trail' || true)"
template_field="$(grep -F '**Deferred rows**' "$ARCHIVE_SKILL" || true)"

if [ -z "$audit_bullet" ]; then
  fail "$ARCHIVE_SKILL Step 0 carries no \"Audit trail\" bullet; the rows the gate lets through unfixed would leave no trail at all"
elif ! printf '%s\n' "$audit_bullet" | grep -qF 'deferred'; then
  fail "$ARCHIVE_SKILL Step 0's audit-trail bullet does not list \`deferred\` rows; a closed state with no audit trail is a finding that disappears"
fi

if [ -z "$template_field" ]; then
  fail "$ARCHIVE_SKILL's archive-report template carries no \`**Deferred rows**\` field; the audit-trail rule has nowhere to be written down, and nothing in v1.4.0 clears a deferred row later"
fi

if ! printf '%s\n%s\n' "$audit_bullet" "$template_field" | grep -qF 'destination'; then
  fail "neither $ARCHIVE_SKILL Step 0's audit-trail bullet nor its \`**Deferred rows**\` template field names the destination; a trail recording that work was deferred but not where it went is not a trail"
fi

# L12 — the report's own counters. Every closed state the gate accepts has to be countable in the
# review report, plus `open`. SUPERSET and not equality on purpose: the line legitimately also
# counts `open`, and its omission of `fixed` — never a closed state — stays legal, because forcing
# `fixed` in would smuggle an unrelated behaviour change into this one. The anchor is the Return
# template's field label, the thing the coordinator fills in rather than an explanation of it.
buckets="$(grep -F '**Findings**:' "$REVIEW_SKILL" || true)"

if [ -z "$buckets" ]; then
  fail "$REVIEW_SKILL has no \`**Findings**:\` bucket line; the review report has no counters for the pass set to be compared against"
elif [ "$pass11_count" -ge 3 ]; then
  while IFS= read -r bucket_value; do
    if [ -z "$bucket_value" ]; then
      continue
    fi
    if ! printf '%s\n' "$buckets" | grep -qF "$bucket_value"; then
      fail "$REVIEW_SKILL's \`**Findings**:\` line does not count \`$bucket_value\`; a status the archive gate accepts that the report never counts is a row the user never sees"
    fi
  done <<EOF
$pass11
open
EOF
fi

# L13 — the user-facing surface. The honest limit is stated here rather than assumed: this is a
# documentation-PRESENCE clause, never a correctness one, and a wrong paraphrase passes it. The
# README is deliberately not a second definition site — asserting set equality here would create a
# further copy of the pass set in the one file the project has kept free of canon.
readme_body="$(awk '$0 == "## Review Workflow" { f = 1; next } f && /^## / { exit } f' "$README" || true)"

if [ -z "$readme_body" ]; then
  fail "$README has no \"## Review Workflow\" section; the user-facing description of the review system moved and L13 has nothing to read"
else
  for literal in deferred destination; do
    if ! printf '%s\n' "$readme_body" | grep -qF "$literal"; then
      fail "$README's Review Workflow section never mentions \"$literal\"; a user reading only the README cannot learn that routing a severe finding elsewhere is expressible"
    fi
  done
fi

# L16 — ledger finding L-014. Step 0 cites two different contracts, so a sub-agent that cannot open
# either resolves a bare "contract §11" by guessing, and both mis-resolutions read plausible. Every
# § citation in the section must name the file it means. Citations are compared per LOGICAL UNIT —
# a line joined with its indented continuations — so a wrapped filename does not turn CI red;
# pinning two halves of one statement to a single physical line is the idiom A32 corrected.
step0_units="$(
  printf '%s\n' "$step0" |
    awk '
      function flush() { if (buf != "") print buf; buf = "" }
      /^[[:space:]]*$/ { flush(); next }
      /^[[:space:]]/ && buf != "" { buf = buf " " $0; next }
      { flush(); buf = $0 }
      END { flush() }
    ' |
    tr -s " " || true
)"
step0_cites="$(printf '%s\n' "$step0_units" | grep -F '§' || true)"

while IFS= read -r cite_unit; do
  if [ -z "$cite_unit" ]; then
    continue
  fi
  if ! printf '%s\n' "$cite_unit" | grep -qF 'review-ledger-contract.md'; then
    fail "$ARCHIVE_SKILL Step 0 cites a § without naming the contract it means: \"$cite_unit\""
  fi
done <<EOF
$step0_cites
EOF

# L17 — the cross-canon join. sdd-status-contract.md §5 asks §9 for the end states under one
# word and restates nothing, so the citation graph runs one way: status → review. This clause
# reads that word out of the status canon and asserts §9 still defines a set under it. Renaming
# §9's union silently reverts the defect where a ledger holding a `verified` row stayed
# `partial` forever. sdd-status-contract.md takes no edit for this; it is read, never written.
union_word="$(printf '%s\n' "$status5" | grep -F '| `review-ledger` |' | grep -F 'review-ledger-contract.md' | sed -nE 's/.*not in an? ([a-z-]+) state.*/\1/p' || true)"
union_word_count="$(printf '%s' "$union_word" | grep -c . || true)"

if [ "$union_word_count" -ne 1 ]; then
  fail "$STATUS §5's \`review-ledger\` row yielded $union_word_count union words, expected exactly 1; the status canon moved and L17 would pass vacuously against whatever §9 happens to say"
else
  union_bullet="$(printf '%s\n' "$sec9" | tr 'A-Z' 'a-z' | bullet_body "$union_word states are" || true)"

  if [ -z "$union_bullet" ]; then
    fail "§9 defines no set under the word $STATUS §5 cites ($union_word); a consumer resolving that citation gets nothing back, so the countable signal for review-ledger cannot be derived"
  else
    for literal in info closed union; do
      if ! printf '%s\n' "$union_bullet" | grep -qF "$literal"; then
        fail "§9's $union_word bullet does not name \"$literal\"; the union and the BLOCKER/CRITICAL gate set have to be distinguished where they are defined, or a reader cannot tell which one $STATUS §5 is asking for"
      fi
    done
  fi
fi

# L18 — the checkability caveat, and the reason it needs a clause at all. The scenario asking for
# it is labelled [CI] while nothing in this script read it: a row measured as though a checker
# defended it is exactly the debt the previous cycle paid for. The four literals must co-occur in
# ONE bullet of §11, found by the caveat's own opening words, so they cannot be satisfied by
# scattering the elements across the section and no gloss outside §11 can answer for them.
caveat="$(printf '%s\n' "$sec11" | bullet_body 'No check can validate' || true)"

if [ -z "$caveat" ]; then
  fail "§11 carries no bullet opening \"No check can validate\"; the canon does not say what \"mechanically checkable\" means here, so every clause in this script reads as a test of a real ledger row"
else
  for literal in 'real ledger row' "user's own project" 'checkers run over the plugin repo' 'A mandated form is never a validated row'; do
    if ! printf '%s\n' "$caveat" | grep -qF "$literal"; then
      fail "§11's checkability caveat does not carry the literal \"$literal\"; without it the canon claims a coverage no checker in this repository can deliver"
    fi
  done
fi

report

echo "check-ledger: OK — ledger canon complete, $enum_count status values extracted, pass set agrees across §9, §11 and both mirrors"
