#!/bin/bash
# Add a new connector to all default implementation macro lists.
#
# Usage:
#   ./add-default-impls.sh <repo_root> <SrcPascal> <TgtPascal>
#
# Example:
#   ./add-default-impls.sh /path/to/platro-hs-backend Indiapay IndiapayQ
#
# For every line matching `connectors::{SrcPascal},` in both default_implementations
# files, inserts `    connectors::{TgtPascal},` on the next line.

set -euo pipefail

if [ $# -ne 3 ]; then
  echo "Usage: $0 <repo_root> <SrcPascal> <TgtPascal>"
  echo "Example: $0 /path/to/platro-hs-backend Indiapay IndiapayQ"
  exit 1
fi

REPO_ROOT="$1"
SRC_PASCAL="$2"
TGT_PASCAL="$3"

IMPL_DIR="$REPO_ROOT/crates/hyperswitch_connectors/src"
FILE_V1="$IMPL_DIR/default_implementations.rs"
FILE_V2="$IMPL_DIR/default_implementations_v2.rs"

for f in "$FILE_V1" "$FILE_V2"; do
  if [ ! -f "$f" ]; then
    echo "ERROR: File not found: $f"
    exit 1
  fi
done

# Check target doesn't already exist
for f in "$FILE_V1" "$FILE_V2"; do
  fname=$(basename "$f")
  existing=$(grep -c "connectors::${TGT_PASCAL}," "$f" || true)
  if [ "$existing" -gt 0 ]; then
    echo "ERROR: ${TGT_PASCAL} already exists in $fname ($existing entries)"
    exit 1
  fi
done

echo "Adding connectors::${TGT_PASCAL} after connectors::${SRC_PASCAL} in default implementations..."
echo ""

ERRORS=0

for f in "$FILE_V1" "$FILE_V2"; do
  fname=$(basename "$f")

  # Count source entries before
  src_count=$(grep -c "connectors::${SRC_PASCAL}," "$f")

  # Insert target after each source entry
  sed -i '' "/connectors::${SRC_PASCAL},/a\\
    connectors::${TGT_PASCAL}," "$f"

  # Count target entries after
  tgt_count=$(grep -c "connectors::${TGT_PASCAL}," "$f")

  if [ "$src_count" = "$tgt_count" ]; then
    echo "  $fname: $tgt_count entries added (matches $src_count source entries) ✓"
  else
    echo "  $fname: MISMATCH — $src_count source vs $tgt_count target entries"
    ERRORS=$((ERRORS + 1))
  fi

  # Verify every source is immediately followed by target
  unpaired=$( (grep -A1 "connectors::${SRC_PASCAL}," "$f" || true) | grep -v "connectors::${SRC_PASCAL}," | grep -v "connectors::${TGT_PASCAL}," | (grep -v '^--$' || true) | wc -l | tr -d ' ')
  if [ "$unpaired" -gt 0 ]; then
    echo "  $fname: FAIL — $unpaired entries not properly paired"
    ERRORS=$((ERRORS + 1))
  else
    echo "  $fname: All entries properly paired ✓"
  fi
done

if [ $ERRORS -gt 0 ]; then
  echo ""
  echo "FAILED: $ERRORS verification error(s)"
  exit 1
fi

echo ""
echo "SUCCESS: Default implementations updated and verified."
