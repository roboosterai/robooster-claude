#!/bin/bash
# Links robooster-claude shared rules into ~/.claude/rules/
# Run once per machine. Re-run is safe (overwrites existing symlink).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RULES_SOURCE="$SCRIPT_DIR/../shared-rules"
TARGET_DIR="$HOME/.claude/rules/robooster-shared"

mkdir -p "$HOME/.claude/rules"
ln -sfn "$RULES_SOURCE" "$TARGET_DIR"

echo "✅ Linked: $TARGET_DIR → $RULES_SOURCE"
echo "   Rules will load in every Claude Code session."
