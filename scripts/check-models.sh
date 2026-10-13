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

# The only dispatch identifier that resolves to a declared agent. An un-namespaced value reaches
# no frontmatter at all, so nothing can carry a declared model to the running subagent.
NAMESPACE="subagent_type: 'spec-driven-dev:"

# The retired identifier. It resolves to nothing in this runtime, so every surviving copy is both
# a broken dispatch and a reader's excuse to believe the no-override rule binds only half the set.
RETIRED_TYPE="subagent_type: 'general'"

# The marker each phase body opens its gate block with. Matched by name, never by its full line:
# the full line's canon lives in check-envelope.sh, and a second copy here is the drift both
# scripts were written to prevent.
GATE_MARKER='**ORCHESTRATOR GATE**'

# Stand-in for a phase's own name. Each gate block must now name its own agent, so the blocks
# cannot be compared byte for byte until that one identity token is normalized away — the same
# weakening check-judges.sh applies to the two blind judges.
GATE_PLACEHOLDER='sdd-PHASE'

# The five phases that draft artifacts and must never reach a shell, and the five that must, each
# named rather than counted: a bare count stays green while a name silently drops out of the set.
DRAFTING_PHASES='sdd-explore sdd-propose sdd-spec sdd-design sdd-tasks'
EXECUTION_PHASES='sdd-apply sdd-verify sdd-init sdd-debug sdd-archive'

# The tier each phase ran on when its declaration moved out of the orchestrator's table and into
# its own agent file. M7 only proves the README agrees with the frontmatter, so a retier written to
# both stays green there; this is the copy that makes a tier change a deliberate edit to this line
# rather than a side effect of editing two documents in step.
PHASE_TIERS='sdd-explore=sonnet sdd-propose=sonnet sdd-spec=sonnet sdd-design=opus sdd-tasks=sonnet sdd-apply=opus sdd-verify=sonnet sdd-archive=haiku sdd-init=haiku sdd-debug=opus'

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

tools_line() { # file — the whole `tools:` value, empty when absent
  frontmatter "$1" | sed -nE 's/^tools:[[:space:]]*//p' | head -1
}

gate_block() { # phase name — its gate block, with its own name normalized to the placeholder
  awk -v m="$GATE_MARKER" 'index($0, m) && /^>/ { f = 1 } f && !/^>/ { exit } f' "skills/$1/SKILL.md" |
    sed "s/$1/$GATE_PLACEHOLDER/g"
}

# The repo-wide markdown set, written in check-envelope.sh:104-110's idiom and deliberately the
# same set, so the two checkers cannot disagree about what "repo-wide" means.
scan_files="$(
  {
    find skills agents commands -type f -name '*.md' 2>/dev/null || true
    for f in README.md AGENTS.md; do
      if [ -f "$f" ]; then echo "$f"; fi
    done
  } | sort -u
)"

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

if [ ! -f "$ORCHESTRATOR" ]; then
  fail "$ORCHESTRATOR is missing; the launch rule has no home"
  report
fi

# M5 — INVERTED. Before the phase delegates had frontmatter the template was required TO carry a
# model field, because nothing else could reach the running subagent. Now every agent declares its
# own and a launch-time argument silently WINS over the declaration, so the same field became the
# regression: the assertion that demanded it now forbids it. The match is anchored at line start
# for the same reason frontmatter() reads only the frontmatter — a prose sentence about a `model`
# argument is documentation, and only a line-initial key is a field being passed.
LAUNCH_HEADING='## Sub-Agent Launching Pattern'
launch_body="$(heading_body "$ORCHESTRATOR" "$LAUNCH_HEADING" || true)"
if [ -z "$launch_body" ]; then
  fail "$ORCHESTRATOR has no \"$LAUNCH_HEADING\" section; there is no launch template to check"
else
  # The template is the first fenced block of the section, never the section as a whole: the same
  # section closes with a namespaced review-agent example, which would satisfy this clause on the
  # template's behalf no matter what the template dispatches.
  launch_template="$(printf '%s\n' "$launch_body" | awk '/^```/ { if (f) exit; f = 1; next } f')"
  if [ -z "$launch_template" ]; then
    fail "$ORCHESTRATOR's \"$LAUNCH_HEADING\" section has no fenced launch template; there is no dispatch to check"
  elif ! printf '%s\n' "$launch_template" | grep -qF "${NAMESPACE}sdd-{phase}'"; then
    fail "$ORCHESTRATOR's launch template does not dispatch \`${NAMESPACE}sdd-{phase}'\`; an un-namespaced launch reaches no frontmatter and inherits the session model"
  fi
  if printf '%s\n' "$launch_body" | grep -qE '^[[:space:]]*model:'; then
    fail "$ORCHESTRATOR's launch template declares a \`model:\` field; frontmatter declares the model and a launch-time argument silently overrides all nineteen declarations"
  fi
