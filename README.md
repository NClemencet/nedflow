# nedflow

Lightweight workflow pack for Codex, Claude Code, and OpenCode. Five workflow phases, review helpers, and a commit-format contract.

## Workflow

```
/brainstorm → /plan → /tdd → /review
                ↑
         /debugging (short-circuit for bug fixes)
```

## Commands

In Codex, invoke these as `nedflow <phase> ...`; Codex writes native workflow artifacts under `.codex/nedflow/`. Claude Code and OpenCode keep the slash-command interface and `.claude/` artifact paths.

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

In Codex, the review helpers are also packaged as skills so `nedflow review <base-branch>` can load them through the Codex plugin manifest:

- `security-reviewer`
- `refactor-reviewer`
- `bug-hunter`

Codebase research during `/brainstorm`, `/plan` and `/debugging` uses each runtime's built-in explorer: Claude Code's `Explore` agent (dispatched with `model: haiku`) and OpenCode's `explore` subagent.

In Claude Code, plugin agents are namespaced: the commands dispatch `nedflow:tdd-executor`, `nedflow:security-reviewer`, and so on. The five phase commands are user-only (`disable-model-invocation: true`), so a phase never starts on its own.

## Commit convention

Conventional commits, enforced by the bundled `nedflow-commit-check` hook in Claude Code and by the OpenCode plugin's `tool.execute.before` hook:

```
type(scope): description
```

- Types: `feat|fix|docs|style|refactor|perf|test|chore|build|ci|revert`
- Imperative, lowercase, no period
- Bullets after blank line for details when "why" is non-obvious
- **No `Co-Authored-By` line**, no `--amend`, no `--no-verify` — the hook blocks them

The hook script lives at `bin/nedflow-commit-check.sh`; declaration at `hooks/hooks.json` (filtered with `"if": "Bash(git *)"`, so it only runs for git commands). It isolates the `git [global options] commit` segment of the command, quote-aware, so `git commit -am "..."`, `git -c k=v commit ...` and chained commands are checked, while a message that merely mentions `--amend` is not blocked. Denials are returned as a `permissionDecision: "deny"` JSON payload. It fails-open on `-F file`, heredoc and `$(...)`-built messages (can't parse reliably).

## Review severity scale

`CRITICAL` → `HIGH` → `MEDIUM` → `LOW`

- CRITICAL / HIGH block merge
- MEDIUM / LOW inform — author decides

## Install

### Codex plugin

Use this repository as a local Codex plugin. From the repository root, the Codex manifest lives at:

```sh
.codex-plugin/plugin.json
```

The Codex entrypoint is the `nedflow` skill. Ask Codex for any phase with:

```text
nedflow brainstorm <feature idea>
nedflow plan <slug or feature>
nedflow tdd <plan path or slug>
nedflow review <base-branch>
nedflow debugging <bug description>
```

Codex writes native workflow files under `.codex/nedflow/` by default, while still reading existing `.claude/plans/` files for compatibility.

### Claude Code marketplace (recommended)

In any Claude Code session:

```
/plugin marketplace add <git-url-or-local-path-of-this-repo>
/plugin install nedflow@nedflow
```

To pick up a new release: `/plugin marketplace update nedflow`, then `/plugin update nedflow@nedflow` and restart.

### Claude Code (local development)

Load the working copy for one session, without installing it:

```sh
claude --plugin-dir /path/to/nedflow
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
OPENCODE_CONFIG_DIR=/path/to/nedflow/.opencode opencode
```

You can also copy the files into either of these locations:

- Global: `~/.config/opencode/commands/` and `~/.config/opencode/agents/`
- Per-project: `.opencode/commands/` and `.opencode/agents/`

Restart OpenCode. The custom commands will appear as `/brainstorm`, `/plan`, `/tdd`, `/review`, and `/debugging`.

## Runtime mapping

The workflow is the same in all three runtimes. Only the integration surface changes.

| Codex | Claude Code | OpenCode |
|---|---|---|
| `.codex-plugin/plugin.json` + `skills/nedflow/SKILL.md` | `.claude-plugin/plugin.json` | `.opencode/commands/*.md` + `.opencode/agents/*.md` |
| concise user questions | `AskUserQuestion` | `question` |
| task tracker / plan updates | `TaskCreate` / `TaskUpdate` | `todowrite` |
| optional Codex sub-agents | `Agent` | `task` / subagents |
| local codebase search or Codex explorer | built-in `Explore` agent (`model: haiku`) | built-in `explore` subagent |
| commit contract in skill instructions | `PreToolUse` Bash hook | plugin `tool.execute.before` hook |

## Per-project setup

Recommended additions to project `.gitignore`:

```
.codex/nedflow/
.claude/plans/
.claude/reviews/
```

nedflow never stages or commits these artifacts (brainstorm notes, plans, debugging notes, review reports): they stay local. Only the code changes from `/tdd` and `/debugging` are committed.

## Development

There is no build step.

```sh
claude plugin validate .                                                     # manifests, commands, agents, skills, hooks
bash tests/commit-check.sh                                                   # Claude Code commit hook
NEDFLOW_HOOK_RUNNER="node tests/opencode-hook.mjs" bash tests/commit-check.sh  # OpenCode commit guard
```

`claude plugin validate . --strict` fails only on the expected warning that the root `CLAUDE.md` (contributor notes) is not shipped as plugin context.

Behavioural evals live in `evals/` and run with [`claude plugin eval`](https://code.claude.com/docs/en/plugins). Each case runs with and without the plugin, so the headline number is the uplift:

```sh
claude plugin eval . --scaffold --allow-tools Bash Write --judge-model sonnet --no-publish
```

- `--scaffold` runs `evals/03-review-requires-base/scaffold.sh` (creates a throwaway git repo).
- Granting `Bash` needs the Claude Code sandbox (`bubblewrap` and `socat`); without it, drop `--allow-tools` and skip `04-commit-guard` with `--case`.
- Every run is a full Claude session: 5 cases × 3 runs × 2 arms. Pilot with `--runs 1` first.

## Design notes

- **Minimal hooks.** Only a lightweight commit-format guard. Review is explicit via `/review`, not pre-commit. Keeps the loop fast.
- **Sub-agent per TDD task.** Each task runs in a fresh context - atomic commits, bounded blast radius, no context pollution.
- **Parallel review.** Security / refactor / bugs run in one round-trip. Severity-tagged findings merge into one report.
- **`/debugging` skips brainstorm/plan.** Bugs don't need 3 approaches - they need a failing test and a fix.

## Credits

Inspired by [superpowers](https://github.com/obra/superpowers/) by Jesse Vincent. The `brainstorming` and `test-driven-development` skills are adapted from superpowers — trimmed and re-aligned for the nedflow pipeline.

## License

MIT
