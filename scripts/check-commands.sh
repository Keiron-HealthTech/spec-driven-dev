#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

CONTRACT=skills/_shared/sdd-status-contract.md
REGISTRY=skills/_shared/engram-convention.md

fail() {
  echo "check-commands: FAIL — $1" >&2
  exit 1
}

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
# Both sides are extracted at runtime: renaming either heading empties a set and fails loudly.
if [ ! -f "$CONTRACT" ]; then
  fail "$CONTRACT is missing; the registry has no projection map to agree with"
fi

registry_types="$(
  awk '/^### Artifact Types/ {f=1; next} f && /^#/ {exit} f' "$REGISTRY" |
    grep -E '^\| `' |
    sed -E 's/^\| `([a-z-]+)`.*/\1/' |
    sort -u || true
)"

contract_types="$(
  awk '/^## 4\. / {f=1; next} f && /^## / {exit} f' "$CONTRACT" |
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

only_registry="$(comm -23 <(echo "$registry_types") <(echo "$contract_types") | tr '\n' ' ' | sed 's/ *$//')"
only_contract="$(comm -13 <(echo "$registry_types") <(echo "$contract_types") | tr '\n' ' ' | sed 's/ *$//')"

if [ -n "$only_registry" ] || [ -n "$only_contract" ]; then
  fail "artifact type drift: registry-only: ${only_registry:-none}; projection-only: ${only_contract:-none}"
fi

echo "check-commands: OK — registry complete"
