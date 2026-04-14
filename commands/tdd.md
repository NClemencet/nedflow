---
description: Phase 3 — execute a plan task-by-task via tdd-executor sub-agents, atomic commits, 2 retries on failure
argument-hint: <plan file path or slug>
---

# TDD Execution

Dispatch each plan task to a fresh `tdd-executor` sub-agent. One task → one commit. Atomic.

## Input

`$ARGUMENTS` — absolute path to plan file, or slug. If slug, resolve `.claude/plans/*-$ARGUMENTS.md` (most recent).

## Protocol

1. **Read the plan**. Enumerate tasks. Confirm none already ticked unless resuming.
2. **For each un-ticked task N**:
   1. Spawn sub-agent via `Agent` tool with `subagent_type: tdd-executor`.
   2. Prompt (self-contained — the sub-agent sees none of this conversation):
      ```
      Execute Task <N> from plan: <absolute plan path>

      Read the plan file. Execute ONLY Task <N>. Follow strict TDD:
      1. Red: write the failing test, run it, verify fails for the right reason.
      2. Green: minimum implementation to pass.
      3. Verify: run full relevant test suite.
      4. Tick Task <N> checkboxes in the plan file.
      5. Stage changes INCLUDING the plan file, then commit.

      Commit format: `type(scope): description` (imperative, lowercase, no period).
      No `Co-Authored-By` line.

      Return under 150 words: summary, commit SHA, any deviation from the plan.

      On failure (test red after green, lint/typecheck error): retry up to 2 times. If still failing, return without committing and report the blocker.
      ```
   3. **Wait** for sub-agent return. Read summary.
   4. **Verify** from parent:
      - `git log -1 --format=%H%n%s` → matches reported SHA and the expected commit type.
      - `git show --stat HEAD` → only expected files touched (incl. plan file).
      - Plan file shows Task N checkboxes ticked.
   5. **If sub-agent reported blocker**: stop. Surface to user. Do not dispatch next task.
   6. **If verification fails** (wrong files, missing plan update): one corrective sub-agent with focused prompt. If it fails again, stop and surface.
3. **Between tasks**: by default pause and let user say `continue` unless they requested non-stop (`--auto` or explicit).
4. **End**: all tasks ticked → suggest `/review <base-branch>`.

## Hard rules

- Never edit code yourself. Dispatch, verify, repeat.
- Never skip the verification step. The sub-agent's summary describes intent, not outcome.
- Never amend a previous commit. Each task is a new commit.
- If a commit hook fails, the sub-agent fixes and creates a NEW commit. No `--amend`. No `--no-verify`.
