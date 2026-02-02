---
name: robooster-claude-updating
description: Commits and pushes robooster-claude changes with automatic version increment, or syncs remote changes from teammates
user-invocable: true
---

# robooster-claude-updating

Streamlined release workflow for robooster-claude plugin with single confirmation gate.

---

## Phase 1: Gather Information

**Goal:** Collect all data needed for confirmation (read-only operations only)

**Steps:**

1. **Store original working directory** — Run `pwd` and save as `ORIGINAL_CWD`

2. **Find robooster-claude repository:**

   Check if `$PWD/robooster-claude` exists:
   ```bash
   [ -d "$PWD/robooster-claude/.git" ] && ROBOOSTER_CLAUDE_DIR="$PWD/robooster-claude"
   ```

   If not found, ask user for the path.

3. **Check for changes:**
   ```bash
   cd $ROBOOSTER_CLAUDE_DIR
   GIT_STATUS=$(git status --short)
   git fetch origin main --quiet
   REMOTE_COMMITS=$(git log HEAD..origin/main --oneline)
   REMOTE_COUNT=$(echo "$REMOTE_COMMITS" | grep -c . || echo 0)
   ```

   **Decision matrix:**
   | Local Changes | Remote Commits | Action |
   |---------------|----------------|--------|
   | Yes | Any | `MODE=release` → continue to step 4 |
   | No | Yes | `MODE=sync` → skip to Phase 2 (sync flow) |
   | No | No | Exit: "Already up to date. Local and remote are in sync." |

   For sync mode, also read the new version from remote:
   ```bash
   REMOTE_VERSION=$(git show origin/main:.claude-plugin/plugin.json | grep '"version"' | sed 's/.*"version": *"\([^"]*\)".*/\1/')
   ```

**Steps 4-6 apply only to RELEASE mode. Skip to Phase 2 for SYNC mode.**

4. **Read current version** from `.claude-plugin/plugin.json`

5. **Determine version increment:**

   Analyze files matching `skills/` or `agents/` in `GIT_STATUS`:

   - **Minor bump** if any file is: added (A), deleted (D), renamed (R), or untracked (??)
   - **Minor bump** if any modified file has: >20 lines changed OR frontmatter changes (name/description/user-invocable)
   - **Patch bump** for all other modifications

   Calculate new version:
   - Minor: `major.(minor+1).0`
   - Patch: `major.minor.(patch+1)`

6. **Compose commit message:**
   ```
   chore: bump version to {NEW_VERSION}

   Changes:
   - {list each changed file from GIT_STATUS}
   ```

**Proceed to Phase 2**

---

## Phase 2: Confirm with User

**Goal:** Single confirmation gate before any modifications

### Release Mode Confirmation

Present confirmation using **AskUserQuestion**:

**Question:** "Ready to update robooster-claude?"

Include in description:
- Repository path
- Changes (GIT_STATUS)
- Version: `{CURRENT}` → `{NEW}` ({increment_type} bump)
- Commit message

**Options:**

| Option | Label | Description |
|--------|-------|-------------|
| 1 | **Approve** (Recommended) | Proceed with the proposed version and commit |
| 2 | **Use patch instead** | Override to patch increment (X.Y.Z+1) |
| 3 | **Use minor instead** | Override to minor increment (X.Y+1.0) |
| 4 | **Abort** | Cancel the update |

**Handle response:**
- **Abort:** Exit with "Update cancelled. No changes were made."
- **Override:** Recalculate version, update commit message, proceed
- **Approve:** Proceed with current values

### Sync Mode Confirmation

Present confirmation using **AskUserQuestion**:

**Question:** "Pull remote changes?"

Include in description:
- Repository path
- Commits to pull: `{REMOTE_COUNT}` new commits
- Preview (first 5 commits from REMOTE_COMMITS)
- Version on remote: `{REMOTE_VERSION}`

**Options:**

| Option | Label | Description |
|--------|-------|-------------|
| 1 | **Pull & Update** (Recommended) | Pull commits and update local plugin |
| 2 | **Abort** | Cancel sync |

**Handle response:**
- **Abort:** Exit with "Sync cancelled. No changes were made."
- **Pull & Update:** Proceed to Phase 3 (sync mode)

**Proceed to Phase 3**

---

## Phase 3: Execute Script

**Goal:** Atomically execute version update, commit, rebase, push, and local plugin update

### Release Mode

Run the update script:

```bash
"{ROBOOSTER_CLAUDE_DIR}/scripts/update-plugin.sh" "{NEW_VERSION}" "{COMMIT_MESSAGE}" "{ROBOOSTER_CLAUDE_DIR}" "{ORIGINAL_CWD}"
```

### Sync Mode

Run the sync script:

```bash
"{ROBOOSTER_CLAUDE_DIR}/scripts/update-plugin.sh" --sync "{ROBOOSTER_CLAUDE_DIR}" "{ORIGINAL_CWD}"
```

The script outputs JSON:
- Success: `{"status":"success","version":"X.Y.Z","mode":"release|sync","marketplace_updated":true,"plugin_updated":true,"plugin_scope":"project"}`
- Error: `{"status":"error","step":"<step>","message":"<msg>"}`

**Proceed to Phase 4**

---

## Phase 4: Report Results

### Release Mode Success

> ## Update Complete
>
> **Version:** `{CURRENT}` → `{NEW}`
>
> **Actions completed:**
> - Version updated in plugin.json and marketplace.json
> - Changes committed and pushed to origin/main
> - Local marketplace updated: ✓/✗
> - Local plugin updated: ✓/✗ (scope: project/user)

If warnings present, list them.

Always end with:
> **Restart Claude Code for changes to take effect.**

### Sync Mode Success

> ## Sync Complete
>
> **Pulled:** `{REMOTE_COUNT}` commits
> **Version:** `{REMOTE_VERSION}`
>
> **Actions completed:**
> - Pulled latest from origin/main
> - Local marketplace updated: ✓/✗
> - Local plugin updated: ✓/✗ (scope: project/user)

If warnings present, list them.

Always end with:
> **Restart Claude Code for changes to take effect.**

### On Error

> ## Update Failed
>
> **Step:** `{step}`
> **Error:** `{message}`

**Remediation by step:**

| Step | Advice |
|------|--------|
| `validate` | Check arguments |
| `navigate` | Verify repo path exists |
| `update_plugin_json` / `update_marketplace_json` | Check file permissions |
| `git_add` / `git_commit` | Check git status, resolve issues |
| `rebase` | Run `git rebase --abort`, resolve conflicts manually |
| `push` | Check remote access, try `git push origin main` manually |
| `pull` | Check for uncommitted changes, resolve conflicts manually |
| `marketplace_update` | Run: `claude plugin marketplace update robooster-marketplace` |
| `plugin_update` | Run: `claude plugin update robooster-claude@robooster-marketplace` |

---

## Rules

1. **Phase 1 is read-only** — No modifications until user confirms
2. **Single confirmation gate** — One AskUserQuestion in Phase 2
3. **Atomic script execution** — All git operations handled by shell script
4. **Stop immediately on errors** — Script reports step and message