fi

# M6 — the namespaced agents carry their own model, and a launch-time override silently wins over
# frontmatter. Both dispatch sites must say so, or the next reader passes the phase model to a
# review lens and quietly overrides the declarations M1 protects. The imperative itself is what is
# matched, not any line pairing `model` with a negation: each site also explains the rule in
# sentences of that shape, and those would keep this green with the instruction gone.
PROHIBITION='[Pp]ass NO `?model`?'
for f in "$ORCHESTRATOR" "$REVIEW"; do
  if [ ! -f "$f" ]; then
    fail "$f is missing; one of the two dispatch sites cannot state the no-override rule"
    continue
  fi
  if ! grep -qE "$PROHIBITION" "$f"; then
    fail "$f does not instruct \"pass NO model\"; a launch-time override wins over frontmatter, and only the imperative stops one"
  fi
done

# M6d — the retired assignment table stays retired, in every tracked file. Its return would be a
# second place to read a phase's tier from, and the one the launch template used to pass as an
# argument.
RETIRED_HEADING='## Phase Model Assignment'
tracked_files="$(git ls-files --cached --others --exclude-standard 2>/dev/null || true)"
if [ -z "$tracked_files" ]; then
  tracked_files="$scan_files"
fi
retired_heading_sites="$(
  printf '%s\n' "$tracked_files" |
    while IFS= read -r f; do
      [ -f "$f" ] || continue
      if grep -qIE "^${RETIRED_HEADING}[[:space:]]*\$" "$f"; then echo "$f"; fi
    done | sort -u
)"
if [ -n "$retired_heading_sites" ]; then
  fail "$(printf '%s' "$retired_heading_sites" | tr '\n' ' ' | sed 's/ *$//;s/ /, /g') still carry the retired \"$RETIRED_HEADING\" heading; each phase's tier is declared in its agent file and nowhere else"
fi

# M6b — and nowhere in the repo still instructs the retired identifier. While that literal
# survives anywhere, a reader can still read the no-override rule as binding the namespaced
# agents only, which is the asymmetry this assignment removed.
retired_sites="$(
  printf '%s\n' "$scan_files" |
    while IFS= read -r f; do
      [ -n "$f" ] || continue
      if grep -qF "$RETIRED_TYPE" "$f"; then echo "$f"; fi
    done | sort -u
)"
if [ -n "$retired_sites" ]; then
  fail "$(printf '%s' "$retired_sites" | tr '\n' ' ' | sed 's/ *$//;s/ /, /g') still instruct \`$RETIRED_TYPE\`, which resolves to no registered agent"
fi

# M6c — and no dispatch site anywhere pairs a namespaced `subagent_type` with a `model:` field.
# M5 covers the orchestrator's own template; this covers every other `Task(` block, present or
# added later, since the override is silent and leaves nothing to notice afterwards.
overrides="$(
  printf '%s\n' "$scan_files" |
    while IFS= read -r f; do
      [ -n "$f" ] || continue
      awk -v file="$f" '
        /Task\(/ { block = 1; namespaced = 0; has_model = 0 }
        block && /subagent_type:[^,)]*:/ { namespaced = 1 }
        block && /^[[:space:]]*model:/ { has_model = 1 }
        block && /\)/ {
          if (namespaced && has_model) { print file ":" NR }
          block = 0
        }
      ' "$f"
    done
)"
if [ -n "$overrides" ]; then
  fail "$(printf '%s' "$overrides" | tr '\n' ' ' | sed 's/ *$//;s/ /, /g') pass a \`model:\` field to a namespaced agent, silently overriding its own declaration"
fi

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

# M8 — one agent file per phase body and one phase body per agent file. Neither side is
# hardcoded: the agent side is the directory, the skill side is derived from the gate marker, so
# adding a phase body without promoting it fails loudly instead of leaving an identifier that
# dispatches to nothing. Both directions, because a one-sided subset check rewards deletion.
phase_agents="$(find agents -maxdepth 1 -name 'sdd-*.md' -exec basename {} .md \; 2>/dev/null | sort -u || true)"
phase_skills="$(
  printf '%s\n' "$scan_files" |
    grep -E '^skills/[^/]+/SKILL\.md$' |
    while IFS= read -r f; do
      [ -n "$f" ] || continue
      if grep -qF "$GATE_MARKER" "$f"; then echo "$f"; fi
    done |
    sed -E 's|^skills/||; s|/SKILL\.md$||' |
    sort -u
)"

if [ -z "$phase_agents" ] || [ -z "$phase_skills" ]; then
  fail "the phase roster is empty on one side (agent files: ${phase_agents:-none}; gate-carrying phase bodies: ${phase_skills:-none}); the bijection would be asserted against nothing"
  report
fi

