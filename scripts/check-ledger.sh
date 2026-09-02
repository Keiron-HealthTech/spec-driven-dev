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

# bullet_body and para_body print ONE LINE PER MATCHED UNIT, so the line count of an extraction is
# the number of units its finder matched. A plain line grep is the same shape with the unit fixed at
# one physical line: one line by construction is not one line MATCHED, so those extractions are
# counted here too. Anything above one has to fail rather than be absorbed:
# every clause here then greps or tokenises the joined output, so two matched units mean a
# containment test passes on either one — a normative unit that lost its required literal is
# answered by a commentary unit that happens to carry it — and a set extraction silently unions
# both. Every extraction below is guarded on this count as well as on emptiness.
unit_count() { printf '%s' "$1" | grep -c . || true; }

# One shared tail, because the reason is the same at every site and a failure message has to stay
# a single line or `report` splits it across two "also:" prefixes.
MULTI_TAIL="the finder matches more than one unit and the joined text is what every comparison reads, so a unit that lost its required text is answered by the other one's copy"

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
# The lead-in is matched per line and the values are unioned, so the multiplicity guard below is
# what keeps the extraction sound: a second lead-in line inside §2 would put values in $enum that
# the schema bullet no longer declares. L20 is not that defence — its first half counts FILES and
# its second excludes $LEDGER, so both halves are blind to a second lead-in inside the canon.
enum_lead="$(printf '%s\n' "$sec2" | grep -F '`status` — one of' || true)"
enum_lead_n="$(unit_count "$enum_lead")"
enum="$(
  printf '%s\n' "$enum_lead" |
    sed -E 's/.*one of `([^`]*)`.*/\1/' |
    tr '|' '\n' |
    tr -d ' ' |
    grep -E '^[a-z-]+$' |
    sort -u || true
)"
enum_count="$(printf '%s' "$enum" | grep -c . || true)"
enum_list="$(printf '%s' "$enum" | tr '\n' ' ' | sed 's/ *$//')"

if [ "$enum_lead_n" -gt 1 ]; then
  fail "§2 carries $enum_lead_n lines matching \"\`status\` — one of\", expected exactly 1; $MULTI_TAIL. The values are unioned across matching lines, so the schema bullet can stop declaring a status while \$enum still reports it — and \$enum is the set L1's floor, L2's membership half and L2's subset half all read"
  report
fi

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
deferred_rule_n="$(unit_count "$deferred_rule")"

if [ "$deferred_rule_n" -eq 0 ]; then
  fail "§9 carries no bullet opening \"\`deferred\` REQUIRES\"; the state has no evidence form, no mandatory destination and no user-only clause for L4, L5 and L6 to read"
elif [ "$deferred_rule_n" -gt 1 ]; then
  fail "§9 carries $deferred_rule_n bullets matching \"\`deferred\` REQUIRES\", expected exactly 1; $MULTI_TAIL. L4, L5, L6 and L21 would be reading a normative rule and a gloss of it as one text"
else
  # L4 — the form is exact, to its END. A row can only be checked against a form that is stated
  # literally. The last literal is the WHOLE form and REPLACES the prefix this clause used to stop
  # at: `deferred — user decision (YYYY-MM-DD)` is a substring of it, so keeping both covered
  # nothing extra and reported one defect as two findings. Stopping at the date left the
  # `: {destination}: {reason}` tail — the segment L5 calls the only structural difference from
  # `wont-fix` — asserted nowhere, so §9 could state a form the destination never reached while L5
  # stayed satisfied by the prose beside it. L24 compares the mirror against this same whole form.
  for literal in 'user decision' 'YYYY-MM-DD' 'deferred — user decision (YYYY-MM-DD): {destination}: {reason}'; do
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
closed9_bullet="$(printf '%s\n' "$sec9" | bullet_body 'only CLOSED states' || true)"
pass11_bullet="$(printf '%s\n' "$sec11" | bullet_body 'archive pass set' || true)"
closed9_n="$(unit_count "$closed9_bullet")"
pass11_n="$(unit_count "$pass11_bullet")"
closed9="$(printf '%s\n' "$closed9_bullet" | tokens || true)"
pass11="$(printf '%s\n' "$pass11_bullet" | tokens || true)"
closed9_count="$(printf '%s' "$closed9" | grep -c . || true)"
pass11_count="$(printf '%s' "$pass11" | grep -c . || true)"
closed9_list="$(printf '%s' "$closed9" | tr '\n' ' ' | sed 's/ *$//')"

# A unioned set is worse than an empty one: it compares as drift and the message blames the wrong
# side. So the count is zeroed after the multiplicity failure, which is what every clause below is
# already gated on, and the run reports the multiplicity once instead of a downstream consequence.
if [ "$closed9_n" -gt 1 ]; then
  fail "§9 carries $closed9_n bullets matching \"only CLOSED states\", expected exactly 1; $MULTI_TAIL. A unioned closed set is what L7 would then compare against §11"
  closed9_count=0
elif [ "$closed9_count" -lt 3 ]; then
  fail "§9's closed-state bullet extracted $closed9_count values, below the floor of 3; the bullet naming \"only CLOSED states\" moved or reflowed, so §9 no longer states the set §11 claims to copy"
fi

if [ "$pass11_n" -gt 1 ]; then
  fail "§11 carries $pass11_n bullets matching \"archive pass set\", expected exactly 1; $MULTI_TAIL. The pass set is the reference L2, L7, L8, L9, L12 and L19 all read"
  pass11_count=0
elif [ "$pass11_count" -lt 3 ]; then
  fail "§11's \"archive pass set\" bullet extracted $pass11_count values, below the floor of 3; neither §9's closed set nor $ARCHIVE_SKILL's mirror has anything left to be compared against"
fi

if [ "$closed9_count" -ge 3 ] && [ "$pass11_count" -ge 3 ]; then
  only_closed9="$(comm -23 <(printf '%s\n' "$closed9") <(printf '%s\n' "$pass11") | tr '\n' ' ' | sed 's/ *$//;s/ /, /g')"
  only_pass11="$(comm -13 <(printf '%s\n' "$closed9") <(printf '%s\n' "$pass11") | tr '\n' ' ' | sed 's/ *$//;s/ /, /g')"

  if [ -n "$only_closed9" ] || [ -n "$only_pass11" ]; then
    fail "§9's closed states and §11's archive pass set disagree: only in §9: ${only_closed9:-none}; only in §11: ${only_pass11:-none}"
  fi
