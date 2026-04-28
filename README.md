# nedflow

Lightweight workflow pack for Claude Code and OpenCode. Five slash commands, four nedflow sub-agents, and one commit-format guard wired into both runtimes.

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

OpenCode also reuses its built-in `explore` subagent during `/plan` and `/debugging` to replace Claude Code's internal `code-explorer` helper.

## Commit convention

Conventional commits, enforced by the bundled `nedflow-commit-check` hook in Claude Code and by the OpenCode plugin's `tool.execute.before` hook:

```
type(scope): description
```

- Types: `feat|fix|docs|style|refactor|perf|test|chore|build|ci|revert`
- Imperative, lowercase, no period
- Bullets after blank line for details when "why" is non-obvious
- **No `Co-Authored-By` line**, no `--amend`, no `--no-verify` — the hook blocks them

The hook script lives at `bin/nedflow-commit-check.sh`; declaration at `hooks/hooks.json`. It fails-open on `-F file` and heredoc-built messages (can't parse reliably).

## Review severity scale

`CRITICAL` → `HIGH` → `MEDIUM` → `LOW`

- CRITICAL / HIGH block merge
- MEDIUM / LOW inform — author decides

## Install

### Claude Code plugin (local symlink)

```sh
ln -s /home/nc/Code/nedflow ~/.claude/plugins/nedflow
```

Restart Claude Code. Verify with `/plugin` - nedflow should appear.

### Claude Code marketplace (share with team)

In any Claude Code session:

```
/plugin marketplace add <git-url-of-this-repo>
/plugin install nedflow@nedflow
```

### OpenCode commands + agents

OpenCode does not consume Claude plugin manifests. Use the `.opencode/` pack in this repo instead.

Recommended install, inspired by `superpowers`: add nedflow as an OpenCode plugin from Git.

```json
{
  "plugin": ["nedflow@git+https://github.com/NClemencet/nedflow.git"]
}
```

Then restart OpenCode.

You can also tell OpenCode:

```text
Fetch and follow instructions from https://raw.githubusercontent.com/NClemencet/nedflow/main/.opencode/INSTALL.md
```

If you are using this repo directly in OpenCode, no extra install step is needed - the project already contains `.opencode/commands/`, `.opencode/agents/`, and a plugin entrypoint under `.opencode/plugins/`.

To reuse nedflow in another project, either copy the files or point OpenCode at this pack:

```sh
OPENCODE_CONFIG_DIR=/home/nc/Code/nedflow/.opencode opencode
```

You can also copy the files into either of these locations:

- Global: `~/.config/opencode/commands/` and `~/.config/opencode/agents/`
- Per-project: `.opencode/commands/` and `.opencode/agents/`

Restart OpenCode. The custom commands will appear as `/brainstorm`, `/plan`, `/tdd`, `/review`, and `/debugging`.

## Runtime mapping

The workflow is the same in both runtimes. Only the integration surface changes.

| Claude Code | OpenCode |
|---|---|
| `.claude-plugin/plugin.json` | `.opencode/commands/*.md` + `.opencode/agents/*.md` |
| `AskUserQuestion` | `question` |
| `TaskCreate` / `TaskUpdate` | `todowrite` |
| `Agent` | `task` / subagents |
| `code-explorer` helper agent | built-in `explore` subagent |
| `PreToolUse` Bash hook | plugin `tool.execute.before` hook |

## Per-project setup

Recommended additions to project `.gitignore`:

```
.claude/plans/
.claude/reviews/
```

Or keep them committed if you want the brainstorm/plan/review history to live with the branch.

## Design notes

- **Minimal hooks.** Only a lightweight commit-format guard. Review is explicit via `/review`, not pre-commit. Keeps the loop fast.
- **Sub-agent per TDD task.** Each task runs in a fresh context - atomic commits, bounded blast radius, no context pollution.
- **Parallel review.** Security / refactor / bugs run in one round-trip. Severity-tagged findings merge into one report.
- **`/debugging` skips brainstorm/plan.** Bugs don't need 3 approaches - they need a failing test and a fix.

## Credits

Inspired by [superpowers](https://github.com/obra/superpowers/) by Jesse Vincent. The `brainstorming` and `test-driven-development` skills are adapted from superpowers — trimmed and re-aligned for the nedflow pipeline.

## License

MIT
