#!/bin/bash
# KB Auto-Sync Hook
# Syncs platro-kb files to GitHub after Write/Edit operations
#
# Triggered by: PostToolUse hook on Write|Edit
# Receives: JSON via stdin with tool_input.file_path

# Read JSON input from stdin
INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

# Exit if no file path
[ -z "$FILE_PATH" ] && exit 0

# Only sync platro-kb paths
if [[ "$FILE_PATH" == *"/platro-kb/"* ]]; then
  # Find the git repo root for this file
  REPO_ROOT=$(cd "$(dirname "$FILE_PATH")" && git rev-parse --show-toplevel 2>/dev/null)
  [ -z "$REPO_ROOT" ] && exit 0

  cd "$REPO_ROOT" || exit 0

  # Get GitHub username
  GH_USER=$(gh api user -q .login 2>/dev/null || echo "unknown")

  # Stage, commit, pull-rebase, push
  git add -A
  git commit -m "Auto-sync by ${GH_USER}: $(date '+%Y-%m-%d %H:%M')" 2>/dev/null || exit 0
  git pull --rebase 2>/dev/null || {
    echo "Rebase conflict - manual resolution needed" >&2
    exit 0  # Non-blocking, don't fail the hook
  }
  git push 2>/dev/null || {
    echo "Push failed - will retry next sync" >&2
    exit 0
  }
fi

exit 0