fi

# L7, membership half. Set equality alone lets §9, §11 and both mirrors drop the SAME value together
# and stay equal — the residual L14 closes the same way for its menu. `deferred` is the state this
# change adds, so its membership is pinned where the closed set is DEFINED, exactly as L2 pins it in
# §2's enum and L14 pins `defer` in §9's decision menu. One membership test is the whole defence:
# §11 inherits the pin through L7's equality above, and both mirrors through L8's and L9's, so the
# other three values are compared and never listed. Deleting "evidenced `deferred`" from all four
# sites together left every set equal to a three-value set, and the run reported that the pass set
# agrees across §9, §11 and both mirrors.
if [ "$closed9_count" -ge 3 ] && ! member deferred "$closed9"; then
  fail "§9's closed-state bullet does not name \`deferred\` (extracted: $closed9_list); this is the closed set's definition site, and §11 and both mirrors comparing equal to a set that dropped it is four sites agreeing on the wrong set"
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
# The finder names the KIND of mirror, not the bare label: Step 0 holds two labelled copies — this
# pass set, and the `deferred` evidence rule L24 mirrors from §9 — and a bare `MIRROR` finder
# matches both, so this clause would fail on its own multiplicity guard the moment the second copy
# is labelled at all. A reworded label still empties the extraction and hits the guard below.
step0="$(awk '/^### Step 0/ { f = 1; next } f && /^### / { exit } f' "$ARCHIVE_SKILL")"

if [ -z "$step0" ]; then
  fail "$ARCHIVE_SKILL has no \"### Step 0\" section; the archive gate's mirror has no home"
fi

mirror_bullet="$(printf '%s\n' "$step0" | bullet_body 'inline set is a MIRROR' || true)"
mirror_bullet_n="$(unit_count "$mirror_bullet")"
arch_set="$(printf '%s\n' "$mirror_bullet" | tokens || true)"

if [ "$mirror_bullet_n" -gt 1 ]; then
  fail "$ARCHIVE_SKILL Step 0 carries $mirror_bullet_n bullets matching \"inline set is a MIRROR\", expected exactly 1; $MULTI_TAIL. Two mirrors in one section union into a pass set that matches neither"
  arch_set=""
elif [ -z "$arch_set" ]; then
  fail "$ARCHIVE_SKILL Step 0 carries no bullet labelled \"This inline set is a MIRROR\"; L8's set comparison has nothing to read"
fi

if [ "$pass11_count" -ge 3 ] && [ -n "$arch_set" ]; then
  only_11="$(comm -23 <(printf '%s\n' "$pass11") <(printf '%s\n' "$arch_set") | tr '\n' ' ' | sed 's/ *$//;s/ /, /g')"
  only_arch="$(comm -13 <(printf '%s\n' "$pass11") <(printf '%s\n' "$arch_set") | tr '\n' ' ' | sed 's/ *$//;s/ /, /g')"

  if [ -n "$only_11" ] || [ -n "$only_arch" ]; then
    fail "pass-set drift between §11 and $ARCHIVE_SKILL Step 0: only in §11: ${only_11:-none}; only in the mirror: ${only_arch:-none}"
  fi

  if ! printf '%s\n' "$mirror_bullet" | grep -qF 'review-ledger-contract.md'; then
    fail "$ARCHIVE_SKILL Step 0's mirror bullet does not name review-ledger-contract.md; a mirror that does not say what it mirrors reads as an independent statement"
  fi
  if ! printf '%s\n' "$mirror_bullet" | grep -qF '§11'; then
    fail "$ARCHIVE_SKILL Step 0's mirror bullet does not cite §11; the section it mirrors has to be named for a reader to resolve the copy"
  fi
fi

# L9 — sdd-review's `REVIEW: RESOLVED` row is the second mirror of §11, and CI asserts the two
# set-equal. Line-scoping is legitimate here and only here: a markdown table row is one line by
# construction, so no reflow can split it. That bounds the unit, not the number of them, so the row
# is counted as well: a second line carrying both labels unions into the set and restores a value
# the normative row dropped. The MIRROR label makes the row findable; the set comparison is the
# assertion, so a reworded label empties the extraction and hits the guard rather than turning the
# clause green.
rev_row="$(grep -F 'REVIEW: RESOLVED' "$REVIEW_SKILL" | grep -F 'MIRROR' || true)"
rev_row_n="$(unit_count "$rev_row")"
rev_set="$(printf '%s\n' "$rev_row" | tokens || true)"

if [ "$rev_row_n" -gt 1 ]; then
  fail "$REVIEW_SKILL carries $rev_row_n MIRROR-labelled \`REVIEW: RESOLVED\` rows, expected exactly 1; $MULTI_TAIL. Two mirror rows union into a pass set that matches neither"
  rev_set=""
elif [ -z "$rev_set" ]; then
  fail "$REVIEW_SKILL carries no MIRROR-labelled \`REVIEW: RESOLVED\` row; the second copy of the pass set is unasserted, and defending one copy while stranding the other is the partial fix that reads as complete"
fi

if [ "$pass11_count" -ge 3 ] && [ -n "$rev_set" ]; then
  only_11_rev="$(comm -23 <(printf '%s\n' "$pass11") <(printf '%s\n' "$rev_set") | tr '\n' ' ' | sed 's/ *$//;s/ /, /g')"
  only_rev="$(comm -13 <(printf '%s\n' "$pass11") <(printf '%s\n' "$rev_set") | tr '\n' ' ' | sed 's/ *$//;s/ /, /g')"

  if [ -n "$only_11_rev" ] || [ -n "$only_rev" ]; then
    fail "pass-set drift between §11 and $REVIEW_SKILL's \`REVIEW: RESOLVED\` row: only in §11: ${only_11_rev:-none}; only in the mirror: ${only_rev:-none}"
  fi

  if ! printf '%s\n' "$rev_row" | grep -qF '§11'; then
    fail "$REVIEW_SKILL's \`REVIEW: RESOLVED\` row is labelled a MIRROR without citing §11; the section it mirrors has to be named for a reader to resolve the copy"
  fi
fi

