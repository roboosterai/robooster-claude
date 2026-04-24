#!/bin/bash
# Add target connector base_url after source connector base_url in all config TOML files.
#
# Usage:
#   ./add-toml-base-urls.sh <repo_root> <source> <target>
#
# Example:
#   ./add-toml-base-urls.sh /path/to/platro-hs-backend indiapay indiapay_q
#
# Finds all .toml files under config/ and loadtest/config/ that contain
# {source}.base_url and inserts {target}.base_url with the same URL value
# on the next line.

set -euo pipefail

if [ $# -ne 3 ]; then
  echo "Usage: $0 <repo_root> <source> <target>"
  echo "Example: $0 /path/to/platro-hs-backend indiapay indiapay_q"
  exit 1
fi

REPO_ROOT="$1"
SOURCE="$2"
TARGET="$3"

# Find all TOML files with source.base_url
TOML_FILES=()
while IFS= read -r f; do
  TOML_FILES+=("$f")
done < <(grep -rl "^${SOURCE}\.base_url" "$REPO_ROOT/config/" "$REPO_ROOT/loadtest/" --include='*.toml' 2>/dev/null | sort)

if [ ${#TOML_FILES[@]} -eq 0 ]; then
  echo "ERROR: No TOML files found with ${SOURCE}.base_url"
  exit 1
fi

# Check target doesn't already exist
for f in "${TOML_FILES[@]}"; do
  if grep -q "^${TARGET}\.base_url" "$f"; then
    echo "ERROR: ${TARGET}.base_url already exists in $(basename "$f")"
    exit 1
  fi
done

echo "Adding ${TARGET}.base_url after ${SOURCE}.base_url in ${#TOML_FILES[@]} TOML files..."
echo ""

ERRORS=0

for f in "${TOML_FILES[@]}"; do
  fname=$(echo "$f" | sed "s|${REPO_ROOT}/||")

  # Extract the URL value from the source line
  url=$(grep "^${SOURCE}\.base_url" "$f" | head -1 | sed "s/^${SOURCE}\.base_url *= *//")

  # Insert target line after source line
  sed -i '' "/^${SOURCE}\.base_url/a\\
${TARGET}.base_url = ${url}" "$f"

  # Verify insertion
  if grep -q "^${TARGET}\.base_url" "$f"; then
    echo "  $fname: added ${TARGET}.base_url = ${url} ✓"
  else
    echo "  $fname: FAIL — insertion not found"
    ERRORS=$((ERRORS + 1))
  fi
done

if [ $ERRORS -gt 0 ]; then
  echo ""
  echo "FAILED: $ERRORS verification error(s)"
  exit 1
fi

echo ""
echo "SUCCESS: ${#TOML_FILES[@]} TOML files updated."
