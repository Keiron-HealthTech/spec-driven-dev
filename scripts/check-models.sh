#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

ORCHESTRATOR=skills/sdd-orchestrator/SKILL.md
REVIEW=skills/sdd-review/SKILL.md
README=README.md

# Every subagent in this plugin used to inherit the session model. When that session runs Opus,
# ten phase delegates and nine agents all run Opus, including four review lenses in parallel over
# the same diff. The assignment below is what removes that default, so these assertions exist to
# keep it declared rather than remembered: an undeclared model is silently the old behavior back.
ALLOWED='opus|sonnet|haiku'

# A statement may name an override only to forbid it. Same vocabulary as check-envelope.sh, so
# the two scripts agree on what turns a mention into a prohibition.
NEGATION='never|not |no |none|nothing|cannot|neither|without'

# Failures accumulate instead of exiting at the first one, matching check-commands.sh: a single
# run then names every violated assertion, which is what makes a deliberate one-line mutation
# observable even when an unrelated assertion is already failing.
FAILURES=""

fail() {
  FAILURES="${FAILURES}${FAILURES:+$'\n'}$1"
}

# Called at the end, and early wherever continuing would run an assertion against a file or a set
# that is not there — those cases report what is known and stop rather than cascade.
report() {
  if [ -n "$FAILURES" ]; then
    echo "check-models: FAIL — $(printf '%s\n' "$FAILURES" | head -1)" >&2
    printf '%s\n' "$FAILURES" | tail -n +2 | sed 's/^/  also: /' >&2
    exit 1
  fi
}

heading_body() { # file, exact "## " heading line — its body up to the next "## "
  awk -v h="$2" '$0 == h { f = 1; next } f && /^## / { exit } f' "$1"
}

# The frontmatter only, never the body: a prose line reading `model: sonnet` inside an agent's
# instructions is documentation, not a declaration, and must not satisfy M1 on its behalf.
frontmatter() { # file
  awk 'NR == 1 { if ($0 != "---") exit; next } /^---[[:space:]]*$/ { exit } { print }' "$1"
}

model_of() { # file — the declared value, empty when absent or unparseable
  frontmatter "$1" |
    sed -nE 's/^model:[[:space:]]*//p' |
    head -1 |
    sed -E 's/[[:space:]]*#.*$//' |
    tr -d "\"'" |
    sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//'
}

# M1 — every registered agent declares one model from the allowed set, inside its frontmatter.
# `inherit` is rejected here rather than accepted as an explicit choice: it is byte-for-byte the
# session-inheritance this assignment exists to remove, so allowing it would let the default back
# in under a name that reads like a decision.
agent_files="$(find agents -maxdepth 1 -name '*.md' | sort || true)"

if [ -z "$agent_files" ]; then
  fail "agents/ yielded no agent files; every model assertion below would pass vacuously"
  report
fi

while IFS= read -r f; do
  [ -n "$f" ] || continue

  declared="$(frontmatter "$f" | grep -cE '^model:' || true)"
  if [ "$declared" -eq 0 ]; then
    fail "$f declares no \`model:\` in its frontmatter; it inherits the session model, which is the Opus-by-default cost this assignment removes"
    continue
  fi
  if [ "$declared" -gt 1 ]; then
    fail "$f declares \`model:\` $declared times; which one binds is left to the reader"
    continue
  fi

  value="$(model_of "$f")"
  if [ -z "$value" ]; then
    fail "$f declares an empty \`model:\` value; the assignment would be scanned vacuously"
    continue
  fi
  if [ "$value" = "inherit" ]; then
    fail "$f declares \`model: inherit\`; that IS session inheritance, so the agent still runs whatever the session runs"
    continue
  fi
  if ! printf '%s\n' "$value" | grep -qxE "$ALLOWED"; then
    fail "$f declares the unknown model \"$value\"; allowed values are opus, sonnet and haiku"
  fi
done <<EOF
$agent_files
EOF

# M2 — the two blind judges run the same model. check-judges.sh compares their bodies up to
# identity tokens and would catch a divergence, but it would report it as generic drift; named
# here, the reason survives: a dual review whose judges differ in capability is not a blind pair,
# it is a strong judge and a weak one, and disagreement between them stops being evidence.
A=agents/jd-judge-a.md
B=agents/jd-judge-b.md
if [ -f "$A" ] && [ -f "$B" ]; then
  model_a="$(model_of "$A")"
  model_b="$(model_of "$B")"
  if [ -n "$model_a" ] && [ -n "$model_b" ] && [ "$model_a" != "$model_b" ]; then
    fail "$A declares \"$model_a\" and $B declares \"$model_b\"; blind judges must be equally capable or their disagreement means nothing"
  fi
fi

report

# M3 — the phase delegates are launched as `subagent_type: 'general'`, so they have no frontmatter
# to carry a model and the orchestrator must pass one per phase. The roster is never hardcoded
# here: it is derived from the ORCHESTRATOR GATE line each phase skill carries, so adding a phase
# skill without a table row fails loudly instead of quietly inheriting the session model.
delegates="$(
  grep -rlE "Task\(subagent_type: 'general'\)" skills/*/SKILL.md 2>/dev/null |
    sed -E 's|^skills/||; s|/SKILL.md$||' |
    sort -u || true
)"

if [ -z "$delegates" ]; then
  fail "no phase skill carries the \`Task(subagent_type: 'general')\` gate line; the phase roster would be compared against nothing"
  report
fi

if [ ! -f "$ORCHESTRATOR" ]; then
  fail "$ORCHESTRATOR is missing; the phase model assignment has no home"
  report
fi

TABLE_HEADING='## Phase Model Assignment'
table_rows="$(
  heading_body "$ORCHESTRATOR" "$TABLE_HEADING" |
    sed -nE 's/^\|[[:space:]]*`(sdd-[a-z-]+)`[[:space:]]*\|[[:space:]]*`?([A-Za-z0-9_.-]+)`?[[:space:]]*\|.*/\1 \2/p' || true
)"
table_phases="$(printf '%s\n' "$table_rows" | awk 'NF {print $1}' | sort -u || true)"