# L10 — the audited dead end. A deferred row is never cleared inside the change that defers it, so
# the archive report IS the entire record that the obligation exists: Step 0 has to list those rows
# and the report template has to carry a field for them. `**Deferred rows**` is a template field,
# not prose — a paragraph about auditing deferrals cannot produce it.
audit_bullet="$(printf '%s\n' "$step0" | bullet_body 'Audit trail' || true)"
audit_bullet_n="$(unit_count "$audit_bullet")"
template_field="$(grep -F '**Deferred rows**' "$ARCHIVE_SKILL" || true)"
template_field_n="$(unit_count "$template_field")"

if [ "$audit_bullet_n" -eq 0 ]; then
  fail "$ARCHIVE_SKILL Step 0 carries no \"Audit trail\" bullet; the rows the gate lets through unfixed would leave no trail at all"
elif [ "$audit_bullet_n" -gt 1 ]; then
  fail "$ARCHIVE_SKILL Step 0 carries $audit_bullet_n bullets matching \"Audit trail\", expected exactly 1; $MULTI_TAIL"
elif ! printf '%s\n' "$audit_bullet" | grep -qF 'deferred'; then
  fail "$ARCHIVE_SKILL Step 0's audit-trail bullet does not list \`deferred\` rows; a closed state with no audit trail is a finding that disappears"
fi

if [ "$template_field_n" -eq 0 ]; then
  fail "$ARCHIVE_SKILL's archive-report template carries no \`**Deferred rows**\` field; the audit-trail rule has nowhere to be written down, and nothing in v1.5.0 clears a deferred row later"
elif [ "$template_field_n" -gt 1 ]; then
  fail "$ARCHIVE_SKILL carries $template_field_n lines matching \"**Deferred rows**\", expected exactly 1; $MULTI_TAIL. The field the archive report is filled from is the normative one, and a sentence about deferred rows is not it"
  template_field=""
fi

if ! printf '%s\n%s\n' "$audit_bullet" "$template_field" | grep -qF 'destination'; then
  fail "neither $ARCHIVE_SKILL Step 0's audit-trail bullet nor its \`**Deferred rows**\` template field names the destination; a trail recording that work was deferred but not where it went is not a trail"
fi

# L24 — the ENFORCEMENT site's copy of §9's `deferred` rule, mirrored the way L8 mirrors the pass
# set. Step 0 restates the evidence form, the MANDATORY-destination rule and the never-set-it-
# yourself rule, and L8's own bullet says why the copy exists: for the executor that cannot resolve
# the contract's path. That makes this the line the fallback reader actually applies, and until now
# no clause read it — deleting it, or stripping the two rules from it, left all four checkers green
# and the archive executor holding "evidenced `deferred`" with no definition of "evidenced".
# The FORM is compared, not pinned: it is extracted from §9 and asserted here, so the checker holds
# no second copy of it and the two sites are compared on the WHOLE form rather than its prefix —
# the residual L4 above closes at the definition site. The two RULES are pinned as literals instead,
# because Step 0 addresses the executor in the imperative its `wont-fix` twin already uses and §9
# speaks of the agent in the third person: the same rule in two grammars cannot be compared by
# containment, so this half defends their PRESENCE exactly as L5 and L6 do one file over.
deferred_form="$(printf '%s\n' "$deferred_rule" | grep -oE '`deferred — user decision[^`]*`' | tr -d '`' || true)"
deferred_form_n="$(unit_count "$deferred_form")"
rule_mirror="$(printf '%s\n' "$step0" | bullet_body 'inline rule is a MIRROR' || true)"
rule_mirror_n="$(unit_count "$rule_mirror")"

# Gated on §9's rule being found as exactly one bullet — the condition L4, L5 and L6 already run
# under. Ungated, a moved `deferred` REQUIRES anchor reports twice: once as the missing bullet and
# once as a form nothing could have extracted from it, which is one defect read as two findings.
if [ "$deferred_rule_n" -eq 1 ]; then
  if [ "$deferred_form_n" -gt 1 ]; then
    fail "§9's \`deferred\` rule states $deferred_form_n backticked forms opening \"deferred — user decision\", expected exactly 1; $MULTI_TAIL. L24 would compare the mirror against whichever one came first"
    deferred_form=""
  elif [ "$deferred_form_n" -eq 0 ]; then
    fail "§9's \`deferred\` rule states no backticked form opening \"deferred — user decision\"; L4 above says which literal went missing, and L24 has no form to compare the mirror against"
  fi
fi

if [ "$rule_mirror_n" -gt 1 ]; then
  fail "$ARCHIVE_SKILL Step 0 carries $rule_mirror_n bullets matching \"inline rule is a MIRROR\", expected exactly 1; $MULTI_TAIL. A gloss carrying the form would answer for the normative rule that lost it"
elif [ "$rule_mirror_n" -eq 0 ]; then
  fail "$ARCHIVE_SKILL Step 0 carries no bullet labelled \"This inline rule is a MIRROR\"; the rule the fallback executor applies when it cannot resolve the contract's path is unlabelled and unread, which is the state in which deleting it keeps CI green"
elif [ -n "$deferred_form" ]; then
  if ! printf '%s\n' "$rule_mirror" | grep -qF "$deferred_form"; then
    fail "$ARCHIVE_SKILL Step 0's \`deferred\` rule mirror does not carry §9's evidence form \"$deferred_form\"; the destination tail is the only structural difference from \`wont-fix\`, so two copies agreeing on the prefix are not two copies of the form"
  fi
  for literal in destination MANDATORY; do
    if ! printf '%s\n' "$rule_mirror" | grep -qF "$literal"; then
      fail "$ARCHIVE_SKILL Step 0's \`deferred\` rule mirror does not carry \"$literal\"; §9 requires the destination rather than recommending it, and a mirror that drops the requirement lets an undestined row archive"
    fi
  done
  for literal in 'NEVER set deferred yourself' 'only the user can authorize it'; do
    if ! printf '%s\n' "$rule_mirror" | grep -qF "$literal"; then
      fail "$ARCHIVE_SKILL Step 0's \`deferred\` rule mirror does not state \"$literal\"; §9 reserves this hatch to the user, and the executor reading only this line is the one that would take it"
    fi
  done
  if ! printf '%s\n' "$rule_mirror" | grep -qF 'review-ledger-contract.md'; then
    fail "$ARCHIVE_SKILL Step 0's \`deferred\` rule mirror does not name review-ledger-contract.md; a mirror that does not say what it mirrors reads as an independent statement"
  fi
  if ! printf '%s\n' "$rule_mirror" | grep -qF '§9'; then
    fail "$ARCHIVE_SKILL Step 0's \`deferred\` rule mirror does not cite §9; the section it mirrors has to be named for a reader to resolve the copy"
  fi
