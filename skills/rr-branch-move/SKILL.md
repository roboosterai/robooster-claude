---
name: rr-branch-move
description: Move uncommitted changes and local commits from main to a new feature branch. Use when the user started coding on main and wants to move work to a branch.
user-invocable: true
---

# rr-branch-move

Move all work (uncommitted changes + local commits) from main to a new feature branch based on `origin/main`.

## Steps

1. **Resolve repo and branch name** from `$ARGUMENTS` (expects `<repo> <new-branch>`). If either is missing, ask the user.

2. **Move** — run `rr branch-move $REPO $NEW_BRANCH`. The command handles all checks internally:
   - Refuses if not on main
   - Refuses if working tree is clean and no local commits (nothing to move)
   - Refuses if target branch already exists (locally or on remote)
   - Fetches origin
   - Stashes uncommitted changes (`git stash -u`, includes untracked files)
   - Creates new branch at current HEAD (captures local commits)
   - Resets main to `origin/main`
   - Checks out new branch
   - Pops stash (conflicts reported as warning, not fatal)

3. **Report** — the command prints checkmarks for each step. Relay the output to the user.
