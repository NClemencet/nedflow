# nedflow

Lightweight Claude Code workflow plugin. Five slash commands, four sub-agents, no hooks.

## Workflow

```
/brainstorm → /plan → /tdd → /review
                ↑
         /debugging (short-circuit for bug fixes)
```

## Commands

| Command | Phase | Purpose |
|---|---|---|
| `/brainstorm <idea>` | 1 | 2-3 proposals, trade-offs, user picks. Writes `.claude/plans/<date>-<slug>.brainstorm.md`. |
| `/plan <slug>` | 2 | Executable TDD plan at `.claude/plans/<date>-<slug>.md`. |
| `/tdd <plan>` | 3 | Dispatches each task to `tdd-executor` sub-agent. Atomic commits. 2 retries on failure. |
| `/review <base-branch>` | 4 | Spawns 3 reviewers in parallel. Aggregates `.claude/reviews/<branch>-<date>.md`. |
| `/debugging <bug>` | — | Investigate → failing unit test → fix via `tdd-executor` → commit. |

## Sub-agents

| Agent | Role | Tools |
|---|---|---|
| `tdd-executor` | Red/green/commit one plan task | all |
| `security-reviewer` | Diff scan: secrets, injection, auth, crypto | read-only + bash |
| `refactor-reviewer` | Diff scan: dead code, duplication, naming | read-only + bash |
| `bug-hunter` | Diff scan: logic bugs, edge cases, coverage | read-only + bash |

## Commit convention

Every commit emitted by nedflow follows:

```
type(scope): description
```

- Types: `feat|fix|refactor|docs|chore|test`
- Imperative, lowercase, no period
- Bullets after blank line for details when "why" is non-obvious
- **No `Co-Authored-By` line**

## Review severity scale

`CRITICAL` → `HIGH` → `MEDIUM` → `LOW`

- CRITICAL / HIGH block merge
- MEDIUM / LOW inform — author decides

## Install

### As local plugin (symlink)

```sh
ln -s /home/nc/Code/nedflow ~/.claude/plugins/nedflow
```

Restart Claude Code. Verify with `/plugin` — nedflow should appear.

### Via marketplace (share with team)

In any Claude Code session:

```
/plugin marketplace add <git-url-of-this-repo>
/plugin install nedflow@nedflow
```

## Per-project setup

Recommended additions to project `.gitignore`:

```
.claude/plans/
.claude/reviews/
```

Or keep them committed if you want the brainstorm/plan/review history to live with the branch.

## Design notes

- **No blocking hooks.** Review is explicit via `/review`, not pre-commit. Keeps the loop fast.
- **Sub-agent per TDD task.** Each task runs in a fresh context — atomic commits, bounded blast radius, no context pollution.
- **Parallel review.** Security / refactor / bugs run in one round-trip. Severity-tagged findings merge into one report.
- **`/debugging` skips brainstorm/plan.** Bugs don't need 3 approaches — they need a failing test and a fix.

## License

MIT