fi

# L11 — NEGATIVE, both halves, plus a guard on EACH half, because an absence produced by a broken
# extraction reads exactly like compliance. (a) `deferred` is not a severity-floor state: §5
# partitions the WARNING and SUGGESTION rows that never block, so a closed BLOCKER state would turn
# the floor into a second escape hatch nothing gates. (b) `deferred` is not an envelope status: the
# ledger row's vocabulary and the phase envelope's are different closed sets that happen to share a
# field name, and A6's prohibition on the `status: {value}` shape is that same constraint one layer
# down. The envelope extraction is check-envelope.sh:347-355's own idiom, so the two checkers read
# that row the same way instead of each inventing a parse; the status canon is read here and written
# nowhere.
status2="$(section "$STATUS" 2)"
envelope_enum="$(
  printf '%s\n' "$status2" |
    grep -F '| `status` |' |
    sed -E 's/.*enum `([^`]*)`.*/\1/' |
    tr '|' '\n' |
    tr -d ' \\' |
    grep -E '^[a-z]+$' |
    sort -u || true
)"
envelope_count="$(unit_count "$envelope_enum")"
envelope_list="$(printf '%s' "$envelope_enum" | tr '\n' ' ' | sed 's/ *$//')"

# Matched case-insensitively: the rule is that §5 does not name the state at all, and a capitalised
# mention is the same drift written differently.
floor_hits="$(printf '%s\n' "$sec5" | grep -inF deferred || true)"
sec5_count="$(unit_count "$sec5")"

while IFS= read -r floor_hit; do
  if [ -n "$floor_hit" ]; then
    fail "§5 names \`deferred\` — \"$floor_hit\"; the severity floor is the partition of rows that never block, so a closed BLOCKER state stated there is a second escape hatch no gate reads"
  fi
done <<EOF
$floor_hits
EOF

# Same hazard as the envelope half below, same shape of answer: the negative above runs first and
# unconditionally, and this guard is additive rather than gating. §5 is reached by its `## 5.`
# section number alone — retitling the heading leaves the extraction intact, renumbering it empties
# it — and a negative asserted against nothing is indistinguishable from compliance.
if [ "$sec5_count" -eq 0 ]; then
  fail "§5's severity-floor section extraction is empty; the \`## 5.\` section number moved, so the negative above asserted an absence against text nothing read rather than against a section that does not name \`deferred\`"
fi

# The negative runs first and unconditionally, and the count guard is additive rather than gating.
# Gated behind an exact count the negative would be unreachable by its own falsifying mutation:
# ADDING `deferred` to the envelope enum moves the count to 4, so the guard would fire and the
# membership test — the assertion — would never run. An emptied extraction cannot produce a false
# accusation here, because `deferred` is not a member of nothing; the guard is what catches that.
if member deferred "$envelope_enum"; then
  fail "$STATUS §2's envelope enum carries \`deferred\` (extracted: $envelope_list); a phase envelope reports whether the phase completed and a ledger row reports how a finding was resolved, and one vocabulary leaking into the other is what A6 refuses one shape lower"
fi

if [ "$envelope_count" -ne 3 ]; then
  fail "$STATUS §2's envelope status enum yielded $envelope_count values, expected exactly 3 ($envelope_list); the status canon moved, and a negative asserted against an extraction that returns nothing passes for the wrong reason"
fi

# L12 — the report's own counters. Every closed state the gate accepts has to be countable in the
# review report, plus `open`. SUPERSET and not equality on purpose: the line legitimately also
# counts `open`, and its omission of `fixed` — never a closed state — stays legal, because forcing
# `fixed` in would smuggle an unrelated behaviour change into this one. The anchor is the Return
# template's field label, the thing the coordinator fills in rather than an explanation of it.
buckets="$(grep -F '**Findings**:' "$REVIEW_SKILL" || true)"
buckets_n="$(unit_count "$buckets")"

if [ "$buckets_n" -eq 0 ]; then
  fail "$REVIEW_SKILL has no \`**Findings**:\` bucket line; the review report has no counters for the pass set to be compared against"
elif [ "$buckets_n" -gt 1 ]; then
  fail "$REVIEW_SKILL carries $buckets_n lines matching \"**Findings**:\", expected exactly 1; $MULTI_TAIL. A filled-in example counting a status the template itself omits is the absorption this refuses"
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

# L14 — one decision menu, defined once in §9, restated only where a user is actually shown the
# choice, and cited everywhere else. Five sites, and the citing ones are the ones that get
# forgotten: three agreeing menus plus a further statement that omits an option is the partial fix
# that reads as complete. Each of the five extractions carries its own emptiness and multiplicity
# guard and its own message, so a moved anchor at one site never silences the comparison at another.
#
# The two restating sites are compared to §9 by SET EQUALITY in both directions, the way L7, L8
# and L9 compare the pass set. Two, not three: the definition site is the reference the comparison
# reads, never one of the sites compared to it. A literal containment test — which this was — is
# stricter than the canon on order and separators, where the canon is silent, and weaker than it on
# supersets, where the canon is not: `fix / wont-fix / defer / leave open / proceed` contains the
# literal and would pass, at the one site where a user is actually shown the choice, offering back
# the option §11 refuses and this change retired. Membership is the property; ordering is not.
# Nothing here enumerates the menu: §9's set is extracted at run time and is the only reference, so
# the checker holds no second copy of a list the canon owns.
#
# The matched shape is a slash-separated run of lowercase options, so the separator convention is
# what makes the set findable while the set is what is asserted — and because every site's text is
# joined and squeezed first, a meaning-preserving reflow at any of them stays legal.
#
# Finding the runs is split from choosing one so the runs can be counted before one of them answers
# for the rest. `grep -o` prints EVERY run in the joined text and only the first survives, so a
# second run is not unioned into the set — it is discarded unread, and a commentary run written
# ABOVE the normative menu is what every comparison then reads. Selecting silently is the same
# defect as unioning silently, which is why each call site below guards the run count.
menu_runs() { # joined, squeezed text on stdin — one slash-separated option run per line
  grep -oE '[a-z][a-z -]*( / [a-z][a-z -]*)+'
}

