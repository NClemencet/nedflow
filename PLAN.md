# nedflow — Architecture & Design

Plugin implementation is complete. This file documents the architecture for contributors.

## Design principles

1. **Explicit over automatic.** User invokes each phase. No silent activation, no blocking hooks.
2. **Atomic commits.** One TDD task → one commit. Plan file update is part of the same commit.
3. **Sub-agent isolation.** TDD tasks and review passes run in fresh contexts. The orchestrator only dispatches and verifies.
4. **Parallel where independent.** Review runs 3 agents concurrently in one round-trip.
5. **No hidden state.** Brainstorm, plan, and review artefacts live as files under `.claude/`.

## File layout

```
nedflow/
├── .claude-plugin/
│   ├── plugin.json         # Plugin manifest
│   └── marketplace.json    # Marketplace entry (self-hosted)
├── commands/
│   ├── brainstorm.md       # /brainstorm
│   ├── plan.md             # /plan
│   ├── tdd.md              # /tdd
│   ├── review.md           # /review
│   └── debugging.md        # /debugging
├── agents/
│   ├── tdd-executor.md     # Executes one plan task
│   ├── security-reviewer.md
│   ├── refactor-reviewer.md
│   └── bug-hunter.md
├── README.md
└── PLAN.md                 # This file
```

## Artefact locations (per project)

| Phase | Path | Lifetime |
|---|---|---|
| Brainstorm | `.claude/plans/YYYY-MM-DD-<slug>.brainstorm.md` | Keep or gitignore |
| Plan | `.claude/plans/YYYY-MM-DD-<slug>.md` | Keep or gitignore |
| Debug note | `.claude/plans/YYYY-MM-DD-<slug>.debugging.md` | Only when bug non-reproducible in code |
| Review | `.claude/reviews/<branch>-YYYY-MM-DD.md` | Keep or gitignore |

## Command responsibilities

### /brainstorm
- Research codebase for context
- Produce 2-4 approaches (default 3, variable)
- Wait for user selection
- Write brainstorm note

### /plan
- Read latest brainstorm for slug (if any)
- Produce executable plan with exact test code, commands, commit messages
- Reject own output if any "TODO" or "TBD" appears — brainstorm was incomplete

### /tdd
- Loop plan tasks
- Dispatch one `tdd-executor` sub-agent per task
- Verify commit SHA, touched files, plan tick after each task
- Default: pause between tasks for user `continue`
- Never edit code directly — dispatch only

### /review
- Require base branch argument (no default)
- Spawn 3 reviewers in parallel (single orchestrator message, 3 Agent calls)
- Aggregate findings by severity CRITICAL/HIGH/MEDIUM/LOW then by category

### /debugging
- Investigate first, state root cause before fixing
- Write failing unit test **when reproducible in code**
- Dispatch `tdd-executor` for the fix
- Document manually when non-reproducible

## Commit convention

Enforced by `tdd-executor`:

```
type(scope): description
```

- `type`: `feat|fix|refactor|docs|chore|test`
- Imperative, lowercase, no trailing period
- Detail bullets after one blank line
- **No `Co-Authored-By` line**
- Never `--amend`, never `--no-verify`

## Sub-agent contracts

### tdd-executor
- **Input:** plan path + task number
- **Output:** summary ≤150 words, commit SHA, deviations
- **Retries:** 2 on lint/test failure; surface blocker on third
- **Never:** amend, skip plan tick, commit unrelated changes

### security-reviewer / refactor-reviewer / bug-hunter
- **Input:** base branch
- **Output:** one finding per line or `NO FINDINGS`
- **Format:** `- [<SEVERITY>] <path>:<line> — <problem> → <fix>`
- **Scope:** each agent sticks to its category; no overlap

## Extension points

- **New review angle** — add an agent under `agents/`, register it in `/review` command as a 4th parallel call.
- **New phase** — add a command under `commands/`, reference artefacts in `.claude/`.
- **Language-specific TDD** — fork `tdd-executor` (e.g. `tdd-executor-rust`) with stricter tooling, select in `/tdd` based on repo detection.

## Non-goals

- Pre-commit hooks (blocking gates) — too coarse, slows the loop.
- Automatic phase progression — user stays in control of when to advance.
- Large language-specific best-practice skills — those belong in per-project CLAUDE.md.
