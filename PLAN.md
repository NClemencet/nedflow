# nedflow - Architecture & Design

Claude Code and OpenCode support are both implemented. This file documents the architecture for contributors.

## Design principles

1. **Explicit over automatic.** User invokes each phase. No silent activation, no blocking hooks.
2. **Atomic commits.** One TDD task → one commit, task files only. Plan file is updated once at the end of the run (`chore(plan): complete <slug>`). Live progress lives in runtime task tracking (Claude Code TaskList / OpenCode `todowrite`), not in plan checkbox ticks.
3. **Sub-agent isolation.** TDD tasks and review passes run in fresh contexts. The orchestrator only dispatches and verifies.
4. **Parallel where independent.** Review runs 3 agents concurrently in one round-trip.
5. **No hidden state.** Brainstorm, plan, and review artefacts live as files under `.claude/`.

## File layout

```
nedflow/
├── .opencode/
│   ├── commands/           # OpenCode custom commands
│   └── agents/             # OpenCode subagents
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

## Runtime surfaces

| Runtime | Integration surface |
|---|---|
| Claude Code | `.claude-plugin/` manifest + prompt files under `commands/` and `agents/` |
| OpenCode | `.opencode/plugins/nedflow.js` for Git install, plus `.opencode/commands/` + `.opencode/agents/` as source prompts and `tool.execute.before` commit enforcement |

Both runtimes share the same workflow and artifact locations under `.claude/`.

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
- In OpenCode, delegate repository discovery to the built-in `explore` subagent
- Produce executable plan with exact test code, commands, commit messages
- Reject own output if any "TODO" or "TBD" appears — brainstorm was incomplete

### /tdd
- Loop plan tasks
- Create one live progress entry per un-ticked plan task; update status live
- Dispatch one `tdd-executor` sub-agent per task — task files only, plan file untouched
- Verify commit SHA and touched files after each task
- Default: pause between tasks for user `continue`
- Final step (after all tasks done): tick all plan checkboxes and commit `chore(plan): complete <slug>`
- Never edit code directly — dispatch only

### /review
- Require base branch argument (no default)
- Spawn 3 reviewers in parallel
- Aggregate findings by severity CRITICAL/HIGH/MEDIUM/LOW then by category

### /debugging
- Investigate first, state root cause before fixing
- In OpenCode, delegate the initial investigation to the built-in `explore` subagent
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
- **Never:** amend, touch the plan file, commit unrelated changes

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