menu_set() { # option runs on stdin, one per line — the options of the FIRST run, sorted
  head -1 |
    tr '/' '\n' |
    sed -E 's/^ +//; s/ +$//' |
    grep -E '^[a-z][a-z -]*$' |
    sort -u
}

# Both directions, per restating site: an option dropped at a site and an option added at a site are
# opposite failures of the same agreement, and only the first is visible to a containment test.
menu_agree() { # site set on $1, site description on $2
  only_menu9="$(comm -23 <(printf '%s\n' "$menu9") <(printf '%s\n' "$1") | tr '\n' ' ' | sed 's/ *$//;s/ /, /g')"
  only_site="$(comm -13 <(printf '%s\n' "$menu9") <(printf '%s\n' "$1") | tr '\n' ' ' | sed 's/ *$//;s/ /, /g')"
  if [ -n "$only_menu9" ] || [ -n "$only_site" ]; then
    fail "decision-menu drift between §9 and $2: only in §9: ${only_menu9:-none}; only at that site: ${only_site:-none}"
  fi
}

# (a) the definition site, and the two sites that restate it
menu="$(printf '%s\n' "$sec9" | bullet_body 'decision menu' || true)"
menu_n="$(unit_count "$menu")"
menu9_runs="$(printf '%s\n' "$menu" | menu_runs || true)"
menu9_runs_n="$(unit_count "$menu9_runs")"
menu9="$(printf '%s\n' "$menu9_runs" | menu_set || true)"
menu9_count="$(unit_count "$menu9")"
menu9_list="$(printf '%s' "$menu9" | awk '{ printf "%s%s", (NR > 1 ? ", " : ""), $0 } END { print "" }')"

if [ "$menu_n" -eq 0 ]; then
  fail "§9 carries no bullet naming a \"decision menu\"; the menu has no definition site, so the two sites that state it and the two that cite it all resolve to nothing"
elif [ "$menu_n" -gt 1 ]; then
  fail "§9 carries $menu_n bullets naming a \"decision menu\", expected exactly 1; $MULTI_TAIL. A menu with two definition sites is the drift this clause exists to refuse"
elif [ "$menu9_runs_n" -gt 1 ]; then
  fail "§9's decision-menu bullet carries $menu9_runs_n slash-separated option runs, expected exactly 1; the first is selected and the rest discarded unread, so a commentary run would become the set both restating sites are compared against"
  menu9_count=0
elif [ "$menu9_count" -lt 3 ]; then
  fail "§9's decision-menu bullet yielded $menu9_count options, below the floor of 3; the slash-separated option run moved or reflowed, so the definition site states no set for the restating sites to be compared against"
  menu9_count=0
elif ! member defer "$menu9"; then
  # Set equality alone would let all three sites drop the same option together and stay equal — the
  # residual L7 has too. `defer` is the option this change adds, so its membership is pinned at the
  # definition site exactly as L2 pins `deferred` in §2's enum. One membership test, not an
  # enumeration: the other three options are compared, never listed.
  fail "§9's decision-menu bullet does not offer \`defer\` (extracted: $menu9_list); the option that routes a severe finding to a destination is what the deferred state exists to give the user, and three sites agreeing it is gone is still three sites agreeing on the wrong menu"
fi

# The step-5 scope ends at the next numbered step, never at a second `5. **USER GATE` opening, so
# the openings joined into it are counted too: this is the one extraction here whose unit is a whole
# numbered step rather than a bullet, and two steps read as one is the same absorption.
gate_step="$(awk '/^5\. \*\*USER GATE/ { f = 1 } f && /^[0-9]+\. / && !/^5\. / { exit } f' "$REVIEW_SKILL" | tr '\n' ' ' | tr -s ' ' || true)"
gate_opens="$(printf '%s\n' "$gate_step" | grep -oF '5. **USER GATE' || true)"
gate_opens_n="$(unit_count "$gate_opens")"
gate_runs="$(printf '%s\n' "$gate_step" | menu_runs || true)"
gate_runs_n="$(unit_count "$gate_runs")"
gate_menu="$(printf '%s\n' "$gate_runs" | menu_set || true)"
gate_menu_count="$(unit_count "$gate_menu")"

if [ -z "$gate_step" ]; then
  fail "$REVIEW_SKILL has no numbered step opening \"5. **USER GATE\"; the step where the user is shown the menu moved and L14 has nothing to read"
elif [ "$gate_opens_n" -gt 1 ]; then
  fail "$REVIEW_SKILL's step-5 scope joins $gate_opens_n \"5. **USER GATE\" openings, expected exactly 1; $MULTI_TAIL, and the scope ends at the next numbered step rather than at the second opening"
elif [ "$gate_runs_n" -gt 1 ]; then
  fail "$REVIEW_SKILL's USER GATE step carries $gate_runs_n slash-separated option runs, expected exactly 1; the first is selected and the rest discarded unread, so the place a user is actually asked can stop offering an option while a run above it answers for the menu"
elif [ "$gate_menu_count" -lt 3 ]; then
  fail "$REVIEW_SKILL's USER GATE step states $gate_menu_count menu options, below the floor of 3; the place a user is actually asked no longer presents a slash-separated option set, so nothing there can be compared with §9's ($menu9_list)"
elif [ "$menu9_count" -ge 3 ]; then
  menu_agree "$gate_menu" "$REVIEW_SKILL's USER GATE step, the place a user is actually asked"
fi

orch_bullet="$(bullet_body 'OPEN-FINDINGS' < "$ORCHESTRATOR" || true)"
orch_bullet_n="$(unit_count "$orch_bullet")"
orch_runs="$(printf '%s\n' "$orch_bullet" | menu_runs || true)"
orch_runs_n="$(unit_count "$orch_runs")"
orch_menu="$(printf '%s\n' "$orch_runs" | menu_set || true)"
orch_menu_count="$(unit_count "$orch_menu")"

if [ "$orch_bullet_n" -eq 0 ]; then
  fail "$ORCHESTRATOR carries no \`REVIEW: OPEN-FINDINGS\` outcome bullet; the menu's second restating site moved, and L14 and L15 both read it"
elif [ "$orch_bullet_n" -gt 1 ]; then
  fail "$ORCHESTRATOR carries $orch_bullet_n bullets matching \"OPEN-FINDINGS\", expected exactly 1; $MULTI_TAIL. L15's negative would then be satisfied by whichever bullet omits \`proceed\`"
