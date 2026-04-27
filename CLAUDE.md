# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

nedflow is a Claude Code / OpenCode **workflow plugin** — no compiled code, no test suite. All logic lives in Markdown prompt files (commands, agents, skills) plus one Bash hook script and one JavaScript OpenCode adapter.

## Commands

There is no build step. To verify the commit hook works:

```sh
bash bin/nedflow-commit-check.sh
```

To test hook logic manually, pipe a JSON payload:

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
| `skills/` | Reusable embedded skills: `brainstorming/SKILL.md`, `test-driven-development/SKILL.md` |
| `.opencode/commands/` | OpenCode versions of the same commands |
| `.opencode/agents/` | OpenCode versions of the same sub-agents |

Claude Code reads `commands/` and `agents/` via `.claude-plugin/plugin.json`. OpenCode reads `.opencode/` via `.opencode/plugins/nedflow.js` (a runtime adapter that loads the same prompt files).

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

`bin/nedflow-commit-check.sh` is declared as a PreToolUse hook in `hooks/hooks.json`. It intercepts `git commit -m "..."` calls and:

- Blocks `--amend`, `--no-verify`, and `Co-Authored-By` trailers
- Validates conventional commit format: `type(scope): description`
- Fails-open on `-F file` and heredoc-built messages

Valid types: `feat|fix|docs|style|refactor|perf|test|chore|build|ci|revert`

### Extending

- **New review angle**: add an agent under `agents/` and mirror it in `.opencode/agents/`; register a 4th parallel dispatch in `commands/review.md` (and `.opencode/commands/review.md`).
- **New phase**: add a command under `commands/` (and `.opencode/commands/`); use `.claude/` for artifacts.
- **Language-specific TDD**: fork `tdd-executor` (e.g. `tdd-executor-rust`); select it in `/tdd` based on repo detection.

## Commit convention

Enforced by the hook — no exceptions:

```
type(scope): description
```

- Lowercase, imperative mood, no trailing period
- No `Co-Authored-By`, no `--amend`, no `--no-verify`