orphan_agents="$(comm -23 <(printf '%s\n' "$phase_agents") <(printf '%s\n' "$phase_skills") | tr '\n' ' ' | sed 's/ *$//;s/ /, /g')"
unpromoted="$(comm -13 <(printf '%s\n' "$phase_agents") <(printf '%s\n' "$phase_skills") | tr '\n' ' ' | sed 's/ *$//;s/ /, /g')"
if [ -n "$orphan_agents" ] || [ -n "$unpromoted" ]; then
  fail "agents/ and the phase bodies are not a bijection: agent with no phase body: ${orphan_agents:-none}; phase body with no agent: ${unpromoted:-none}"
fi

# Set equality cannot see a crossed pointer: two files may both exist and each cite the other's
# body. The message reports what the file does cite, which is the difference between a usable
# failure and a puzzle.
while IFS= read -r name; do
  [ -n "$name" ] || continue
  own="skills/$name/SKILL.md"
  if ! grep -qF "$own" "agents/$name.md"; then
    cited="$(grep -oE 'skills/[a-z0-9-]+/SKILL\.md' "agents/$name.md" | head -1 || true)"
    fail "agents/$name.md does not cite its own phase body $own; it cites ${cited:-nothing}"
  elif [ ! -f "$own" ]; then
    fail "agents/$name.md cites $own, which does not exist"
  fi
done <<EOF
$phase_agents
EOF

# And `name:` must equal the basename for all nineteen, not only the ten: the runtime resolves a
# namespaced dispatch on the declared name, so a mismatch means this suite and the runtime
# disagree about which agents exist.
while IFS= read -r f; do
  [ -n "$f" ] || continue
  base="$(basename "$f" .md)"
  declared_name="$(frontmatter "$f" | sed -nE 's/^name:[[:space:]]*//p' | head -1 | tr -d "\"'" | sed -E 's/[[:space:]]+$//')"
  if [ "$declared_name" != "$base" ]; then
    fail "$f declares name: ${declared_name:-nothing} but its basename is $base; the namespaced dispatch would not resolve"
  fi
done <<EOF
$agent_files
EOF

# M9 — the ten gate blocks each name their own agent, and are otherwise the same block. Comparing
# after normalizing only this file's own name is what gives containment teeth: a crossed launch
# line leaves the other phase's name un-normalized and fails both clauses at once.
gate_digests=""
while IFS= read -r name; do
  [ -n "$name" ] || continue
  block="$(gate_block "$name")"
  if [ -z "$block" ]; then
    fail "skills/$name/SKILL.md has no gate block under the $GATE_MARKER marker; a deleted block is not a passing one"
    continue
  fi
  if ! printf '%s\n' "$block" | grep -qF "$NAMESPACE$GATE_PLACEHOLDER'"; then
    fail "skills/$name/SKILL.md's gate block does not launch \`$NAMESPACE$name'\`; it dispatches something other than its own agent"
    continue
  fi
  gate_digests="${gate_digests}${gate_digests:+$'\n'}$(printf '%s\n' "$block" | cksum | tr -d ' \t') $name"
done <<EOF
$phase_skills
EOF

# The reference is the block most phases share, not whichever sorts first: when the first file is
# the one that drifted, comparing against it blames every file that did not.
if [ -n "$gate_digests" ]; then
  shared_digest="$(printf '%s\n' "$gate_digests" | awk '{ print $1 }' | sort | uniq -c | sort -k1,1nr -k2 | awk 'NR == 1 { print $2 }')"
  shared_count="$(printf '%s\n' "$gate_digests" | awk -v d="$shared_digest" '$1 == d' | grep -c .)"
  ref_name="$(printf '%s\n' "$gate_digests" | awk -v d="$shared_digest" '$1 == d { print $2; exit }')"
  ref_block="$(gate_block "$ref_name")"
  while IFS=' ' read -r digest name; do
    [ -n "$name" ] || continue
    [ "$digest" != "$shared_digest" ] || continue
    fail "skills/$name/SKILL.md's gate block differs from the block $shared_count phases share (skills/$ref_name/SKILL.md) once the phase name is normalized: $(diff <(printf '%s\n' "$ref_block") <(gate_block "$name") | tr '\n' ' ' | sed 's/  */ /g' | cut -c1-200)"
  done <<EOF
$gate_digests
EOF
fi

