# Installing nedflow for OpenCode

## Installation

Add nedflow to the `plugin` array in your `opencode.json` (global or project-level):

```json
{
  "plugin": ["nedflow@git+https://github.com/NClemencet/nedflow.git"]
}
```

Restart OpenCode. The plugin auto-installs and registers all nedflow commands and subagents.

Commands added:

- `/brainstorm`
- `/plan`
- `/tdd`
- `/review`
- `/debugging`

## Verify

Start a new OpenCode session and run one of these:

```text
/brainstorm improve the review workflow
```

or

```text
/review main
```

## Updating

nedflow updates automatically when you restart OpenCode.

To pin a specific version:

```json
{
  "plugin": ["nedflow@git+https://github.com/NClemencet/nedflow.git#v0.1.3"]
}
```

## How it works

The plugin registers the commands and subagents shipped in this repository into OpenCode config at startup, and enforces nedflow commit-message rules before `bash` runs `git commit`.

Runtime mapping:

- `AskUserQuestion` -> `question`
- `TaskCreate` / `TaskUpdate` -> `todowrite`
- `Agent` -> `task` / subagents
- Claude `code-explorer` helper -> built-in `explore` subagent
- Claude `PreToolUse` commit hook -> OpenCode `tool.execute.before`

## Troubleshooting

### Plugin not loading

1. Check logs: `opencode run --print-logs "hello" 2>&1 | grep -i nedflow`
2. Verify the plugin line in your `opencode.json`
3. Make sure you are running a recent version of OpenCode

### Commands not appearing

1. Restart OpenCode after editing `opencode.json`
2. Check the plugin is loading in logs
3. Make sure no local config overrides are redefining the same command names
