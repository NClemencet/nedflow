#!/usr/bin/env bash
# Table-driven tests for the commit guard.
# Usage:
#   bash tests/commit-check.sh                                                  # Claude Code hook
#   NEDFLOW_HOOK_RUNNER="node tests/opencode-hook.mjs" bash tests/commit-check.sh  # OpenCode guard
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [[ -n "${NEDFLOW_HOOK_RUNNER:-}" ]]; then
  read -ra RUNNER <<<"$NEDFLOW_HOOK_RUNNER"
else
  RUNNER=(bash "$ROOT/bin/nedflow-commit-check.sh")
fi
pass=0
fail=0

# check <allow|deny> <bash command as Claude would send it>
check() {
  local expect=$1 cmd=$2 out code got
  out=$(jq -cn --arg c "$cmd" '{tool_name:"Bash",tool_input:{command:$c}}' | (cd "$ROOT" && "${RUNNER[@]}") 2>/dev/null)
  code=$?
  if [[ $code -eq 2 ]] || printf '%s' "$out" | jq -e '.hookSpecificOutput.permissionDecision == "deny"' >/dev/null 2>&1; then
    got=deny
  else
    got=allow
  fi
  if [[ $got == "$expect" ]]; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1))
    printf 'FAIL expected %s, got %s: %s\n' "$expect" "$got" "$cmd"
  fi
}

# Not a commit: always allowed.
check allow 'ls -la'
check allow 'git log --oneline -n 5'
check allow 'echo "never use --amend" > notes.txt'

# Valid conventional commits.
check allow 'git commit -m "feat: add thing"'
check allow "git commit -m 'feat(api): add endpoint'"
check allow 'git commit -m "feat!: drop node 18 support"'
check allow 'git commit -am "fix(hook): handle compound commands"'
check allow 'git -C sub commit -m "chore: bump deps"'
check allow 'git status && git commit -m "fix(hook): handle chained call"'
check allow 'npm test; git commit -m "test: cover parser edge case"'
check allow 'git commit -m "docs: explain why --amend is forbidden"'
check allow 'echo "use --amend carefully" && git commit -m "docs: explain amend usage"'
check allow 'git commit -m "fix(cli): handle a | b; c && d case"'
check allow 'git commit -m "feat: add \"quoted\" word"'
check allow 'git commit -s -m "feat: add signoff support"'
check allow 'git commit -uno -m "chore: skip untracked files"'

# Message sources we cannot parse: fail-open.
check allow 'git commit -F msg.txt'
check allow $'git commit -m "$(cat <<\'EOF\'\nfeat: add heredoc support\n\nBody line.\nEOF\n)"'

# Forbidden flags and trailers.
check deny 'git commit --amend -m "fix: tweak thing"'
check deny 'git commit --amend --no-edit'
check deny 'git commit --no-verify -m "fix: tweak thing"'
check deny 'git commit -n -m "fix: tweak thing"'
check deny 'git commit -sn -m "fix: tweak thing"'
check deny 'git commit -m "fix: tweak; thing" --amend'
check deny 'git commit -m "feat: add thing" -m "Co-Authored-By: Someone <someone@example.com>"'
check deny $'git commit -m "$(cat <<\'EOF\'\nfeat: add thing\n\nCo-Authored-By: Someone <someone@example.com>\nEOF\n)"'

# Malformed subjects.
check deny 'git commit -m "Add thing."'
check deny 'git commit -m "feat: Add thing"'
check deny 'git commit -m "feat: add thing."'
check deny 'git commit -m "feature: add thing"'
check deny 'git commit -am "Bad message here"'
check deny 'git -c user.name=x commit -m "Bad message here"'
check deny 'cd sub && git commit -m "WIP"'

printf '%d passed, %d failed\n' "$pass" "$fail"
[[ $fail -eq 0 ]]