elif [ "$orch_runs_n" -gt 1 ]; then
  fail "$ORCHESTRATOR's OPEN-FINDINGS bullet carries $orch_runs_n slash-separated option runs, expected exactly 1; the first is selected and the rest discarded unread, so the router can stop offering an option while a run beside it answers for the menu"
elif [ "$orch_menu_count" -lt 3 ]; then
  fail "$ORCHESTRATOR's OPEN-FINDINGS bullet states $orch_menu_count menu options, below the floor of 3; the router no longer presents a slash-separated option set, so nothing there can be compared with §9's ($menu9_list)"
elif [ "$menu9_count" -ge 3 ]; then
  menu_agree "$orch_menu" "$ORCHESTRATOR's OPEN-FINDINGS bullet, where the router presents the choice"
fi

# (b) the two citing sites. Both are Judgment-Day-scoped and have no reason to hold the menu
# inline, so each cites §9 rather than restating it. Both halves are needed at each site: the
# citation alone would allow the options to stay beside it, and the negative alone would allow a
# bare rule citing nothing.
jd_bullet="$(printf '%s\n' "$sec7" | bullet_body 'resolve only by user decision' || true)"
jd_bullet_n="$(unit_count "$jd_bullet")"

if [ "$jd_bullet_n" -eq 0 ]; then
  fail "§7 carries no bullet stating that suspect and contradiction findings \"resolve only by user decision\"; the rule that hands those rows to the user's menu moved"
elif [ "$jd_bullet_n" -gt 1 ]; then
  fail "§7 carries $jd_bullet_n bullets matching \"resolve only by user decision\", expected exactly 1; $MULTI_TAIL. One bullet citing §9 would answer for another that enumerates the menu itself"
else
  if ! printf '%s\n' "$jd_bullet" | grep -qF '§9'; then
    fail "§7's user-decision bullet does not cite §9; a rule that names no definition site is read as one, and this is the site that gets left behind when the menu changes"
  fi
  if printf '%s\n' "$jd_bullet" | grep -qF 'wont-fix'; then
    fail "§7's user-decision bullet enumerates options of its own (it names \`wont-fix\`); that makes it a fourth statement of the menu, and a fourth statement is what silently omits an option"
  fi
fi

# The second citing site is a table cell, not a bullet: the corroboration table's `suspect` row
# hands those findings to the user, so it belongs to the category above and is asserted the same
# way. Line-scoping is legitimate here for L9's reason — a markdown table row is one line by
# construction, so no reflow can split it — and the row is counted for L9's other reason: a second
# line carrying both literals would answer for a normative row that cites nothing.
suspect_row="$(grep -F 'jd:a-only' "$REVIEW_SKILL" | grep -F '`suspect`' || true)"
suspect_row_n="$(unit_count "$suspect_row")"

if [ "$suspect_row_n" -eq 0 ]; then
  fail "$REVIEW_SKILL carries no \`jd:a-only\` corroboration row naming \`suspect\`; the cell that hands a one-judge finding to the user moved, and unread is exactly the state in which it restates the menu"
elif [ "$suspect_row_n" -gt 1 ]; then
  fail "$REVIEW_SKILL carries $suspect_row_n \`jd:a-only\` rows naming \`suspect\`, expected exactly 1; $MULTI_TAIL. One row citing §9 would answer for another that enumerates the menu itself"
else
  if ! printf '%s\n' "$suspect_row" | grep -qF '§9'; then
    fail "$REVIEW_SKILL's \`suspect\` corroboration row does not cite §9; the resolution set for those rows is the user's menu, and a cell naming no definition site is read as one"
  fi
  if printf '%s\n' "$suspect_row" | grep -qF 'wont-fix'; then
    fail "$REVIEW_SKILL's \`suspect\` corroboration row enumerates options of its own (it names \`wont-fix\`); that makes it a further statement of the menu, and one no clause compares with §9 is what silently offers two of four options"
  fi
fi

# L15 — NEGATIVE: `proceed` is retired as a row-level outcome. It meant advancing past the gate
# with rows still open, which §11 refuses, so the router was offering a choice the archive gate
# would reject. Scope is load-bearing and the negative is NEVER file-wide: elsewhere in this file
# "proceed to Phase 5" is correct prose, and §9's own menu bullet mentions `proceed` in negated
# form. Both must survive, so the assertion reads the OPEN-FINDINGS bullet and nothing else.
if [ "$orch_bullet_n" -eq 1 ] && printf '%s\n' "$orch_bullet" | grep -qF 'proceed'; then
  fail "$ORCHESTRATOR's OPEN-FINDINGS bullet still offers \`proceed\`; §11 refuses a ledger with open severe rows, so that option has no legal outcome and \`defer\` is what it was reaching for"
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
  union_bullet_n="$(unit_count "$union_bullet")"

  if [ "$union_bullet_n" -eq 0 ]; then
    fail "§9 defines no set under the word $STATUS §5 cites ($union_word); a consumer resolving that citation gets nothing back, so the countable signal for review-ledger cannot be derived"
  elif [ "$union_bullet_n" -gt 1 ]; then
    fail "§9 defines $union_bullet_n sets under the word $STATUS §5 cites ($union_word), expected exactly 1; $MULTI_TAIL. A citation resolving to two definitions resolves to neither"
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
caveat_n="$(unit_count "$caveat")"

if [ "$caveat_n" -eq 0 ]; then
  fail "§11 carries no bullet opening \"No check can validate\"; the canon does not say what \"mechanically checkable\" means here, so every clause in this script reads as a test of a real ledger row"
elif [ "$caveat_n" -gt 1 ]; then
  fail "§11 carries $caveat_n bullets opening \"No check can validate\", expected exactly 1; $MULTI_TAIL. The caveat that bounds every other clause cannot be assembled out of two"
else
  for literal in 'real ledger row' "user's own project" 'checkers run over the plugin repo' 'A mandated form is never a validated row'; do
    if ! printf '%s\n' "$caveat" | grep -qF "$literal"; then
      fail "§11's checkability caveat does not carry the literal \"$literal\"; without it the canon claims a coverage no checker in this repository can deliver"
    fi
  done
fi

