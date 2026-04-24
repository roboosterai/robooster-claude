---
name: rr-status
description: Check git status across workspace repos. Use when the user asks to check repo status, what's changed, or what needs pushing.
user-invocable: true
---

# rr-status

Run `rr status $ARGUMENTS` and present the result.

If `$ARGUMENTS` is empty, run `rr status` (all repos, default).

The user can pass flags directly:
- `/rr-status -p platro` — platro repos only
- `/rr-status -p robooster` — non-platro repos only
- `/rr-status services` — single repo by partial name
- `/rr-status --json` — JSON output
- `/rr-status --local` — skip fetch for instant results

After showing the table, briefly summarize anything that needs attention (dirty repos, repos behind remote).
