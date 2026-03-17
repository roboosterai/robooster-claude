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

   Try these locations in order (first match wins):

   a. CWD **is** the repo: `basename "$PWD"` == `robooster-claude` and `$PWD/.git` exists
   b. Direct child: `$PWD/robooster-claude/.git` exists
   c. Sibling (from `platro/`): `basename "$PWD"` == `platro` and `$PWD/../robooster-claude/.git` exists
   d. Sibling of parent (from `platro/platro-*/`): `basename "$(dirname "$PWD")"` == `platro` and `$PWD/../../robooster-claude/.git` exists

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

6. **Analyze changes and generate descriptions:**

   For each file in `GIT_STATUS`:

   a. Get the diff:
      - Modified files: `git diff HEAD -- {file}`
      - Staged files: `git diff --cached -- {file}`
      - Untracked files: Read file content directly

   b. Analyze the diff semantically:
      - What functionality was added, changed, fixed, or removed?
      - Focus on user-visible behavior, not implementation details

   c. Categorize the change:
      | Category | When to use |
      |----------|-------------|
      | **Added** | New skills, agents, features, flags |
      | **Changed** | Modified behavior, updated prompts, refactored logic |
      | **Fixed** | Bug corrections, error handling improvements |
      | **Removed** | Deleted skills, agents, deprecated features |

   d. Write a concise description (one line, no file paths)

   **Example analysis:**

   | File | Diff Summary | Category | Description |
   |------|--------------|----------|-------------|
   | `skills/task-implementing/SKILL.md` | Added --muttests argument | Added | `--muttests` flag to task-implementing skill |
   | `agents/test-verifier.md` | New agent file | Added | test-verifier agent for mutation testing |
   | `skills/brainstorming/SKILL.md` | Changed prompt text | Changed | Simplified brainstorming skill prompts |

   Store results as `CHANGELOG_ENTRIES` grouped by category.

7. **Compose commit message:**

   Determine commit type from primary change category:

   | Primary Category | Commit Type |
   |------------------|-------------|
   | Added (new features) | `feat` |
   | Changed (modifications) | `refactor` or `docs` |
   | Fixed (bug fixes) | `fix` |
   | Removed (deletions) | `refactor` |

   Identify the main change for the summary line (most significant or first Added item).

   Format:
   ```
   {type}: {brief summary of main change}

   {CHANGELOG_ENTRIES as bullet list, grouped by category}
   ```

   **Example:**
   ```
   feat: add mutation testing support to task-implementing

   Added:
   - test-verifier agent for mutation testing validation
   - --muttests flag with options: all, new, none

   Changed:
   - Simplified task handoff document format
   ```

8. **Prepare changelog entry:**

   Format `CHANGELOG_ENTRY` for insertion:
   ```markdown
   ## {NEW_VERSION} — {YYYY-MM-DD}

   **Added**
   - {items from CHANGELOG_ENTRIES.Added}

   **Changed**
   - {items from CHANGELOG_ENTRIES.Changed}

   **Fixed**
   - {items from CHANGELOG_ENTRIES.Fixed}

   **Removed**
   - {items from CHANGELOG_ENTRIES.Removed}
   ```

   Only include categories that have entries.

**Proceed to Phase 2**

---

## Phase 2: Confirm with User

**Goal:** Single confirmation gate before any modifications

### Release Mode Confirmation

Present confirmation using **AskUserQuestion**:

**Question:** "Ready to update robooster-claude?"

Include in description:
- Repository path
- Version: `{CURRENT}` → `{NEW}` ({increment_type} bump)
- Changelog entry (formatted):
  ```
  {CHANGELOG_ENTRY}
  ```
- Commit message:
  ```
  {COMMIT_MESSAGE}
  ```

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

1. **Update CHANGELOG.md:**

   Read `{ROBOOSTER_CLAUDE_DIR}/CHANGELOG.md`

   Find the line containing `# Changelog`

   Insert `CHANGELOG_ENTRY` immediately after that line (with a blank line separator)

   Write the updated content back to the file

   **Example before:**
   ```markdown
   # Changelog

   ## 2.2.0 — 2026-02-02
   ...
   ```

   **Example after:**
   ```markdown
   # Changelog

   ## 2.2.1 — 2026-02-03

   **Fixed**
   - Corrected prompt wording in brainstorming skill

   ## 2.2.0 — 2026-02-02
   ...
   ```

2. **Run the update script:**

   ```bash
   "{ROBOOSTER_CLAUDE_DIR}/scripts/update-plugin.sh" "{NEW_VERSION}" "{COMMIT_MESSAGE}" "{ROBOOSTER_CLAUDE_DIR}" "{ORIGINAL_CWD}"
   ```

   The script's `git add -A` automatically stages the updated CHANGELOG.md.

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
> **Changelog:**
> {CHANGELOG_ENTRY}
>
> **Actions completed:**
> - CHANGELOG.md updated
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
