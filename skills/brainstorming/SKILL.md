---
name: brainstorming
description: "Phase 1 of the nedflow pipeline. Use this BEFORE any creative work — new features, components, behavior changes. Refines intent, surfaces trade-offs via 2-3 approaches, records outcome to .claude/plans/<date>-<slug>.brainstorm.md. No implementation."
---

# Brainstorming

**Announce first:** start your response with the literal line `**[nedflow:brainstorm] Phase 1: Brainstorm**` so the user sees the skill fired.

Turn an idea into a shared design. Refine scope, constraints and success criteria until unambiguous. Walk the design tree, resolving dependencies one-by-one. For each question, provide your recommended answer.

<HARD-GATE>
Do NOT write code, scaffold files, or invoke an implementation skill until the user has explicitly picked an approach. This applies to every project regardless of perceived simplicity — "simple" tasks are where unexamined assumptions cause the most wasted work.
</HARD-GATE>

## Input

User feature idea: `$ARGUMENTS` (if invoked via `/brainstorm`) — otherwise use the user's latest message.

## Protocol

1. **Restate** the idea in one sentence. Confirm with user.
2. **Research** the codebase if needed — dispatch a `code-explorer` Agent (`subagent_type: code-explorer`) with a focused prompt: which patterns, files, or APIs to look for (existing helpers, naming conventions, conflicts). Include returned findings in the brainstorm file under "Research notes". Give the explorer specific questions; do not ask it to read the whole repo.
3. **Propose 2-3 approaches** (2 if narrow, up to 4 if genuinely distinct). Each:
   - **Approach name** (short)
   - **How it works** (2-3 sentences)
   - **Pros / Cons** (bullets)
   - **Rough effort** (S/M/L)
   - **Risks**
4. **Ask high-leverage questions** via `AskUserQuestion` (1-4 per call, 2-4 options each, "Other" auto-added). Skip questions the codebase already answers or whose answer doesn't change the approach. Good axes: scope (MVP / full / experiment), persistence (memory / disk / DB), surface (CLI / web / both), priority (perf / DX / correctness).
5. **Pick approach** via `AskUserQuestion`: single-select, one option per proposal, label = approach name, description = 1-line summary + effort tag. User can pick "Other" to redirect. Do not proceed without explicit selection.
6. **Write brainstorm file** (see below).

## Interaction style

- Prefer `AskUserQuestion` over free-text Q&A whenever choices are discrete and bounded. Fewer round-trips, clearer intent.
- Free-text only when the answer is genuinely open-ended (naming, exact constraint values).
- Batch related questions in a single `AskUserQuestion` call (max 4) to minimise interruptions.

## Design principles

- **YAGNI** — strip anything not required for success criteria.
- **Isolation** — units with one clear purpose, well-defined interfaces, testable independently.
- **Follow existing patterns** — explore current structure first. Include targeted cleanup only where it serves the current goal. No drive-by refactors.
- **Scope check** — if the idea spans multiple independent subsystems, flag it and help decompose before brainstorming a single sub-project.

## Output file

After user selects an approach, determine the slug:
- 3-5 words from the feature description, kebab-case, lowercase
- Prefix with today's date (`YYYY-MM-DD`)
- Path: `.claude/plans/YYYY-MM-DD-<slug>.brainstorm.md`

Create `.claude/plans/` if absent. Suggest user add it to `.gitignore` if they want notes kept local.

Template:

```markdown
# Brainstorm: <feature>

**Date:** YYYY-MM-DD
**Slug:** <slug>

## Original idea

<user's exact words>

## Research notes

- <finding 1 with file:line refs>
- <finding 2>

## Options considered

### Option A: <name>
- How: ...
- Pros: ...
- Cons: ...
- Effort: S|M|L

### Option B: <name>
...

## Chosen direction

**Option <X>** — <rationale in 1-2 sentences>

## Open questions resolved

- Q: ... → A: ...

## Out of scope

- <bullet>

## Next step

Run `/plan <slug>` to generate the implementation plan.
```

## Exit

Print the brainstorm file path. Suggest: `/plan <slug>` next. Do not proceed to planning or implementation in the same turn.
