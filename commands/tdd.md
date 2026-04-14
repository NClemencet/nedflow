---
description: Phase 3 — execute a plan task-by-task via tdd-executor sub-agents, atomic commits, 2 retries on failure
argument-hint: <plan file path or slug>
---

# TDD Execution

**Announce first:** start your response with the literal line `**[nedflow:tdd] Phase 3: TDD Execution**` so the user sees the command fired.

Dispatch each plan task to a fresh `tdd-executor` sub-agent. One task → one commit. Atomic.

## Input

`$ARGUMENTS` — absolute path to plan file, or slug. If slug, resolve `.claude/plans/*-$ARGUMENTS.md` (most recent).

## Protocol

1. **Read the plan**. Enumerate tasks. Confirm none already ticked unless resuming.
2. **Track progress:** call `TaskCreate` once with one entry per un-ticked plan task. Each entry's `content` is the task title from the plan. Initial `status: pending`. Keep the returned task IDs.
3. **For each un-ticked task N**:
   1. `TaskUpdate` the matching tracker entry → `status: in_progress`.
   2. Spawn sub-agent via `Agent` tool with `subagent_type: tdd-executor`.
   3. Prompt (self-contained — the sub-agent sees none of this conversation):
      ```
      Execute Task <N> from plan: <absolute plan path>

      Read the plan file. Execute ONLY Task <N>. Follow strict TDD:
      1. Red: write the failing test, run it, verify fails for the right reason.
      2. Green: minimum implementation to pass.
      3. Verify: run full relevant test suite.
      4. Stage task files ONLY (do NOT modify or stage the plan file), then commit.

      Commit format: `type(scope): description` (imperative, lowercase, no period).
      No `Co-Authored-By` line.

      Return under 150 words: summary, commit SHA, any deviation from the plan.

      On failure (test red after green, lint/typecheck error): retry up to 2 times. If still failing, return without committing and report the blocker.
      ```
   4. **Wait** for sub-agent return. Read summary.
   5. **Verify** from parent:
      - `git log -1 --format=%H%n%s` → matches reported SHA and the expected commit type.
      - `git show --stat HEAD` → only expected task files touched. Plan file must NOT appear.
   6. **On success:** `TaskUpdate` tracker entry → `status: completed`.
   7. **If sub-agent reported blocker**: stop. Leave tracker entry `in_progress`. Surface to user. Do not dispatch next task.
   8. **If verification fails** (wrong files, plan file accidentally staged): one corrective sub-agent with focused prompt. If it fails again, stop and surface. Tracker stays `in_progress`.
4. **Between tasks**: by default pause and let user say `continue` unless they requested non-stop (`--auto` or explicit).
5. **End (all tracker entries completed)**:
   1. Edit the plan file: tick every `- [ ]` → `- [x]`.
   2. `git add <plan file>` then commit: `chore(plan): complete <slug>`.
   3. Suggest `/review <base-branch>`.

## Hard rules

- Never edit code yourself. Dispatch, verify, repeat.
- Never skip the verification step. The sub-agent's summary describes intent, not outcome.
- Never amend a previous commit. Each task is a new commit.
- If a commit hook fails, the sub-agent fixes and creates a NEW commit. No `--amend`. No `--no-verify`.