# M10 — the frontmatter of a phase agent carries exactly four keys, in one order, and declares
# `tools:` as a scalar. A reordered or list-valued grant is not a style question: it changes how
# the runtime parses the grant, and a misparsed grant fails open, not closed.
EXPECTED_KEYS='name description tools model'
while IFS= read -r name; do
  [ -n "$name" ] || continue
  f="agents/$name.md"
  keys="$(frontmatter "$f" | sed -nE 's/^([A-Za-z_][A-Za-z0-9_-]*):.*/\1/p' | tr '\n' ' ' | sed 's/ *$//')"
  if [ "$keys" != "$EXPECTED_KEYS" ]; then
    fail "$f declares frontmatter keys \"${keys:-none}\"; expected exactly \"$EXPECTED_KEYS\", in that order"
  fi
  if [ -z "$(tools_line "$f")" ]; then
    fail "$f declares an empty \`tools:\` value; a grant nobody can read is the unrestricted default back"
  fi
  if frontmatter "$f" | awk '/^tools:/ { t = 1; next } /^[A-Za-z_][A-Za-z0-9_-]*:/ { t = 0 } t' | grep -qE '^[[:space:]]*-[[:space:]]'; then
    fail "$f declares \`tools:\` as a YAML list; the grant must be one scalar line, which is the shape every other agent in this plugin uses"
  fi
done <<EOF
$phase_agents
EOF

# M11 — the five drafting phases reach no shell. They read, search and write artifacts; a `Bash`
# grant would let a drafting phase run the project's code, which is the privilege creep this
# assertion exists to catch. The whole file is searched, not only the grant line: the word appears
# in no agent body, so a hit anywhere is a hit in the grant.
for name in $DRAFTING_PHASES; do
  f="agents/$name.md"
  if [ ! -f "$f" ]; then
    fail "$f is missing; the no-shell guarantee for the drafting phases cannot be asserted"
    continue
  fi
  if grep -qF 'Bash' "$f"; then
    fail "$f names \`Bash\`; the five drafting phases draft artifacts and must not reach a shell"
  fi
done

# M12 — and the five execution phases do carry it, each named. sdd-archive belongs here: its
# grant is real, not an oversight, and a check narrowed back to four names would drop it while
# staying green. Read from the grant line alone, so no prose can satisfy it on a file's behalf.
for name in $EXECUTION_PHASES; do
  f="agents/$name.md"
  if [ ! -f "$f" ]; then
    fail "$f is missing; one of the five execution phases has no grant to check"
    continue
  fi
  if ! tools_line "$f" | grep -qF 'Bash'; then
    fail "$f's \`tools:\` line does not grant \`Bash\`; this phase runs commands and would fail at its first one"
  fi
done

# M13 — every Engram tool is declared under both server prefixes. A prefix with no server behind
# it is dropped silently rather than reported, so a single-prefix declaration loses the tool with
# no error under the other install shape — a failure that looks exactly like the phase choosing
# not to persist.
while IFS= read -r name; do
  [ -n "$name" ] || continue
  f="agents/$name.md"
  engram_tokens="$(grep -oE 'mcp__[a-z_]*engram[a-z_]*' "$f" | sort -u || true)"
  if [ -z "$engram_tokens" ]; then
    fail "$f declares no Engram tool under either prefix; the parity assertion would pass vacuously"
    continue
  fi
  plain="$(printf '%s\n' "$engram_tokens" | sed -nE 's/^mcp__engram__(mem_[a-z_]+)$/\1/p' | sort -u)"
  plugin="$(printf '%s\n' "$engram_tokens" | sed -nE 's/^mcp__plugin_engram_engram__(mem_[a-z_]+)$/\1/p' | sort -u)"
  plugin_only="$(comm -13 <(printf '%s\n' "$plain") <(printf '%s\n' "$plugin") | grep -v '^$' | tr '\n' ' ' | sed 's/ *$//;s/ /, /g' || true)"
  plain_only="$(comm -23 <(printf '%s\n' "$plain") <(printf '%s\n' "$plugin") | grep -v '^$' | tr '\n' ' ' | sed 's/ *$//;s/ /, /g' || true)"
  if [ -n "$plain_only" ] || [ -n "$plugin_only" ]; then
    fail "$f declares Engram tools under one prefix only: missing mcp__plugin_engram_engram__ for ${plain_only:-none}; missing mcp__engram__ for ${plugin_only:-none}"
  fi
done <<EOF
$phase_agents
EOF

# M14 — each phase agent declares exactly the tier PHASE_TIERS sanctions for it.
for pair in $PHASE_TIERS; do
  name="${pair%%=*}"
  tier="${pair#*=}"
  f="agents/$name.md"
  if [ ! -f "$f" ]; then
    fail "$f is missing; the sanctioned $tier tier for $name has no declaration to check"
    continue
  fi
  value="$(model_of "$f")"
  if [ "$value" != "$tier" ]; then
    fail "$f declares \"${value:-nothing}\" but the sanctioned tier for $name is \"$tier\"; a retier is a decision, made by editing PHASE_TIERS, never a drift"
  fi
done

report

echo "check-models: OK — $(printf '%s\n' "$agent_files" | grep -c .) agents carry an explicit model; $(printf '%s\n' "$phase_agents" | grep -c .) pair 1:1 with their phase body"
