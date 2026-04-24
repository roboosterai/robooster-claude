---
name: rr-commit
description: Stage all changes and commit with an auto-generated message. Use when the user wants to commit changes in a repo.
user-invocable: true
---

# rr-commit

Commit all changes in a repo with an auto-generated conventional commit message.

## Steps

1. **Resolve repo** from `$ARGUMENTS`. If empty, ask the user which repo.

2. **Check status** — run `rr status $REPO --json`. If not dirty, report "nothing to commit" and stop.

3. **Read the diff** — run `git -C $REPO_PATH diff` and `git -C $REPO_PATH diff --cached` and `git -C $REPO_PATH status --porcelain` to understand all changes (staged, unstaged, untracked).

4. **Generate commit message** — from the diff, write a concise conventional commit message:
   - Format: `type: brief description` (one line, under 72 chars)
   - Types: `feat`, `fix`, `refactor`, `docs`, `chore`, `test`, `style`
   - If changes span multiple concerns, pick the primary one for the type
   - Add a body paragraph only if the change is non-obvious

5. **Commit** — run `rr commit $REPO -m "the generated message"`

6. **Report** — show the commit hash and message.

`$REPO_PATH` is obtained from the `path` field in the JSON status output.
