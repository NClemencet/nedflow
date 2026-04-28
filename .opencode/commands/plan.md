---
description: Phase 2 - write an executable TDD plan to .claude/plans/<date>-<slug>.md based on the brainstorm note
agent: build
---

# Plan

**Announce first:** start your response with the literal line `**[nedflow:plan] Phase 2: Plan**` so the user sees the command fired.

Produce an executable plan. Every task must be runnable by a subagent with zero context from this conversation.

## Input

`$ARGUMENTS` - a slug matching an existing brainstorm file (preferred), or a fresh feature name.

## Protocol

1. **Locate brainstorm** - look for `.claude/plans/*-$ARGUMENTS.brainstorm.md` (most recent if multiple). If found, read it. If not, proceed from conversation context but warn that a brainstorm is recommended.
2. **Research codebase** - dispatch the built-in `explore` subagent via the `task` tool to verify file paths, check the test framework and patterns in use, find import conventions, and confirm whether any planned utilities already exist. Use those findings to fill the Files section and task sketches accurately.
3. **Derive plan path** - same slug as brainstorm, today's date: `.claude/plans/YYYY-MM-DD-<slug>.md`. If no brainstorm, slug from `$ARGUMENTS`.
4. **Resolve gaps** - if brainstorm is missing key decisions (test framework, file layout, error handling style, breaking-change policy), use the `question` tool to fill them. Bounded axes only; free-text for naming or paths.
5. **Draft plan** using the template below.
6. **Self-check** before writing: every task has an exact test, exact code intent, exact commit message. No `TODO`, no `tbd`. If you cannot fill a section, ask via `question` rather than fabricating.
7. **Write file**.

## Plan template

```markdown
# Plan: <feature>

**Date:** YYYY-MM-DD
**Brainstorm:** .claude/plans/<date>-<slug>.brainstorm.md
**Goal:** <one sentence>

## Files

- Create: `path/to/new.ext`
- Modify: `path/to/existing.ext`

## Out of scope

- <bullet>

## Tasks

### Task 1: <short title>

**Touches:** `path/a.ext`, `path/b.test.ext`

- [ ] **Red:** write failing test in `path/b.test.ext`:
  ```<lang>
  <exact test code, or precise description if code too long>
  ```
  Run: `<exact command>` -> expect fail with message containing `<substring>`.
- [ ] **Green:** implement minimum in `path/a.ext` to pass the test.
  Run: `<exact command>` -> expect pass.
- [ ] **Verify:** run full relevant suite: `<command>` -> all green.
- [ ] **Commit:** `<type>(<scope>): <imperative description>`

### Task 2: ...

(same structure)

## Done criteria

- All task checkboxes ticked
- Full test suite green
- No stray debug prints / commented code
- Branch ready for `/review <base-branch>`
```

## Rules

- Prefer the `question` tool (1-4 questions, 2-4 options each) over free-text for any decision with discrete choices. Batch related questions in a single call.
- Every task ends with a commit. Commits stay atomic.
- Commit format: `type(scope): description` (imperative, lowercase, no period). Types: `feat|fix|refactor|docs|chore|test`. Bullets after blank line for details. No `Co-Authored-By`.
- Tasks must be executable independently by a subagent reading only the plan file.
- Prefer 3-7 tasks. If more than 10, re-scope - likely too large for a single branch.

## Exit

Print the plan path. Ask: `Plan written to <path>. Run /tdd <path> to execute?`