# --------------------------------------------------------------------------------------------
# L19-L23 close five labels this change over-claimed. The delta spec measures five [CI] scenarios
# as though a checker defended them while nothing here read them. The ones whose text this change
# wrote or edited get a clause; the ones carried forward unchanged from a modified requirement are
# relabelled in the spec instead of defended by a clause invented after the fact, because a clause
# written to cover text nobody touched asserts the tree it was written against and nothing more.
# --------------------------------------------------------------------------------------------

# The markdown surface, in check-envelope.sh:104-110's own idiom, so the two checkers agree on what
# "repo-wide" means rather than each inventing a scope.
scan_files="$(
  {
    find skills agents commands -type f -name '*.md' 2>/dev/null || true
    for surface_file in "$README" AGENTS.md; do
      if [ -f "$surface_file" ]; then echo "$surface_file"; fi
    done
  } | sort -u
)"

names_all() { # whitespace-separated values on $1, file on $2 — every line naming all of them
  awk -v vals="$1" -v file="$2" '
    {
      n = split(vals, V, " +")
      for (i = 1; i <= n; i++) {
        if (V[i] != "" && index($0, V[i]) == 0) { next }
      }
      print file "\t" FNR "\t" $0
    }
  ' "$2"
}

para_body() { # keyword on $1; body on stdin — one blank-line-delimited paragraph, joined
  awk -v kw="$1" '
    function flush() { if (buf != "" && index(buf, kw) > 0) print buf; buf = "" }
    /^[[:space:]]*$/ { flush(); next }
    { buf = (buf == "" ? $0 : buf " " $0) }
    END { flush() }
  ' | tr -s " "
}

# L19 — the mirror count is frozen at exactly two, and every other statement of the pass set is
# accounted for. The pass set legitimately has one definition site plus two copies, because both
# are read by executor sub-agents that may not be able to resolve the contract's path. A THIRD
# copy is drift, and its failure mode is silent: the third statement keeps the old set and no
# clause compares it to anything, which is how this change found `sdd-review`'s row stranded while
# `sdd-archive`'s was already asserted. The three legitimate categories are keyed on SHAPES — the
# canon's own path, the `MIRROR` label beside the contract's filename, and the review report's
# `**Findings**:` field label — never on a topic word and never on a hardcoded list of values.
pass_statements="$(
  if [ "$pass11_count" -ge 3 ]; then
    printf '%s\n' "$scan_files" | while IFS= read -r scan_file; do
      if [ -n "$scan_file" ]; then
        names_all "$(printf '%s' "$pass11" | tr '\n' ' ')" "$scan_file"
      fi
    done
  fi
)"
labelled_mirrors="$(printf '%s\n' "$pass_statements" | grep -F 'MIRROR' | grep -F 'review-ledger-contract.md' || true)"
mirror_count="$(printf '%s' "$labelled_mirrors" | grep -c . || true)"
mirror_files="$(printf '%s\n' "$labelled_mirrors" | cut -f1 | sort -u | grep -c . || true)"

if [ "$pass11_count" -ge 3 ]; then
  if [ "$mirror_count" -eq 0 ]; then
    fail "no line in the markdown surface states the §11 pass set under a \`MIRROR\` label naming review-ledger-contract.md; the label convention that makes a copy findable moved, so L19 can no longer tell a permitted mirror from a third statement"
  elif [ "$mirror_count" -ne 2 ] || [ "$mirror_files" -ne 2 ]; then
    fail "the §11 pass set is mirrored at $mirror_count labelled site(s) across $mirror_files file(s), expected exactly 2 across 2 — $ARCHIVE_SKILL Step 0 and $REVIEW_SKILL's \`REVIEW: RESOLVED\` row, the only two an executor reads when it cannot resolve the contract's path"
  fi

  while IFS="$(printf '\t')" read -r stmt_file stmt_line stmt_text; do
    if [ -z "$stmt_file" ] || [ "$stmt_file" = "$LEDGER" ]; then
      continue
    fi
    if printf '%s\n' "$stmt_text" | grep -qF 'MIRROR' && printf '%s\n' "$stmt_text" | grep -qF 'review-ledger-contract.md'; then
      continue
    fi
    if printf '%s\n' "$stmt_text" | grep -qF '**Findings**:'; then
      continue
    fi
    fail "$stmt_file:$stmt_line states the whole §11 pass set without labelling itself a MIRROR of review-ledger-contract.md; that is a third copy of the set, and nothing compares it to §11"
  done <<EOF
$pass_statements
EOF
fi

# L20 — the status enum has exactly one home. check-envelope.sh's A3 makes this assertion for the
# status canon's two enums; the ledger's enum never had it, and this change is the first to touch
# that line since it was written. Two halves, because either alone is satisfiable the wrong way:
# the definition site's own lead-in shape occurs exactly once and in $LEDGER, and no other file in
# the markdown surface carries a line naming every declared value. The second half is what makes it
# a test of the enum rather than a test of one phrase — a full copy written in different words
# still has to name all of them.
enum_sites="$(
  printf '%s\n' "$scan_files" | while IFS= read -r scan_file; do
    if [ -n "$scan_file" ]; then
      grep -lF '`status` — one of' "$scan_file" || true
    fi
  done
)"
enum_site_count="$(printf '%s' "$enum_sites" | grep -c . || true)"
# Flattened for the message: a failure line has to stay one line, or `report` splits it across
# two "also:" prefixes and the second half reads as a separate finding.
enum_sites_list="$(printf '%s' "$enum_sites" | tr '\n' ' ' | sed 's/ *$//')"

if [ "$enum_site_count" -ne 1 ]; then
  fail "the \"\`status\` — one of\" lead-in appears at $enum_site_count sites in the markdown surface, expected exactly 1 ($enum_sites_list); the enum's single definition site is what makes every other file's partition a derived copy rather than a second declaration"
elif [ "$enum_sites" != "$LEDGER" ]; then
  fail "the status enum is declared in $enum_sites rather than $LEDGER; the schema's home moved and every clause here reads the wrong file"
fi

enum_copies="$(
  printf '%s\n' "$scan_files" | while IFS= read -r scan_file; do
    if [ -n "$scan_file" ] && [ "$scan_file" != "$LEDGER" ]; then
      names_all "$enum_list" "$scan_file"
    fi
  done
)"

while IFS="$(printf '\t')" read -r copy_file copy_line copy_text; do
  if [ -z "$copy_file" ]; then
    continue
  fi
  fail "$copy_file:$copy_line names every value of §2's status enum; the full enum has one definition site and a second copy drifts the moment an eighth value is added"
