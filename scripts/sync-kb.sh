#!/bin/bash
# KB Auto-Sync Hook
# Syncs KB files to GitHub after Write/Edit operations
#
# Triggered by: PostToolUse hook on Write|Edit
# Receives: JSON via stdin with tool_input.file_path

# Debug log
DEBUG_LOG="/tmp/hook-debug.log"

# Read JSON input from stdin
INPUT=$(cat)
echo "INPUT: $INPUT" >> "$DEBUG_LOG"

FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
echo "FILE_PATH: $FILE_PATH" >> "$DEBUG_LOG"

# Exit if no file path
[ -z "$FILE_PATH" ] && { echo "No file path - exiting" >> "$DEBUG_LOG"; exit 0; }

# Only sync KB paths (platro-kb or root kb)
if [[ "$FILE_PATH" == *"/platro-kb/"* ]] || [[ "$FILE_PATH" == *"/kb/"* ]]; then
  echo "Path matches KB pattern" >> "$DEBUG_LOG"

  # Find the git repo root for this file
  REPO_ROOT=$(cd "$(dirname "$FILE_PATH")" && git rev-parse --show-toplevel 2>/dev/null)
  echo "REPO_ROOT: $REPO_ROOT" >> "$DEBUG_LOG"
  [ -z "$REPO_ROOT" ] && { echo "No repo root - exiting" >> "$DEBUG_LOG"; exit 0; }

  cd "$REPO_ROOT" || exit 0
  echo "Changed to: $(pwd)" >> "$DEBUG_LOG"

  # Stage, commit, pull-rebase, push
  git add -A
  git commit -m "Auto-sync: $(date '+%Y-%m-%d %H:%M')" 2>/dev/null || exit 0
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
