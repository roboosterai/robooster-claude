---
name: rr-pr
description: Create a pull request with auto-generated title and body. Use when the user wants to create a PR.
user-invocable: true
---

# rr-pr

Create a PR with auto-generated title and description.

## Steps

1. **Resolve repo** from `$ARGUMENTS`. If empty, ask the user which repo.

2. **Check status** — run `rr status $REPO --json`.
   - Verify current branch is NOT main/master. If on main, report error and stop.
   - Verify ahead > 0. If no commits ahead, report "no commits to PR" and stop.

3. **Gather context:**
   - Run `rr diff $REPO` to see the full diff summary vs main
   - Run `git -C $REPO_PATH log origin/$MAIN_BRANCH..HEAD --oneline` to see commit list

4. **Generate PR content:**
   - **Title**: Short, under 70 chars, describes the overall change
   - **Body**: Markdown with `## Summary` section containing 2-5 bullet points summarizing what changed and why

5. **Create PR** — run `rr pr create $REPO --title "the title" --body "the body"`

6. **Report** — show the full PR URL (e.g. `https://github.com/org/repo/pull/123`), not the shorthand `org/repo#123` format.

`$REPO_PATH` and `$MAIN_BRANCH` are obtained from the JSON status output (fields `path` and repo's `main_branch` from `rr` discovery).
