# Domain Contract (shared across SDD skills)

One canon for a project's domain language and its durable decisions. Consumers cite this file
by path and section (`domain-contract.md` §N); they never copy its rules.

## 1. Files and Layout

- Single context: one `GLOSSARY.md` at the repository root.
- Multi-context: `GLOSSARY-MAP.md` at the root lists each context, the path of its
  `GLOSSARY.md`, and how the contexts relate.
- ADRs: `docs/adr/NNNN-slug.md` for system-wide decisions; in the map layout, also
  `{context}/docs/adr/` for decisions scoped to one context.
- Numbering: `NNNN` is the highest existing four-digit number in `docs/adr/` plus one,
  zero-padded to four digits. The first ADR is `0001`. A gap is never refilled.
- Lazy creation: no domain file exists until the first term is resolved or the first ADR is
  accepted. Never create placeholders.
- Layout inference: map when `GLOSSARY-MAP.md` exists; otherwise single when a root
  `GLOSSARY.md` exists; otherwise absent. Monorepo signals only inform which context to ask
  about when the first term arrives.
- The layout recorded by `sdd-init` is a hint; the filesystem is the authority. Check that a
  file exists before reading it.
- Domain files are project knowledge, not SDD artifacts: never a registered artifact type, and
  never moved at archive.
- The upstream discipline renamed its glossary from `CONTEXT.md` to `GLOSSARY.md`; the old name
  is not used here.

## 2. Consumption

- Before exploring, read `GLOSSARY.md` (or `GLOSSARY-MAP.md`, then the glossary of each context
  the work touches) and the ADRs under `docs/adr/` that touch the area.
- When the files are absent, proceed silently: do not flag the absence, and never suggest
  creating them upfront.
- Use the glossary's terms in everything you produce: titles, requirement names, test names,
  identifiers. Never use a synonym the glossary lists under `_Avoid_`.
- A concept you need that the glossary lacks is a signal: either the language is invented
  (reconsider it) or the glossary has a real gap (propose a term, §3).
- Never contradict an ADR silently. Flag it explicitly, in this form:
  `_Contradicts ADR-NNNN ({title}), but worth reopening because…_`

## 3. Roles and Writes

- The orchestrator is the only writer of domain files
  (`skills/sdd-orchestrator/SKILL.md` Rule 10(c)). Where each mode lets it write is set by
  `skills/_shared/persistence-contract.md` "Domain Files".
- Phase sub-agents are read-only on domain files in every mode. They never create or modify
  `GLOSSARY.md`, `GLOSSARY-MAP.md`, anything under `docs/adr/` or, in the map layout,
  anything under `{context}/docs/adr/`; they propose instead.
- Proposals travel in a `### Domain Candidates` subsection of the phase's `detailed_report`,
  omitted when empty, one line per candidate in these shapes:

```markdown
### Domain Candidates
- Term: **{Term}**: {one or two sentence definition}. _Avoid_: {synonyms}. Seen in: {where}
- ADR: {short title}. Hard to reverse: {why}. Surprising: {why}. Trade-off: {alternatives weighed}
- Contradicts ADR-NNNN ({title}): {why it is worth reopening}
```

- The orchestrator relays the candidates to the user and writes only what the user accepts.

The phase pointer, carried verbatim as one line by every reading phase in its
`## Execution and Persistence Contract` section:

```text
Domain files: read and follow `skills/_shared/domain-contract.md` before you start.
```

The instruction-file snippet, one line the orchestrator adds to the user's existing `CLAUDE.md`
or `AGENTS.md` once the user accepts it:

```text
Domain language: read `GLOSSARY.md` (or `GLOSSARY-MAP.md`) and `docs/adr/` before working in this repo; use the glossary's terms and flag any contradiction with an ADR.
```

## 4. Glossary Entry Format

A glossary file takes this shape:

```markdown
# {Context name}

{One or two sentences on what this context covers.}

## Language

**Booking**: A person's claim on one slot of a provider's calendar, held until it is kept or released.
_Avoid_: reservation, appointment request
```

- Be opinionated: pick one word for each concept and list the others under `_Avoid_`.
- Each entry defines one term, in one or two sentences that say what the term IS, not what it
  does or how it is built.
- Domain terms only: words specific to this project, never general programming concepts.
- No implementation details: a glossary is not a spec and not a scratch pad. It names no file,
  function, table or field.
- Group entries under subheadings once clusters of terms emerge.
- Concepts only, never example records, names, identifiers or values. In a healthtech
  repository this means no PHI and nothing PHI-adjacent.

## 5. ADR Format and the Offer Test

- An ADR lives at `docs/adr/NNNN-slug.md`, numbered by the rule in §1.
- Its body is `# {title}` followed by one to three sentences: the context, the decision, and why.
  Add only what earns its place: a Status line (proposed, accepted, deprecated, or superseded by
  ADR-NNNN), the options considered, the consequences.

Offer an ADR only when ALL THREE conditions hold; when any one is missing, offer none:
1. Hard to reverse: undoing the decision later costs real work.
2. Surprising without context: a reader of the code would ask why it is this way.
3. The result of a real trade-off: a credible alternative was weighed and rejected.

What usually qualifies: the architectural shape; integration patterns between contexts;
technology choices that lock the project in; boundary and scope decisions, explicit refusals
included; deliberate deviations from the obvious path; constraints the code cannot show;
rejected alternatives that are not obvious.

A phase only offers an ADR, as a candidate under `### Domain Candidates` (§3). The orchestrator
asks the user and writes the ADR only when the user accepts it.

## 6. Active Discipline

The orchestrator applies this during the Phase 1 discovery conversation and at user gates:

- Challenge, immediately, a term the user uses in a way that conflicts with the glossary.
- Sharpen a vague or overloaded word into one canonical term, or into distinct terms when it
  names two concepts.
- Stress-test the relationships between terms with concrete edge-case scenarios.
- Contrast what the user describes with what the code does, using the findings of `sdd-explore`,
  and surface the gap. The orchestrator never reads source itself; when that evidence is
  missing, it launches `sdd-explore`.
- Write a resolved term immediately, one term per write; never batch terms to the end. In `none`
  mode, write only when the user explicitly asks (`skills/_shared/persistence-contract.md`
  "Domain Files").
- In the map layout, when the context of a term is unclear, ask which context it belongs to.

## 7. Limits and Maintenance

- This contract is self-policing, like the phase gate (`skills/_shared/sdd-status-contract.md`
  §12). Every phase agent keeps a write tool, so nothing stops a sub-agent from writing a
  glossary except this rule.
- `scripts/check-domain.sh` reads the phase pointer out of §3, checks that exactly the reading
  phases carry it verbatim, and checks that the rules of this file are present by anchor phrase.
  It checks that the rules are stated, never that they are obeyed.
- A rule changes here and nowhere else; consumers cite this file and never copy it.

---
Adapted from mattpocock/skills (github.com/mattpocock/skills) by Matt Pocock, MIT.
