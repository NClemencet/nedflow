# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

nedflow is a Claude Code / OpenCode / Codex **workflow plugin** — no compiled code. All logic lives in Markdown prompt files (commands, agents, skills) plus one Bash hook script and one JavaScript OpenCode adapter. The only automated tests cover the commit guard (`tests/`) and plugin behaviour (`evals/`).

## Commands

There is no build step.

```sh
claude plugin validate .                                                     # manifests + components
bash tests/commit-check.sh                                                   # commit hook, table-driven
NEDFLOW_HOOK_RUNNER="node tests/opencode-hook.mjs" bash tests/commit-check.sh  # same table vs OpenCode guard
claude plugin eval . --case 05-neg-plain-question --runs 1 --ablation none --no-publish   # cheap eval pilot
```

- `validate --strict` fails only on the expected "CLAUDE.md at the plugin root is not loaded" warning.
- Full eval run: `claude plugin eval . --scaffold --allow-tools Bash Write --judge-model sonnet --no-publish`. Granting Bash requires the sandbox (`bubblewrap` + `socat`). Each case is a real Claude session — mind the cost.
- To test hook logic by hand, pipe a payload; a denial prints a `permissionDecision: "deny"` JSON object (exit 0):

```sh
echo '{"tool_input":{"command":"git commit -m \"feat: add thing\""}}' | bash bin/nedflow-commit-check.sh; echo "exit $?"
```

## Architecture

### Workflow pipeline

```
/brainstorm → /plan → /tdd → /review
                ↑
         /debugging (short-circuit for bug fixes)
```

Each phase is user-invoked. No automatic progression.

### Prompt file locations

| Dir | Contents |
|---|---|
| `commands/` | One `.md` per slash command (brainstorm, plan, tdd, review, debugging) |
| `agents/` | Sub-agent prompts: `tdd-executor`, `security-reviewer`, `refactor-reviewer`, `bug-hunter` |
| `skills/` | Shared skills `brainstorming`, `test-driven-development`; Codex-only skills `nedflow`, `security-reviewer`, `refactor-reviewer`, `bug-hunter` |
| `tests/` | `commit-check.sh` (table-driven hook tests) + `opencode-hook.mjs` shim |
| `evals/` | `claude plugin eval` cases (`prompt.md` + `graders/`, or `case.yaml`); `evals/results/` is gitignored |
| `.opencode/commands/` | OpenCode versions of the same commands |
| `.opencode/agents/` | OpenCode versions of the same sub-agents |

Claude Code auto-discovers `commands/`, `agents/`, `skills/`, `hooks/hooks.json` and `bin/` (added to the Bash PATH). OpenCode reads `.opencode/` via `.opencode/plugins/nedflow.js` (a runtime adapter that loads the same prompt files and maps the commit guard to `tool.execute.before`). Codex reads `skills/` via `.codex-plugin/plugin.json`.

### Claude Code conventions

- Plugin components are namespaced: dispatch agents with `subagent_type: "nedflow:<agent>"`, refer to skills as `nedflow:<skill>`.
- Codebase research uses the built-in `Explore` agent with `model: "haiku"` (it otherwise inherits the session model). OpenCode uses its built-in `explore`.
- Phase commands carry `disable-model-invocation: true` — they are user-invoked only.
- Codex-only skills carry `disable-model-invocation: true` + `user-invocable: false`: Claude Code also scans `skills/` (a `skills` path in `plugin.json` adds to the scan, it does not replace it), while Codex ignores both keys.
- `` !`cmd` `` context injection aborts the whole command if `cmd` fails or Bash is denied. Use it only in commands that need git anyway (`/tdd`, `/debugging`), with commands that cannot fail inside a repo, and pre-approve the exact command in `allowed-tools`. Never interpolate `$ARGUMENTS` into it.
- Task tracking: one `TaskCreate` per task (`subject`, `activeForm`), sent in a single message; progress via `TaskUpdate` (`taskId`, `status`). OpenCode uses `todowrite`.

### Sub-agent contracts

- **`tdd-executor`**: receives plan path + task number; writes a failing test, implements minimally, runs full suite, commits atomically. Returns ≤150 words + commit SHA. Retries 2× on lint/test failure. Never amends; never touches the plan file.
- **`security-reviewer` / `refactor-reviewer` / `bug-hunter`**: each receives a base branch, scans the diff independently for its own category, returns `- [SEVERITY] path:line — problem → fix` or `NO FINDINGS`. Spawned in parallel by `/review`.

### Artifacts (written into consumer repos, not here)

```
.claude/plans/YYYY-MM-DD-<slug>.brainstorm.md   ← /brainstorm output
.claude/plans/YYYY-MM-DD-<slug>.md               ← /plan output
.claude/plans/YYYY-MM-DD-<slug>.debugging.md     ← /debugging (non-reproducible bugs only)
.claude/reviews/<branch>-YYYY-MM-DD.md           ← /review aggregation
```

### Commit hook

`bin/nedflow-commit-check.sh` is declared as a PreToolUse hook in `hooks/hooks.json` (`matcher: "Bash"`, `"if": "Bash(git *)"`, `timeout: 10`). It isolates the `git [global options] commit` segment of the command (quote-aware, so `-am`, `git -c k=v commit` and chained commands are covered) and:

- Blocks `--amend`, `--no-verify` / `-n`, and `Co-Authored-By` trailers (flags are matched outside quoted strings)
- Validates conventional commit format: `type(scope): description`
- Fails-open on `-F file`, heredoc and `$(...)`-built messages
- Denies by printing `hookSpecificOutput.permissionDecision: "deny"` JSON (exit 0)

`.opencode/plugins/nedflow.js` mirrors the same logic — change both together and run the test table against both.

Valid types: `feat|fix|docs|style|refactor|perf|test|chore|build|ci|revert`

### Extending

- **New review angle**: add an agent under `agents/` and mirror it in `.opencode/agents/`; register a 4th parallel dispatch (`subagent_type: "nedflow:<name>"`) in `commands/review.md` (and `.opencode/commands/review.md`).
- **New phase**: add a command under `commands/` (and `.opencode/commands/`); use `.claude/` for artifacts.
- **Language-specific TDD**: fork `tdd-executor` (e.g. `tdd-executor-rust`); select it in `/tdd` based on repo detection.

## Commit convention

Enforced by the hook — no exceptions:

```
type(scope): description
```

- Lowercase, imperative mood, no trailing period
- No `Co-Authored-By`, no `--amend`, no `--no-verify`
