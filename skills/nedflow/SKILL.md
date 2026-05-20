---
name: nedflow
description: "Use when the user asks for the nedflow workflow in Codex, including /brainstorm, /plan, /tdd, /review, /debugging, or phrases like nedflow brainstorm, nedflow plan, nedflow TDD, nedflow review, and nedflow debugging."
---

# nedflow for Codex

nedflow is a five-phase workflow for feature work and bug fixes:

```text
brainstorm -> plan -> tdd -> review
                 ^
          debugging shortcut
```

Use this skill as the Codex-native orchestration layer. The existing `brainstorming` and `test-driven-development` skills provide detailed phase discipline; this skill defines how the phases are invoked and tracked in Codex.

## Invocation mapping

- `/brainstorm <idea>` or `nedflow brainstorm <idea>`: run Phase 1.
- `/plan <slug-or-feature>` or `nedflow plan <slug-or-feature>`: run Phase 2.
- `/tdd <plan-path-or-slug>` or `nedflow tdd <plan-path-or-slug>`: run Phase 3.
- `/review <base-branch>` or `nedflow review <base-branch>`: run Phase 4.
- `/debugging <bug>` or `nedflow debugging <bug>`: run the debugging shortcut.

If the user asks for "nedflow" without naming a phase, infer the phase from context. If no phase is clear, ask which phase they want.

## Shared conventions

- Announce the phase with the exact prefix shown in that phase.
- Use Codex task tracking for multi-step phases.
- Prefer files under `.codex/nedflow/`:
  - Plans: `.codex/nedflow/plans/`
  - Reviews: `.codex/nedflow/reviews/`
- If the repository already contains `.claude/plans/` or the user references a Claude/OpenCode plan, read and reuse it rather than migrating it.
- Use today's date in `YYYY-MM-DD` format for generated files.
- Slugs are 3-5 words, lowercase, kebab-case.
- Commit subjects must follow: `type(scope): description`
  - Types: `feat|fix|docs|style|refactor|perf|test|chore|build|ci|revert`
  - Description starts lowercase and has no trailing period.
  - Do not use `--amend`, `--no-verify`, or `Co-Authored-By`.

## Phase 1: Brainstorm

Announce:

```text
**[nedflow:brainstorm] Phase 1: Brainstorm**
```

Use the `brainstorming` skill. Adapt only the output path to Codex:

```text
.codex/nedflow/plans/YYYY-MM-DD-<slug>.brainstorm.md
```

Do not implement. End by printing the brainstorm path and suggesting:

```text
nedflow plan <slug>
```

## Phase 2: Plan

Announce:

```text
**[nedflow:plan] Phase 2: Plan**
```

Produce an executable TDD plan. Every task must be runnable from the plan file alone.

Protocol:

1. Locate the brainstorm note:
   - Prefer `.codex/nedflow/plans/*-<slug>.brainstorm.md`.
   - Also check `.claude/plans/*-<slug>.brainstorm.md` for compatibility.
2. Research the codebase before writing the plan:
   - Identify test framework, commands, file layout, import style, and existing utilities.
   - Use local search/read commands first.
   - Use Codex sub-agents only when delegation is explicitly part of the user's requested nedflow workflow and the environment permits it.
3. Derive plan path:
   - `.codex/nedflow/plans/YYYY-MM-DD-<slug>.md`
4. Resolve missing decisions with concise user questions when a reasonable assumption would be risky.
5. Write the plan using this template:

```markdown
# Plan: <feature>

**Date:** YYYY-MM-DD
**Brainstorm:** <path or "none">
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
  `<exact test intent or code sketch>`
  Run: `<exact command>` -> expect fail with `<substring>`.
- [ ] **Green:** implement minimum in `path/a.ext` to pass.
  Run: `<exact command>` -> expect pass.
- [ ] **Verify:** run full relevant suite: `<command>` -> all green.
- [ ] **Commit:** `<type>(<scope>): <imperative description>`

## Done criteria

- All task checkboxes ticked
- Full relevant suite green
- No stray debug prints or unrelated edits
- Branch ready for `nedflow review <base-branch>`
```

