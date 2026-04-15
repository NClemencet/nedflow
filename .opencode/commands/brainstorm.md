---
description: Phase 1 - refine a feature idea via 2-3 proposals, surface trade-offs, record outcome to .claude/plans/<date>-<slug>.brainstorm.md
agent: build
---

# Brainstorm

**Announce first:** start your response with the literal line `**[nedflow:brainstorm] Phase 1: Brainstorm**` so the user sees the command fired.

Refine the user's idea until scope, constraints and success criteria are unambiguous. No implementation code. Produce a brainstorm note at the end.

## Input

User feature idea: `$ARGUMENTS`

## Protocol

1. **Restate** the idea in one sentence. Confirm with user.
2. **Research** the codebase if needed (`grep`, `glob`, `read`) to check existing patterns, conflicts, reusable pieces. Keep it bounded.
3. **Propose 2-3 approaches** (variable - typically 3, but use 2 if the space is narrow or 4 if genuinely distinct branches exist). Each proposal:
   - **Approach name** (short)
   - **How it works** (2-3 sentences)
   - **Pros / Cons** (bullets)
   - **Rough effort** (S/M/L)
   - **Risks**
4. **Ask high-leverage questions** via the `question` tool (1-4 questions per call, 2-4 options each). Skip questions whose answer does not change the chosen approach. Skip questions already answered by the codebase. Examples of good axes: scope (MVP / full / experiment), persistence (memory / disk / DB), surface (CLI / web / both), priority (perf / DX / correctness).
5. **Pick approach** via the `question` tool: single-select, one option per proposal from step 3, label = approach name, description = 1-line summary + effort tag. Do not proceed without an explicit selection.
6. **Write brainstorm file** (see below).

## Interaction style

- Prefer the `question` tool over free-text Q&A whenever choices are discrete and bounded.
- Free-text only when the answer is genuinely open-ended (for example naming or exact constraint values).
- Batch related questions in a single `question` call (max 4) to minimize interruptions.

## Output file

After user selects an approach, determine the slug:
- Extract 3-5 words from feature description, kebab-case, lowercase
- Prefix with today's date (YYYY-MM-DD)
- Path: `.claude/plans/YYYY-MM-DD-<slug>.brainstorm.md`

Create `.claude/plans/` if absent. Suggest user add it to `.gitignore` if they want brainstorm/plan notes kept local.

Content template:

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

**Option <X>** - <rationale in 1-2 sentences>

## Open questions resolved

- Q: ... -> A: ...

## Out of scope

- <bullet>

## Next step

Run `/plan <slug>` to generate the implementation plan.
```

## Exit

Print the brainstorm file path. Suggest: `/plan <slug>` next.
