---
name: rr-merge
description: Merge the current branch to main — via PR (squash) if one exists, or direct merge if not.
user-invocable: true
---

# rr-merge

Merge the current branch to main. Uses PR squash merge when a PR exists, falls back to direct local merge otherwise.

## Steps

1. **Resolve repo** from `$ARGUMENTS`. If empty, ask the user which repo.

2. **Get repo info** — run `rr status $REPO --json` to get `$REPO_PATH`, current branch, and remote state.
   - If already on main, report "already on main, nothing to merge" and stop.
   - If dirty, report "working tree is dirty, commit or stash first" and stop.

3. **Check for PR** — run `gh pr view --json number,title,state,url,headRefName` in `$REPO_PATH`.

4. **If PR exists and is open:**
   - Display PR number, title, URL, and branch name.
   - Run `rr pr merge $REPO $PR_NUMBER`.
   - Run `rr done $REPO`.
   - Report merge succeeded.

5. **If no PR exists — direct merge:**
   - Ensure the branch is pushed and up to date with remote. If unpushed commits exist, run `rr push $REPO` first.
   - Show the branch name and commit count ahead of main.
   - Run the following git commands in `$REPO_PATH`:
     ```bash
     git checkout main
     git pull origin main
     git merge --squash $BRANCH
     git commit -m "$SQUASH_MESSAGE"
     git push origin main
     git branch -d $BRANCH
     git push origin --delete $BRANCH
     ```
   - `$SQUASH_MESSAGE` — generate a single conventional commit message summarizing all commits on the branch. Use `git log main..$BRANCH --oneline` to see what's being merged.
   - Report merge succeeded and branch cleaned up.

`$REPO_PATH` is obtained from the `path` field in the JSON status output.
