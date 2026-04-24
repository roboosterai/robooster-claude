---
name: rr-ship
description: Commit all changes with auto-generated message and push. Use when the user wants to commit and push in one shot.
user-invocable: true
---

# rr-ship

Commit + push in one shot with an auto-generated commit message.

## Steps

1. **Resolve repo** from `$ARGUMENTS`. If empty, ask the user which repo.

2. **Check status** — run `rr status $REPO --json`. If not dirty and no commits ahead, report "nothing to ship" and stop.

3. **If dirty**, read the diff to generate a commit message:
   - Run `git -C $REPO_PATH diff` and `git -C $REPO_PATH diff --cached` and `git -C $REPO_PATH status --porcelain`
   - Generate a concise conventional commit message (see `/rr-commit` for format rules)

4. **Ship** — run `rr ship $REPO -m "the generated message"`. If not dirty but has unpushed commits, run `rr push $REPO` instead.

5. **Report** — show commit hash (if committed), push result, and final state.

`$REPO_PATH` is obtained from the `path` field in the JSON status output.
