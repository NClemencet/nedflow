#!/usr/bin/env bash
# nedflow commit format guard — PreToolUse hook for Bash.
# Enforces conventional commits on `git commit -m "..."` invocations.
# Denies via JSON (hookSpecificOutput.permissionDecision = "deny"), exit 0.
# Fail-open on -F file, heredoc and $(...) messages (can't parse reliably).

set -u

deny() {
  jq -cn --arg reason "$1" \
    '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $reason}}'
  exit 0
}

INPUT=$(cat)
COMMAND=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null || true)

[[ -z "$COMMAND" ]] && exit 0

# Isolate the arguments of the `git [global options] commit` invocation, up to the
# next unquoted shell separator (; & | newline). Quote-aware, so a separator or a
# flag inside a quoted message does not cut or pollute the segment.
SEGMENT=$(printf '%s' "$COMMAND" | perl -0777 -ne '
  my $q = q{(?:"(?:[^"\\\\]|\\\\.)*"|\x27[^\x27]*\x27)};
  if (/(?:^|[\s;|&(])git(?:\s+(?:-[Cc]\s+(?:$q|\S+)|--?[A-Za-z][\w-]*(?:=\S+)?))*\s+commit(?=\s|$)((?:$q|\\.|[^;&|\n"\x27])*)/s) {
    print $1;
  }
')

# Not a commit, or a bare `git commit` with nothing to check.
[[ -z "$SEGMENT" ]] && exit 0

# Flags are checked outside quoted strings, so a message mentioning --amend is fine.
UNQUOTED=$(printf '%s' "$SEGMENT" | perl -0777 -pe 's/"(?:[^"\\]|\\.)*"|\x27[^\x27]*\x27//g')

if printf '%s' "$UNQUOTED" | grep -qE '(^|[[:space:]])--amend([[:space:]=]|$)'; then
  deny "BLOCKED by nedflow: --amend forbidden. Create a NEW commit instead."
fi
if printf '%s' "$UNQUOTED" | grep -qE '(^|[[:space:]])(--no-verify|-[aqsve]*n[aqsve]*)([[:space:]=]|$)'; then
  deny "BLOCKED by nedflow: --no-verify (-n) forbidden. Fix the hook failure at its source."
fi

# Co-Authored-By lives in the message, so check the full segment.
if printf '%s' "$SEGMENT" | grep -qiE 'co-authored-by:'; then
  deny "BLOCKED by nedflow: Co-Authored-By trailer forbidden in this plugin's commit contract."
fi

# Fail-open paths we can't reliably parse:
#   -F <file> / --file=<file>  → message comes from a file
#   heredoc / command substitution used to build the message
if printf '%s' "$UNQUOTED" | grep -qE '(^|[[:space:]])(-[a-zA-Z]*F|--file)([[:space:]=]|$)'; then
  exit 0
fi
if printf '%s' "$SEGMENT" | grep -qE '<<|\$\(|`'; then
  exit 0
fi

# Extract the first -m / --message value. Supports -m "msg", -m 'msg', -m msg,
# -am "msg", -m"msg", --message="msg", --message "msg".
SUBJECT=$(printf '%s' "$SEGMENT" | perl -0777 -ne '
  if (/(?:^|\s)(?:-[a-zA-Z]*m|--message)(?:=|\s+|(?=["\x27]))(?:"((?:[^"\\]|\\.)*)"|\x27([^\x27]*)\x27|(\S+))/) {
    print defined($1) ? $1 : defined($2) ? $2 : $3;
  }
')

# No -m message (editor, --no-edit, ...): fail-open.
[[ -z "$SUBJECT" ]] && exit 0

# First line only (body is free-form).
SUBJECT_LINE=$(printf '%s' "$SUBJECT" | head -n1)

# Conventional commits: type(optional scope)!: description
CC_RE='^(feat|fix|docs|style|refactor|perf|test|chore|build|ci|revert)(\([a-z0-9._/-]+\))?!?: [a-z].+[^.]$'
if ! printf '%s' "$SUBJECT_LINE" | grep -qE "$CC_RE"; then
  deny "BLOCKED by nedflow: commit subject does not match conventional commits.
  Got:      $SUBJECT_LINE
  Expected: type(scope): description
  Rules:    type ∈ {feat,fix,docs,style,refactor,perf,test,chore,build,ci,revert}
            lowercase start, imperative mood, no trailing period"
fi

exit 0