done <<EOF
$enum_copies
EOF

# L21 — NEGATIVE: the canon names no issue tracker. `{destination}` is a free string the user
# supplies, and a tracker reference in an artifact schema would be this plugin's first. A real ROW
# may name a real destination; the prohibition is on the CANON, never on the data. Two shapes,
# tested deliberately differently. Product names are matched case-insensitively over the whole
# file. The issue-key shape is matched case-SENSITIVELY and only inside §9 and §11, because §2's
# own row-id format is `{PREFIX}-{NNN}` — a tracker-shaped string by construction — so a whole-file
# shape test would fire on the canon's own ids, and under `-i` the shape matches ordinary hyphenated
# words too, which is how a negative like this comes to pass for the wrong reason.
tracker_names="$(grep -inE 'jira|linear|asana|trello|youtrack|clickup|redmine|bugzilla|pivotal|github issue|gitlab issue|azure boards' "$LEDGER" || true)"
tracker_shapes="$(printf '%s\n%s\n' "$sec9" "$sec11" | grep -nE '[A-Z]{2,}-[0-9]+' || true)"

while IFS= read -r tracker_hit; do
  if [ -n "$tracker_hit" ]; then
    fail "$LEDGER names an issue tracker: \"$tracker_hit\"; the destination is a free string the user supplies and this canon assumes no tracker exists"
  fi
done <<EOF
$tracker_names
EOF

while IFS= read -r shape_hit; do
  if [ -n "$shape_hit" ]; then
    fail "§9 or §11 shows a tracker-shaped issue identifier: \"$shape_hit\"; an example destination in that shape assumes the tracker the canon says it does not assume"
  fi
done <<EOF
$tracker_shapes
EOF

if [ -n "$deferred_rule" ]; then
  for literal in 'the user supplies it' 'names no tracker and assumes none exists'; do
    if ! printf '%s\n' "$deferred_rule" | grep -qF "$literal"; then
      fail "§9's \`deferred\` rule does not state \"$literal\"; without it the destination has no stated nature, and the negative above defends an absence the canon never claimed"
    fi
  done
fi

# L22 — the by-design consequence, stated at the definition site. A review whose severe rows are
# all evidenced `deferred` returns RESOLVED, routes to verify, and the change archives with those
# findings unfixed. That reads exactly like a hole in the gate, so the canon has to say it is
# intended, in those words, where the outcome is defined — otherwise a future reader files it as a
# bug and a future refuter confirms the filing. Scoped to the outcome section and then to the ONE
# paragraph opening with its own words, so the three literals have to co-occur there and cannot be
# assembled out of the routing table or the mirror row a few lines above.
summary_section="$(awk '$0 == "## Review Summary" { f = 1; next } f && /^## / { exit } f' "$REVIEW_SKILL" || true)"
by_design="$(printf '%s\n' "$summary_section" | para_body 'rows are all closed' || true)"
by_design_n="$(unit_count "$by_design")"

if [ -z "$summary_section" ]; then
  fail "$REVIEW_SKILL has no \"## Review Summary\" section; the outcome tokens and their consequences moved and L22 has nothing to read"
elif [ "$by_design_n" -eq 0 ]; then
  fail "$REVIEW_SKILL's Review Summary carries no paragraph about a ledger whose rows are all closed; the deferred-only outcome is left to be inferred, and inferred it reads as a hole in the archive gate"
elif [ "$by_design_n" -gt 1 ]; then
  fail "$REVIEW_SKILL's Review Summary carries $by_design_n paragraphs about a ledger whose rows are all closed, expected exactly 1; $MULTI_TAIL. The by-design claim has to be made where the outcome is defined, not spread over two paragraphs"
else
  for literal in 'is RESOLVED and routes as RESOLVED' 'resolves it for this cycle' 'archives with that finding unfixed, by design'; do
    if ! printf '%s\n' "$by_design" | grep -qF "$literal"; then
      fail "$REVIEW_SKILL's deferred-only paragraph does not state \"$literal\"; the consequence has to be claimed as intended behaviour at the site that defines the outcome, not implied near it"
    fi
  done
fi

# L23 — neither escape hatch is the coordinator's to take. This rule is the one conformance edit in
# this change with no other mechanical defence at all: A6 and A7 do not read it, no set extraction
# touches it, and one careless edit reverts it silently in the file the whole change is about.
# Scoped to the Rules section and then to the bullet opening with the rule's own normative words.
rules_section="$(awk '$0 == "## Rules" { f = 1; next } f && /^## / { exit } f' "$REVIEW_SKILL" || true)"
never_set="$(printf '%s\n' "$rules_section" | bullet_body 'NEVER dispatch the fix agent' || true)"
never_set_n="$(unit_count "$never_set")"

if [ -z "$rules_section" ]; then
  fail "$REVIEW_SKILL has no \"## Rules\" section; the rule reserving both escape hatches to the user has no home"
elif [ "$never_set_n" -eq 0 ]; then
  fail "$REVIEW_SKILL's Rules section carries no bullet opening \"NEVER dispatch the fix agent\"; the rule that keeps the coordinator out of both escape hatches moved"
elif [ "$never_set_n" -gt 1 ]; then
  fail "$REVIEW_SKILL's Rules section carries $never_set_n bullets opening \"NEVER dispatch the fix agent\", expected exactly 1; $MULTI_TAIL. This rule has no other mechanical defence at all"
else
  if ! printf '%s\n' "$never_set" | grep -qF '`deferred` rows'; then
    fail "$REVIEW_SKILL's no-dispatch rule does not list \`deferred\` rows; a row closed by routing the work elsewhere is not a row for the fix agent"
  fi
  if ! printf '%s\n' "$never_set" | grep -qF 'NEVER set `wont-fix` or `deferred`'; then
    fail "$REVIEW_SKILL's never-set rule does not name \`deferred\` beside \`wont-fix\`; a second escape hatch an agent may take on its own is not a user decision, and §9 reserves both"
  fi
  if ! printf '%s\n' "$never_set" | grep -qF '§9'; then
    fail "$REVIEW_SKILL's never-set rule cites no §9; the form the decision has to be recorded in lives there, and a rule with no citation is read as its own definition site"
  fi
fi

report

echo "check-ledger: OK — ledger canon complete, $enum_count status values extracted, pass set agrees across §9, §11 and both mirrors"
