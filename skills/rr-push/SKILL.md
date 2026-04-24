---
name: rr-push
description: Push current branch to remote. Use when the user wants to push committed changes.
user-invocable: true
---

# rr-push

Push the current branch of a repo to remote.

## Steps

1. **Resolve repo** from `$ARGUMENTS`. If empty, ask the user which repo.

2. **Check status** — run `rr status $REPO --json`. Show the user current branch and how many commits ahead.

3. **Push** — run `rr push $REPO`.

4. **Report** — confirm push succeeded, show branch and remote.
