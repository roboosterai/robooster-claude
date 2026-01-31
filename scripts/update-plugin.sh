#!/bin/bash
# update-plugin.sh
# Atomically updates robooster-claude plugin version, commits, rebases, and pushes
#
# Usage: update-plugin.sh <new_version> <commit_message> [repo_path]
#
# Arguments:
#   new_version    - Version string (e.g., "1.2.5")
#   commit_message - Full commit message
#   repo_path      - Optional path to repo (defaults to current directory)
#
# Output: JSON to stdout
#   Success: {"status":"success","version":"1.2.5"}
#   Error:   {"status":"error","step":"<step_name>","message":"<error_message>"}

set -o pipefail

# JSON output helpers
json_success() {
    echo "{\"status\":\"success\",\"version\":\"$1\"}"
    exit 0
}

json_error() {
    local step="$1"
    local message="$2"
    # Escape quotes and newlines in message for valid JSON
    message=$(echo "$message" | sed 's/"/\\"/g' | tr '\n' ' ')
    echo "{\"status\":\"error\",\"step\":\"$step\",\"message\":\"$message\"}"
    exit 1
}

# Arguments
NEW_VERSION="$1"
COMMIT_MESSAGE="$2"
REPO_PATH="${3:-.}"

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

# Success
json_success "$NEW_VERSION"
