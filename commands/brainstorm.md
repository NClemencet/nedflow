---
description: Phase 1 — refine a feature idea via 2-3 proposals, surface trade-offs, record outcome to .claude/plans/<date>-<slug>.brainstorm.md
argument-hint: <feature idea>
---

# Brainstorm

Refine the user's idea until scope, constraints and success criteria are unambiguous. No implementation code. Produce a brainstorm note at the end.

## Input

User feature idea: `$ARGUMENTS`

## Protocol

1. **Restate** the idea in one sentence. Confirm with user.
2. **Research** the codebase if needed (Grep/Glob/Read) to check existing patterns, conflicts, reusable pieces. Keep it bounded — don't read the whole repo.
3. **Propose 2-3 approaches** (variable — typically 3, but use 2 if the space is narrow or 4 if genuinely distinct branches exist). Each proposal:
   - **Approach name** (short)
   - **How it works** (2-3 sentences)
   - **Pros / Cons** (bullets)
   - **Rough effort** (S/M/L)
   - **Risks**
4. **Ask high-leverage questions** only. Skip yes/no questions whose answer doesn't change the chosen approach. Skip questions already answered by the codebase.
5. **Wait for user pick**. Do not proceed without explicit choice.
6. **Write brainstorm file** (see below).

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

**Option <X>** — <rationale in 1-2 sentences>

## Open questions resolved

- Q: ... → A: ...

## Out of scope

- <bullet>

## Next step

Run `/plan <slug>` to generate the implementation plan.
```

## Exit

Print the brainstorm file path. Suggest: `/plan <slug>` next.
