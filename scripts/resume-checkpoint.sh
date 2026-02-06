#!/bin/bash
# Resume skill checkpoint after context compacting
# Triggered by: SessionStart hook on compact
# Output: stdout is injected into Claude's context

CHECKPOINT="$CLAUDE_PROJECT_DIR/.claude/skill-checkpoint.md"

if [ -f "$CHECKPOINT" ]; then
  cat "$CHECKPOINT"
fi

exit 0
