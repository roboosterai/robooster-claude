#!/bin/bash
# update-plugin.sh
# Atomically updates robooster-claude plugin version, commits, rebases, pushes,
# and updates local marketplace/plugin
#
# Usage: update-plugin.sh <new_version> <commit_message> [repo_path] [original_cwd]
#
# Arguments:
#   new_version    - Version string (e.g., "1.2.5")
#   commit_message - Full commit message
#   repo_path      - Optional path to repo (defaults to current directory)
#   original_cwd   - Optional directory to return to for plugin operations
#
# Output: JSON to stdout
#   Success: {"status":"success","version":"1.2.5","marketplace_updated":true,"plugin_updated":true,"plugin_scope":"project"}
#   Success with warnings: {"status":"success","version":"1.2.5",...,"warnings":["message"]}
#   Error:   {"status":"error","step":"<step_name>","message":"<error_message>"}

set -o pipefail

# JSON output helpers
# These variables accumulate state for the final JSON output
WARNINGS=()
MARKETPLACE_UPDATED="false"
PLUGIN_UPDATED="false"
PLUGIN_SCOPE=""

escape_json() {
    # Escape quotes and newlines in string for valid JSON
    echo "$1" | sed 's/"/\\"/g' | tr '\n' ' '
}

json_success() {
    local version="$1"
    local output="{\"status\":\"success\",\"version\":\"$version\""
    output+=",\"marketplace_updated\":$MARKETPLACE_UPDATED"
    output+=",\"plugin_updated\":$PLUGIN_UPDATED"
    if [ -n "$PLUGIN_SCOPE" ]; then
        output+=",\"plugin_scope\":\"$PLUGIN_SCOPE\""
    fi
    if [ ${#WARNINGS[@]} -gt 0 ]; then
        output+=",\"warnings\":["
        local first=true
        for warning in "${WARNINGS[@]}"; do
            if [ "$first" = true ]; then
                first=false
            else
                output+=","
            fi
            output+="\"$(escape_json "$warning")\""
        done
        output+="]"
    fi
    output+="}"
    echo "$output"
    exit 0
}

json_error() {
    local step="$1"
    local message="$2"
    message=$(escape_json "$message")
    echo "{\"status\":\"error\",\"step\":\"$step\",\"message\":\"$message\"}"
    exit 1
}

# Arguments
NEW_VERSION="$1"
COMMIT_MESSAGE="$2"
REPO_PATH="${3:-.}"
ORIGINAL_CWD="${4:-}"

# Step 1: Validate arguments
if [ -z "$NEW_VERSION" ]; then
    json_error "validate" "Missing required argument: new_version"
fi

if [ -z "$COMMIT_MESSAGE" ]; then
    json_error "validate" "Missing required argument: commit_message"
fi

# Validate version format (semver-like: X.Y.Z)
if ! echo "$NEW_VERSION" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$'; then
    json_error "validate" "Invalid version format: $NEW_VERSION (expected X.Y.Z)"
fi

# Step 2: Navigate to repo
if ! cd "$REPO_PATH" 2>/dev/null; then
    json_error "navigate" "Cannot navigate to repository: $REPO_PATH"
fi

# Verify we're in a git repo
if ! git rev-parse --git-dir >/dev/null 2>&1; then
    json_error "navigate" "Not a git repository: $REPO_PATH"
fi

# Verify required files exist
PLUGIN_JSON=".claude-plugin/plugin.json"
MARKETPLACE_JSON=".claude-plugin/marketplace.json"

if [ ! -f "$PLUGIN_JSON" ]; then
    json_error "validate" "File not found: $PLUGIN_JSON"
fi

if [ ! -f "$MARKETPLACE_JSON" ]; then
    json_error "validate" "File not found: $MARKETPLACE_JSON"
fi

# Step 3: Update version in plugin.json
if ! sed -i '' "s/\"version\": *\"[^\"]*\"/\"version\": \"$NEW_VERSION\"/" "$PLUGIN_JSON" 2>/dev/null; then
    json_error "update_plugin_json" "Failed to update version in $PLUGIN_JSON"
fi

# Verify the update was applied
if ! grep -q "\"version\": \"$NEW_VERSION\"" "$PLUGIN_JSON"; then
    json_error "update_plugin_json" "Version update not applied to $PLUGIN_JSON"
fi

# Step 4: Update version in marketplace.json
if ! sed -i '' "s/\"version\": *\"[^\"]*\"/\"version\": \"$NEW_VERSION\"/" "$MARKETPLACE_JSON" 2>/dev/null; then
    json_error "update_marketplace_json" "Failed to update version in $MARKETPLACE_JSON"
fi

# Verify the update was applied
if ! grep -q "\"version\": \"$NEW_VERSION\"" "$MARKETPLACE_JSON"; then
    json_error "update_marketplace_json" "Version update not applied to $MARKETPLACE_JSON"
fi

# Step 5: Stage all changes
if ! git add -A 2>&1; then
    json_error "git_add" "Failed to stage changes"
fi

# Step 6: Commit
COMMIT_OUTPUT=$(git commit -m "$COMMIT_MESSAGE" 2>&1)
COMMIT_STATUS=$?
if [ $COMMIT_STATUS -ne 0 ]; then
    # Check if it's "nothing to commit"
    if echo "$COMMIT_OUTPUT" | grep -q "nothing to commit"; then
        json_error "git_commit" "Nothing to commit - no changes detected"
    fi
    json_error "git_commit" "$COMMIT_OUTPUT"
fi

# Step 7: Pull with rebase
REBASE_OUTPUT=$(git pull --rebase origin main 2>&1)
REBASE_STATUS=$?
if [ $REBASE_STATUS -ne 0 ]; then
    # Check for conflict indicators
    if echo "$REBASE_OUTPUT" | grep -qiE "(conflict|cannot rebase|CONFLICT)"; then
        json_error "rebase" "Conflict detected. Run: git rebase --abort"
    fi
    json_error "rebase" "$REBASE_OUTPUT"
fi

# Step 8: Push
PUSH_OUTPUT=$(git push origin main 2>&1)
PUSH_STATUS=$?
if [ $PUSH_STATUS -ne 0 ]; then
    json_error "push" "$PUSH_OUTPUT"
fi

# --- Git operations complete. Below steps are non-fatal (add warnings on failure) ---

# Step 9: Navigate to original working directory (for plugin operations)
if [ -n "$ORIGINAL_CWD" ]; then
    if ! cd "$ORIGINAL_CWD" 2>/dev/null; then
        WARNINGS+=("Could not return to original directory: $ORIGINAL_CWD")
    fi
fi

# Step 10: Update local marketplace
MARKETPLACE_OUTPUT=$(claude plugin marketplace update robooster-marketplace 2>&1)
MARKETPLACE_STATUS=$?
if [ $MARKETPLACE_STATUS -eq 0 ]; then
    MARKETPLACE_UPDATED="true"
else
    WARNINGS+=("Failed to update marketplace: $MARKETPLACE_OUTPUT")
fi

# Step 11: Detect plugin scope
PLUGIN_LIST_OUTPUT=$(claude plugin list 2>/dev/null)
if echo "$PLUGIN_LIST_OUTPUT" | grep -q "robooster-claude"; then
    # Extract scope from the output (look for Scope: line after robooster-claude)
    SCOPE_LINE=$(echo "$PLUGIN_LIST_OUTPUT" | grep -A5 "robooster-claude" | grep -i "scope:" | head -1)
    if echo "$SCOPE_LINE" | grep -qi "project"; then
        PLUGIN_SCOPE="project"
    elif echo "$SCOPE_LINE" | grep -qi "user"; then
        PLUGIN_SCOPE="user"
    fi
fi

# Step 12: Update local plugin
if [ "$MARKETPLACE_UPDATED" = "true" ]; then
    if [ "$PLUGIN_SCOPE" = "project" ]; then
        PLUGIN_OUTPUT=$(claude plugin update robooster-claude@robooster-marketplace --scope project 2>&1)
    else
        PLUGIN_OUTPUT=$(claude plugin update robooster-claude@robooster-marketplace 2>&1)
    fi
    PLUGIN_STATUS=$?
    if [ $PLUGIN_STATUS -eq 0 ]; then
        PLUGIN_UPDATED="true"
    else
        WARNINGS+=("Failed to update plugin: $PLUGIN_OUTPUT")
    fi
else
    WARNINGS+=("Skipped plugin update because marketplace update failed")
fi

# Success (with possible warnings)
json_success "$NEW_VERSION"