if [ -z "$table_phases" ]; then
  fail "$ORCHESTRATOR's \"$TABLE_HEADING\" table yielded no rows; the heading or the table moved and every phase would inherit the session model"
  report
fi

# Set equality in both directions: a phase skill with no row, and a row naming no phase skill.
unassigned="$(comm -23 <(printf '%s\n' "$delegates") <(printf '%s\n' "$table_phases") | tr '\n' ' ' | sed 's/ *$//;s/ /, /g')"
phantom="$(comm -13 <(printf '%s\n' "$delegates") <(printf '%s\n' "$table_phases") | tr '\n' ' ' | sed 's/ *$//;s/ /, /g')"
if [ -n "$unassigned" ] || [ -n "$phantom" ]; then
  fail "$ORCHESTRATOR's phase model table has drifted from the delegate roster: unassigned: ${unassigned:-none}; no such phase skill: ${phantom:-none}"
fi

# M4 — every value in that table is a model this runtime accepts. A typo here does not fail at
# launch: an unrecognized value falls back to inheritance, which is the exact silent regression.
while IFS=' ' read -r phase value; do
  [ -n "${phase:-}" ] || continue
  if [ "$value" = "inherit" ]; then
    fail "$ORCHESTRATOR assigns \`inherit\` to $phase; that leaves the phase running whatever the session runs"
    continue
  fi
  if ! printf '%s\n' "$value" | grep -qxE "$ALLOWED"; then
    fail "$ORCHESTRATOR assigns the unknown model \"$value\" to $phase; allowed values are opus, sonnet and haiku"
  fi
done <<EOF
$table_rows
EOF

# M5 — the launch template itself carries the field. The table is a decision; the template is
# where the decision reaches a running subagent, and a table nobody passes changes nothing.
LAUNCH_HEADING='## Sub-Agent Launching Pattern'
launch_body="$(heading_body "$ORCHESTRATOR" "$LAUNCH_HEADING" || true)"
if [ -z "$launch_body" ]; then
  fail "$ORCHESTRATOR has no \"$LAUNCH_HEADING\" section; there is no template to carry the model"
elif ! printf '%s\n' "$launch_body" | grep -qE "model:[[:space:]]*'?\{"; then
  fail "$ORCHESTRATOR's launch template declares no \`model:\` field; the phase model table would be decided and never passed"
fi

# M6 — the namespaced agents carry their own model, and a launch-time override silently wins over
# frontmatter. Both dispatch sites must say so, or the next reader passes the phase model to a
# review lens and quietly overrides the nine declarations M1 protects.
for f in "$ORCHESTRATOR" "$REVIEW"; do
  if [ ! -f "$f" ]; then
    fail "$f is missing; one of the two dispatch sites cannot state the no-override rule"
    continue
  fi
  if ! grep -iE 'model' "$f" | grep -qiE "$NEGATION"; then
    fail "$f states no prohibition on overriding an agent's declared model; a launch-time override wins over frontmatter"
  fi
done

# M7 — the README is the plugin's only user-facing surface, and its per-agent model is compared
# against the frontmatter instead of maintained by hand. A reader choosing this plugin for its
# cost profile is reading the table, so the table is checked like a claim, not like prose.
if [ ! -f "$README" ]; then
  fail "$README is missing; the plugin's cost profile is undocumented"
else
  # Driven from the files on disk, not from whatever the table happens to publish: a row that
  # loses its model cell drops out of a table-driven scan silently, and one agent quietly
  # undocumented is exactly the drift this assertion is for.
  readme_rows="$(
    heading_body "$README" '## Agents' |
      sed -nE 's/^\|[[:space:]]*`([a-z][a-z0-9-]*)`.*\|[[:space:]]*`?([A-Za-z0-9_.-]+)`?[[:space:]]*\|[[:space:]]*$/\1 \2/p' || true
  )"
  if [ -z "$readme_rows" ]; then
    fail "$README's \"## Agents\" table publishes no model column; the reader cannot see which agent costs what"
  else
    while IFS= read -r f; do
      [ -n "$f" ] || continue
      name="$(basename "$f" .md)"
      declared="$(model_of "$f")"
      published="$(printf '%s\n' "$readme_rows" | awk -v n="$name" '$1 == n {print $2; exit}')"
      if [ -z "$published" ]; then
        fail "$README's agents table publishes no model for $name; the row lost its cell or the agent is undocumented"
      elif [ "$published" != "$declared" ]; then
        fail "$README publishes \"$published\" for $name while $f declares \"$declared\""
      fi
    done <<EOF
$agent_files
EOF
  fi
fi

report

echo "check-models: OK — $(printf '%s\n' "$agent_files" | grep -c .) agents and $(printf '%s\n' "$table_phases" | grep -c .) phase delegates carry an explicit model"