Exit with the plan path and suggest:

```text
nedflow tdd <path>
```

## Phase 3: TDD Execution

Announce:

```text
**[nedflow:tdd] Phase 3: TDD Execution**
```

Follow the `test-driven-development` skill. Execute one unchecked task at a time.

Protocol:

1. Read the plan. Resolve a slug against the newest matching file in:
   - `.codex/nedflow/plans/*-<slug>.md`
   - `.claude/plans/*-<slug>.md`
2. Create a task tracker entry for each unchecked plan task.
3. For each task:
   - Mark it in progress.
   - Red: write the failing test and run the exact command from the plan.
   - Green: implement the minimum change to pass.
   - Verify: run the exact verify command from the plan.
   - Commit only the files touched by that task. Do not stage the plan file.
   - Mark the tracker entry complete.
4. Pause between tasks unless the user requested automatic execution.
5. After all tasks are complete:
   - Optionally tick the plan checkboxes in the local plan file.
   - Do not stage or commit the plan file; `.claude/` may be gitignored by the consumer repository.
   - Suggest `nedflow review <base-branch>`.

If Codex sub-agents are available and the user asked for the nedflow TDD workflow, each plan task may be delegated to a fresh worker. The worker prompt must include the absolute plan path, task number, red/green/verify/commit rules, and the requirement to avoid staging the plan file.

## Phase 4: Review

Announce:

```text
**[nedflow:review] Phase 4: Review**
```

Input is a required base branch, for example `main` or `origin/main`. Do not assume a default.

Protocol:

1. Resolve:
   - Current branch: `git rev-parse --abbrev-ref HEAD`
   - Base validity: `git rev-parse --verify <base>`
   - Diff range: `<base>...HEAD`
2. Review the diff from three angles:
   - Security: secrets, injection, auth, crypto, path traversal, unsafe deserialization.
   - Refactor: dead code, duplication, naming, stray debug, over-abstraction.
   - Bugs: edge cases, null handling, races, unhandled errors, resource leaks, missing tests.
3. Use parallel sub-agents when the user requested nedflow review and the environment permits delegation. Otherwise, perform the three passes locally.
4. Write:

```text
.codex/nedflow/reviews/<branch>-YYYY-MM-DD.md
```

Report format:

```markdown
# Review: <branch> vs <base>

**Date:** YYYY-MM-DD
**Commits:** <N>
**Files changed:** <N>

## Summary

- CRITICAL: <count>
- HIGH: <count>
- MEDIUM: <count>
- LOW: <count>

## CRITICAL

### Security
- <path>:<line> - <problem> -> <fix>

## HIGH

...

## No findings

- <category>: clean
```

Findings use severity `CRITICAL`, `HIGH`, `MEDIUM`, or `LOW`. CRITICAL and HIGH block merge.

## Debugging Shortcut

Announce:

```text
**[nedflow:debugging] Debug**
```

Use for focused bug fixes. The flow is investigate -> reproduce -> red test -> green fix -> verify -> commit.

Protocol:

1. Clarify only essential missing reproduction details.
2. Investigate with local search/read commands and relevant tests.
3. State the suspected root cause in one sentence before editing.
4. If reproducible in code, write and run a failing test first.
5. Apply the minimum fix.
6. Run the targeted test and the relevant suite.
7. Commit as `fix(<scope>): <imperative description>`.
8. If no automated test is possible, write a note under:

```text
.codex/nedflow/plans/YYYY-MM-DD-<slug>.debugging.md
```

Include manual reproduction steps and the test gap in the commit body.

## Compatibility notes

This repository also contains Claude Code and OpenCode command/agent definitions. In Codex, prefer this skill and the Codex paths above, but keep existing `.claude/` plan or review files in place when continuing a workflow that started there.
