#!/usr/bin/env bash
# nedflow commit format guard — PreToolUse hook for Bash.
# Enforces conventional commits on `git commit -m "..."` invocations.
# Fail-open on heredoc / -F file inputs (can't parse reliably without risk).

set -u

INPUT=$(cat)
COMMAND=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null || true)

[[ -z "$COMMAND" ]] && exit 0

# Only act when `git commit` appears as an actual subcommand.
if ! printf '%s' "$COMMAND" | grep -qE '(^|[[:space:]\;\|\&\(])git[[:space:]]+commit([[:space:]]|$)'; then
  exit 0
fi

# Block --amend and --no-verify regardless of message.
if printf '%s' "$COMMAND" | grep -qE '(^|[[:space:]])--amend([[:space:]=]|$)'; then
  echo "BLOCKED by nedflow: --amend forbidden. Create a NEW commit instead." >&2
  exit 2
fi
if printf '%s' "$COMMAND" | grep -qE '(^|[[:space:]])--no-verify([[:space:]=]|$)'; then
  echo "BLOCKED by nedflow: --no-verify forbidden. Fix the hook failure at its source." >&2
  exit 2
fi

# Block Co-Authored-By trailer (nedflow contract forbids it).
if printf '%s' "$COMMAND" | grep -qiE 'co-authored-by:'; then
  echo "BLOCKED by nedflow: Co-Authored-By trailer forbidden in this plugin's commit contract." >&2
  exit 2
fi

# Fail-open paths we can't reliably parse:
#   -F <file> / --file=<file>  → message comes from a file
#   heredoc / command substitution used to build the message
if printf '%s' "$COMMAND" | grep -qE '(^|[[:space:]])(-F|--file(=|[[:space:]]))'; then
  exit 0
fi
if printf '%s' "$COMMAND" | grep -qE '<<[^[:space:]]*[A-Z_]'; then
  exit 0
fi

# Extract the first -m / --message argument's value.
# Supports: -m "msg", -m 'msg', --message="msg", --message "msg", --message=msg
SUBJECT=$(printf '%s' "$COMMAND" | perl -ne '
  while (/(?:^|\s)(?:-m|--message)(?:=|\s+)(?:"((?:[^"\\]|\\.)*)"|'"'"'([^'"'"']*)'"'"'|(\S+))/g) {
    my $m = defined($1) ? $1 : defined($2) ? $2 : $3;
    print "$m\n";
    last;
  }
')

# If we couldn't extract anything, fail-open.
[[ -z "$SUBJECT" ]] && exit 0

# First line only (body is free-form).
SUBJECT_LINE=$(printf '%s' "$SUBJECT" | head -n1)

# Conventional commits: type(optional scope)!: description
CC_RE='^(feat|fix|docs|style|refactor|perf|test|chore|build|ci|revert)(\([a-z0-9._/-]+\))?!?: [a-z].+[^.]$'
if ! printf '%s' "$SUBJECT_LINE" | grep -qE "$CC_RE"; then
  cat >&2 <<EOF
BLOCKED by nedflow: commit subject does not match conventional commits.
  Got:      $SUBJECT_LINE
  Expected: type(scope): description
  Rules:    type ∈ {feat,fix,docs,style,refactor,perf,test,chore,build,ci,revert}
            lowercase start, imperative mood, no trailing period
EOF
  exit 2
fi

exit 0
