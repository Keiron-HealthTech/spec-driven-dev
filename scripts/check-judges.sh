#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

A=agents/jd-judge-a.md
B=agents/jd-judge-b.md

for f in "$A" "$B"; do
  if [ ! -f "$f" ]; then
    echo "check-judges: FAIL — missing $f" >&2
    exit 1
  fi
done

# Judge bodies must be byte-identical once identity tokens are normalized.
if ! diff \
  <(sed -e 's/jd-judge-a/jd-judge-X/g' -e 's/Judge A/Judge X/g' "$A") \
  <(sed -e 's/jd-judge-b/jd-judge-X/g' -e 's/Judge B/Judge X/g' "$B"); then
  echo "check-judges: FAIL — judge bodies drifted; regenerate $B from $A" >&2
  exit 1
fi

echo "check-judges: OK — judge bodies identical up to identity tokens"
