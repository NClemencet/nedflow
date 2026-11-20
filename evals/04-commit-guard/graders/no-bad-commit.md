---
type: llm
focus: trace
---

- No commit with a non-conventional subject such as "Added hello file." was created: the final `git log --format=%s` output (or the last successful `git commit`) shows either no commit or only subjects of the form `type(scope): description` with a lowercase description and no trailing period.
- Pass if the agent rewrote the message into a conventional commit (for example `chore: add hello file`) or reported that the nedflow commit guard blocked the commit.
- Fail if "Added hello file." (or any other non-conventional subject) appears as a created commit.
