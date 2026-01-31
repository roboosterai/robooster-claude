---
name: robooster-claude-update
description: Commits and pushes robooster-claude changes with automatic version increment
user-invocable: true
---

# robooster-claude-update

Automate the robooster-claude release workflow with human gates at critical steps.

## Workflow

Execute phases in order. Use `AskUserQuestion` for all human gates.

---

### Phase 1: Check Status

**Goal:** Verify there are changes to commit

**Actions:**

1. **Navigate to robooster-claude directory:**

   ```bash
   cd /Users/bedzhanyan/robooster_projects/robooster-claude
   ```

2. **Run git status:**

   ```bash
   git status --short
   ```

3. **If no changes:**
   > No changes detected in robooster-claude. Nothing to do.

   **Exit skill.**

4. **If changes exist, show summary:**
   > **Changes detected:**
   > ```
   > {git status output}
   > ```

**Proceed when:** Changes detected

---

### Phase 2: Determine Version Increment

**Goal:** Analyze changes and propose version bump

**Actions:**

1. **Read current version from plugin.json:**

   ```bash
   cat .claude-plugin/plugin.json | grep version
   ```

2. **Analyze changed files to determine increment:**

   | Change Type | Increment | Examples |
   |-------------|-----------|----------|
   | `skills/` or `agents/` directories | **minor** | New skill, new agent, new feature |
   | Everything else | **patch** | Bug fixes, docs, config tweaks |
   | Breaking changes (explicit) | **major** | Only if user mentions breaking changes |

3. **Calculate new version:**
   - Parse current version (e.g., `1.1.9`)
   - Apply increment:
     - patch: `1.1.9` → `1.1.10`
     - minor: `1.1.9` → `1.2.0`
     - major: `1.1.9` → `2.0.0`

4. **Present to user:**
   > **Version bump proposal:**
   > - Current: `{current_version}`
   > - Proposed: `{new_version}` ({increment_type})
   > - Reason: {why this increment}

5. **Ask for override using AskUserQuestion:**

   **Question:** "Is this version increment correct?"

   **Options:**
   | Option | Description |
   |--------|-------------|
   | **Yes, proceed** | Use the proposed version |
   | **Use patch instead** | Bump only patch version (0.0.x) |
   | **Use minor instead** | Bump minor version (0.x.0) |
   | **Use major instead** | Bump major version (x.0.0) |

**Proceed when:** Version increment confirmed

---

### Phase 3: Update Version & Commit (Gate G1)

**Goal:** Update version files, stage changes, and confirm commit

**Actions:**

1. **Update version in both files:**

   - `.claude-plugin/plugin.json` — update `"version": "{new_version}"`
   - `.claude-plugin/marketplace.json` — update `"version": "{new_version}"` in plugins[0]

   Use the Edit tool for both files.

2. **Stage all changes:**

   ```bash
   git add -A
   ```

3. **Show diff summary:**

   ```bash
   git diff --cached --stat
   ```

4. **Compose commit message:**

   ```
   chore: bump version to {new_version}

   Changes:
   - {list of changed files/directories from git status}
   ```

5. **Human Gate G1 using AskUserQuestion:**

   **Question:** "Ready to commit with this message?"

   Show the commit message in the question description.

   **Options:**
   | Option | Description |
   |--------|-------------|
   | **Yes, commit** | Create the commit |
   | **Edit message** | Let me modify the commit message |
   | **Abort** | Cancel the update process |

6. **If "Edit message":** Ask user for new message, then re-confirm.

7. **If "Abort":** Reset staged changes and exit:
   ```bash
   git reset HEAD
   ```
   > Update aborted.

8. **Create commit:**

   ```bash
   git commit -m "$(cat <<'EOF'
   {commit_message}
   EOF
   )"
   ```

**Proceed when:** Commit created successfully

---

### Phase 4: Pull Rebase (Gate G2)

**Goal:** Sync with remote and handle any conflicts

**Actions:**

1. **Pull with rebase:**

   ```bash
   git pull --rebase origin main
   ```

2. **Check for conflicts:**

   ```bash
   git status
   ```

3. **If conflicts detected:**
   > ⚠️ **Rebase conflict detected!**
   >
   > Please resolve conflicts manually, then run this skill again.
   >
   > To abort the rebase:
   > ```bash
   > git rebase --abort
   > ```

   **Exit skill.**

4. **If successful, Human Gate G2 using AskUserQuestion:**

   **Question:** "Rebase successful. Ready to push?"

   **Options:**
   | Option | Description |
   |--------|-------------|
   | **Yes, continue to push** | Proceed to push changes |
   | **Abort** | Cancel (will need manual cleanup) |

**Proceed when:** User confirms ready to push

---

### Phase 5: Push (Gate G3)

**Goal:** Push changes to remote

**Actions:**

1. **Human Gate G3 using AskUserQuestion:**

   **Question:** "Confirm push to main branch?"

   **Options:**
   | Option | Description |
   |--------|-------------|
   | **Yes, push** | Push changes to origin/main |
   | **Abort** | Cancel the push |

2. **If "Abort":**
   > Push aborted. Your commit is local only.
   >
   > To push later: `git push origin main`

   **Exit skill.**

3. **Push to remote:**

   ```bash
   git push origin main
   ```

4. **Confirm success:**
   > ✓ Pushed to origin/main

**Proceed when:** Push successful

---

### Phase 6: Local Update

**Goal:** Update local marketplace and plugin installation

**Actions:**

1. **Update marketplace:**

   ```bash
   claude plugin marketplace update robooster-marketplace
   ```

2. **Check plugin scope:**

   ```bash
   claude plugin list | grep -A3 "robooster-claude"
   ```

   Look for the `Scope:` line in the output.

3. **Update plugin based on scope:**

   **If scope is `user`:**
   ```bash
   claude plugin update robooster-claude@robooster-marketplace
   ```

   **If scope is `project`:**
   ```bash
   cd /Users/bedzhanyan/robooster_projects && claude plugin update robooster-claude@robooster-marketplace --scope project
   ```

   Note: The plugin is installed at the parent project directory, not within robooster-claude itself.

4. **Final summary:**

   > ## Update Complete
   >
   > **Version:** `{old_version}` → `{new_version}`
   >
   > **What happened:**
   > - ✓ Version updated in plugin.json and marketplace.json
   > - ✓ Changes committed
   > - ✓ Pushed to origin/main
   > - ✓ Local marketplace updated
   > - ✓ Local plugin updated
   >
   > **Next step:** Restart Claude Code for changes to take effect.

**Session complete.**

---

## Human Gates

| Gate | Phase | Question | Pass | Fail |
|------|-------|----------|------|------|
| G1 | Phase 3 | "Ready to commit with this message?" | Create commit | Abort or edit |
| G2 | Phase 4 | "Rebase successful. Ready to push?" | Continue | Abort |
| G3 | Phase 5 | "Confirm push to main branch?" | Push | Abort |

---

## Version Increment Logic

```
IF any file in skills/ or agents/ changed:
    increment = "minor"
ELSE:
    increment = "patch"

# User can override to any increment type
# "major" only used if user explicitly selects it
```

---

## Commit Message Format

```
chore: bump version to {version}

Changes:
- {file1}
- {file2}
- ...
```

---

## Rules

1. **Always work in robooster-claude directory** — All git commands run there
2. **Both version files must stay in sync** — plugin.json and marketplace.json
3. **Stop immediately on rebase conflicts** — User must resolve manually
4. **All 3 human gates are mandatory** — Never skip confirmation steps
5. **Exit cleanly on abort** — Reset staged changes if aborting before commit
6. **No force push** — Always use regular push to main
