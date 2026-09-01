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
sec11="$(section "$LEDGER" 11)"

# L1 — vacuity guard. The floor is a floor, not a count: an eighth status value added later is
# legal, and an exact count would be a second copy of the enum's size. Reported immediately
# because every clause below reads $enum.
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
  fail "§2's status enum extraction yielded $enum_count values, below the floor of 6; the \"## 2. Ledger Schema\" heading or its \`status\` bullet moved, and every clause below would read an empty set and pass vacuously"
  report
fi

# L2 — the seventh value exists where the schema is defined. §9 and §11 name statuses; only §2
# declares them, so a state defined anywhere else is not in the enum.
if ! member deferred "$enum"; then
  fail "§2's status enum does not carry \`deferred\` (extracted: $enum_list); the schema bullet is the enum's only definition site"
fi

# L8 — sdd-archive Step 0's pass set is a MIRROR of §11 and CI asserts the two set-equal. The
# label makes the bullet findable; the set comparison is the assertion.
pass11="$(printf '%s\n' "$sec11" | bullet_body 'archive pass set' | tokens || true)"

if [ -z "$pass11" ]; then
  fail "§11 carries no dedicated \"archive pass set\" bullet; L8 has nothing to compare $ARCHIVE_SKILL's mirror against, and a comparison against an empty side would name every value as drift"
fi

step0="$(awk '/^### Step 0/ { f = 1; next } f && /^### / { exit } f' "$ARCHIVE_SKILL")"

if [ -z "$step0" ]; then
  fail "$ARCHIVE_SKILL has no \"### Step 0\" section; the archive gate's mirror has no home"
fi

arch_set="$(printf '%s\n' "$step0" | bullet_body 'MIRROR' | tokens || true)"

if [ -z "$arch_set" ]; then
  fail "$ARCHIVE_SKILL Step 0 carries no MIRROR-labelled pass-set bullet; L8's set comparison has nothing to read"
fi

if [ -n "$pass11" ] && [ -n "$arch_set" ]; then
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

report

echo "check-ledger: OK — ledger canon complete, $enum_count status values extracted, pass set agrees across §11 and the sdd-archive mirror"
