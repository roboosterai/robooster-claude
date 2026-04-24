---
name: rr-pr-merge
description: Full PR lifecycle — create PR, wait for CI checks, merge to main, wait for merge CI, report final status.
user-invocable: true
---

# rr-pr-merge

Full PR lifecycle: create PR, wait for CI, merge, wait for post-merge CI, report.

## Steps

1. **Resolve repo** from `$ARGUMENTS`. If empty, ask the user which repo.

2. **Check status** — run `rr status $REPO --json`.
   - Verify current branch is NOT main/master. If on main, report error and stop.
   - Verify ahead > 0. If no commits ahead, report "no commits to PR" and stop.

3. **Generate PR content:**
   - Run `rr diff $REPO` for diff summary
   - Run `git -C $REPO_PATH log origin/$MAIN_BRANCH..HEAD --oneline` for commit list
   - Generate PR title (under 70 chars) and body (## Summary with bullet points)

4. **Create PR** — run `rr pr create $REPO --title "..." --body "..."`. Capture the PR URL. Extract the PR number from the URL.

5. **Wait for PR checks:**
   - Run `gh pr checks $PR_NUMBER` in `$REPO_PATH`
   - If checks exist and are pending: poll every 30 seconds using `sleep 30`, then re-run `gh pr checks $PR_NUMBER`
   - If all checks pass: proceed
   - If no checks configured: proceed immediately
   - If any check fails: report the failure details and **stop** (do not merge)

6. **Merge** — run `rr pr merge $REPO $PR_NUMBER`

7. **Wait for post-merge actions:**
   - Run `gh run list --branch main --limit 1 --json status,conclusion,name,createdAt` in `$REPO_PATH`
   - If a workflow run started after the merge and is in progress: poll every 30 seconds using `sleep 30`
   - If no runs or already complete: proceed
   - If the run fails: report but do not take action (merge already done)

8. **Final report:**
   ```
   ## PR Merge Complete
   - **PR:** #N — title (URL)
   - **CI Checks:** all passed / no checks / N passed, M failed
   - **Merge:** squash merged to main
   - **Post-merge actions:** passed / no actions / failed (details)
   ```

`$REPO_PATH` and `$MAIN_BRANCH` are obtained from the JSON status output.
