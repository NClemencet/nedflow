---
description: Targeted bug investigation and fix. Short-circuits brainstorm/plan. Writes a failing unit test when reproducible, then drives a fix via tdd-executor.
argument-hint: <bug description>
---

# Debugging

**Announce first:** start your response with the literal line `**[nedflow:debugging] Debug**` so the user sees the command fired.

Fast path for bugs. Investigate → reproduce → red test → green fix → commit.

## Input

`$ARGUMENTS` — bug description, ideally with repro steps, expected vs actual, error messages.

## Protocol

0. **Track progress:** after the clarify step (if any), `TaskCreate` four entries: `investigate`, `reproduce in test`, `fix`, `verify`. Update `in_progress` / `completed` as you move through the protocol. Skip `reproduce in test` entry (mark `completed` with note) if the bug is not reproducible in code per step 4 below.
1. **Clarify** (only if essential): use `AskUserQuestion` for bounded axes — e.g., reproducibility (always / intermittent / unknown), surface (logic / UI / network / build), severity (blocker / regression / minor). Free-text only for raw repro steps or error output. One round max.
2. **Investigate**:
   - Grep for error strings, function names, recent touched files
   - Read relevant code
   - Consider `git log --oneline -- <file>` for recent changes to suspect files
   - If regression suspected, propose `git bisect` — do not run without user approval
3. **Root cause** — state it in one sentence before writing any code. If unclear, investigate more. Do not guess-fix.
4. **Reproduce in a unit test**:
   - **If the bug is reproducible as a unit/integration test** (logic error, wrong output, boundary, state): write a failing test that captures the exact wrong behaviour. This is the RED step.
   - **If not reproducible in code** (UI-only race, intermittent network, environmental): document the investigation and manual repro in `.claude/plans/YYYY-MM-DD-<slug>.debugging.md`, then proceed to fix without an automated test. Note the gap explicitly in the commit body.
5. **Fix via sub-agent**:
   - Spawn `tdd-executor` with the failing test already in place (or without, if non-reproducible). Prompt:
     ```
     Fix the bug described below. <If test exists:> A failing test at <path> captures it.

     Bug: <root cause sentence>
     Expected: <behaviour>
     Actual: <behaviour>

     Steps:
     1. <If test:> Run the failing test, verify it fails for the stated reason.
     2. Write the minimum fix.
     3. Run the test (if any) and full relevant suite. All green.
     4. Commit: `fix(<scope>): <imperative description>`

     No Co-Authored-By. No --amend. Return summary, commit SHA, any regression risk.
     ```
6. **Verify**: parent runs `git log -1` and full test suite again.
7. **Regression watch**: if bug suggests a pattern, grep for similar constructs elsewhere. Report without fixing — that is a follow-up task, not part of this fix.

## Output

Commit SHA + one-sentence summary. If non-reproducible, include the `.claude/plans/*.debugging.md` path.

## Rules

- Prefer `AskUserQuestion` over free-text whenever choices are discrete. Batch related questions (max 4) in a single call.
- One bug → one commit. No drive-by cleanup.
- Never disable or delete the failing test once green.
- If root cause is unclear, investigate more — do not ship a fix for a symptom.
