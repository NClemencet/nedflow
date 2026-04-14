---
description: Phase 4 — parallel multi-angle review (security, refactor, bugs) of the diff vs a base branch, aggregated report with severity
argument-hint: <base-branch>
---

# Review

**Announce first:** start your response with the literal line `**[nedflow:review] Phase 4: Review**` so the user sees the command fired.

Spawn three review sub-agents in parallel. Aggregate findings by severity into `.claude/reviews/<current-branch>-<date>.md`.

## Input

`$ARGUMENTS` — base branch (required, e.g. `main`, `origin/develop`). No default — user must specify.

If missing: ask the user once, then abort if still missing. Do not assume.

## Protocol

1. **Resolve scope**:
   - Current branch: `git rev-parse --abbrev-ref HEAD`
   - Diff range: `$ARGUMENTS...HEAD`
   - Verify base exists: `git rev-parse --verify $ARGUMENTS` — abort with message if it fails.
2. **Track progress:** `TaskCreate` with three entries: `security review`, `refactor review`, `bug hunt`. All start `status: pending`.
3. **Mark all three `in_progress`** via `TaskUpdate` (parallel dispatch).
4. **Spawn 3 sub-agents IN PARALLEL** (single message, three `Agent` tool calls):
   - `security-reviewer`
   - `refactor-reviewer`
   - `bug-hunter`
   As each returns, `TaskUpdate` the matching entry → `completed`.
5. **Each sub-agent receives this prompt shape**:
   ```
   Review the diff of the current branch vs base `<base>`.

   Commands to run:
   - git diff <base>...HEAD
   - git diff <base>...HEAD --stat
   - git log <base>..HEAD --oneline

   Focus: <security | refactor | bugs> only. Do NOT comment on other categories.

   For each finding, output exactly:
   - [<CRITICAL|HIGH|MEDIUM|LOW>] <path>:<line> — <one-line problem> → <concrete fix>

   If none: output exactly `NO FINDINGS`.

   Return the raw finding list. No preamble.
   ```
6. **Collect results**. Merge into a single report, grouped by severity (CRITICAL → HIGH → MEDIUM → LOW). Within each group, group by category (security / refactor / bugs).
7. **Write** `.claude/reviews/<branch>-YYYY-MM-DD.md`. Create `.claude/reviews/` if absent.

## Report format

```markdown
# Review: <branch> vs <base>

**Date:** YYYY-MM-DD
**Commits:** <N> (`git log <base>..HEAD --oneline` output)
**Files changed:** <N>

## Summary

- CRITICAL: <count>
- HIGH: <count>
- MEDIUM: <count>
- LOW: <count>

## CRITICAL

### Security
- <path>:<line> — <problem> → <fix>

### Bugs
- ...

## HIGH

...

## MEDIUM

...

## LOW

...

## No findings

- <category>: clean
```

## Exit

Print the report path. If any CRITICAL or HIGH, recommend user address before merge. If clean, recommend merge.
