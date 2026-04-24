---
name: rr-done
description: Checkout main, pull, and delete the current branch. Use when the user is done with a feature branch and wants to clean up.
user-invocable: true
---

# rr-done

Clean up after a merged branch — verifies merge via tree-diff, checks out main, pulls latest, deletes local and remote feature branch.

## Steps

1. **Resolve repo** from `$ARGUMENTS`. If empty, ask the user which repo.

2. **Done** — run `rr done $REPO`. The command handles all checks internally:
   - Refuses if already on main
   - Refuses if working tree is dirty
   - Fetches origin
   - Verifies branch is merged via tree-diff (`git diff --quiet` against origin/main)
   - Checks out main, pulls `--ff-only`
   - Deletes local branch (`-D`), deletes remote branch (tolerates already-gone)

3. **Force mode** — if the user wants to abandon an unmerged branch, run `rr done $REPO --force` (skips merge check).

4. **Report** — the command prints checkmarks for each step. Relay the output to the user.
