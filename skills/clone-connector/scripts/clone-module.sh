#!/bin/bash
# Clone a Hyperswitch connector module with systematic identifier renaming.
#
# Usage:
#   ./clone-module.sh <repo_root> <source> <target> <SrcPascal> <TgtPascal> <SrcDisplay> <TgtDisplay>
#
# Example:
#   ./clone-module.sh /path/to/platro-hs-backend indiapay indiapay_q Indiapay IndiapayQ "IndiaPay" "IndiaPay Q"
#
# This script:
#   1. Copies the connector module files (handles both flat-file and directory-module structures)
#   2. Applies systematic identifier renames via sed
#   3. Verifies zero stale references remain
#   4. Confirms line counts match source

set -euo pipefail

if [ $# -ne 7 ]; then
  echo "Usage: $0 <repo_root> <source> <target> <SrcPascal> <TgtPascal> <SrcDisplay> <TgtDisplay>"
  echo "Example: $0 /path/to/platro-hs-backend indiapay indiapay_q Indiapay IndiapayQ \"IndiaPay\" \"IndiaPay Q\""
  exit 1
fi

REPO_ROOT="$1"
SOURCE="$2"
TARGET="$3"
SRC_PASCAL="$4"
TGT_PASCAL="$5"
SRC_DISPLAY="$6"
TGT_DISPLAY="$7"

# Derive uppercase forms
SRC_UPPER=$(echo "$SOURCE" | tr '[:lower:]' '[:upper:]')
TGT_UPPER=$(echo "$TARGET" | tr '[:lower:]' '[:upper:]')

CONNECTORS_DIR="$REPO_ROOT/crates/hyperswitch_connectors/src/connectors"

if [ ! -f "$CONNECTORS_DIR/$SOURCE.rs" ]; then
  echo "ERROR: Source connector file not found: $CONNECTORS_DIR/$SOURCE.rs"
  exit 1
fi

if [ -f "$CONNECTORS_DIR/$TARGET.rs" ]; then
  echo "ERROR: Target connector already exists: $CONNECTORS_DIR/$TARGET.rs"
  exit 1
fi

echo "Cloning connector: $SOURCE -> $TARGET"
echo "  PascalCase: $SRC_PASCAL -> $TGT_PASCAL"
echo "  Display:    $SRC_DISPLAY -> $TGT_DISPLAY"
echo "  UPPER:      ${SRC_UPPER}_ -> ${TGT_UPPER}_"
echo ""

# ── Step 1: Copy files ──────────────────────────────────────────────────────

echo "Step 1: Copying files..."

cp "$CONNECTORS_DIR/$SOURCE.rs" "$CONNECTORS_DIR/$TARGET.rs"
echo "  Copied $SOURCE.rs -> $TARGET.rs"

if [ -d "$CONNECTORS_DIR/$SOURCE" ]; then
  mkdir -p "$CONNECTORS_DIR/$TARGET"
  for subfile in "$CONNECTORS_DIR/$SOURCE"/*.rs; do
    [ -f "$subfile" ] || continue
    basename=$(basename "$subfile")
    cp "$subfile" "$CONNECTORS_DIR/$TARGET/$basename"
    echo "  Copied $SOURCE/$basename -> $TARGET/$basename"
  done
fi

# ── Step 2: Apply sed renames ────────────────────────────────────────────────

echo ""
echo "Step 2: Applying identifier renames..."

TARGET_FILES=("$CONNECTORS_DIR/$TARGET.rs")
if [ -d "$CONNECTORS_DIR/$TARGET" ]; then
  for subfile in "$CONNECTORS_DIR/$TARGET"/*.rs; do
    [ -f "$subfile" ] && TARGET_FILES+=("$subfile")
  done
fi

# Apply sed rules in strict order to each file
# Order matters: most specific patterns first, most general last
for f in "${TARGET_FILES[@]}"; do
  fname=$(basename "$f")
  sed -i '' \
    -e "s/${SRC_UPPER}_/${TGT_UPPER}_/g" \
    -e "s/connectors\.${SOURCE}\./connectors.${TARGET}./g" \
    -e "s/as ${SOURCE};/as ${TARGET};/g" \
    -e "s/${SOURCE}::/${TARGET}::/g" \
    -e "s/${SOURCE}_connector/${TARGET}_connector/g" \
    -e "s/\"${SOURCE}\"/\"${TARGET}\"/g" \
    -e "s/${SRC_DISPLAY}/${TGT_DISPLAY}/g" \
    -e "s/${SRC_PASCAL}/${TGT_PASCAL}/g" \
    "$f"
  echo "  Renamed identifiers in $fname"
done

# ── Step 3: Verify ──────────────────────────────────────────────────────────

echo ""
echo "Step 3: Verifying..."

ERRORS=0

# Check for stale PascalCase references
STALE_PASCAL=$(grep -rn "${SRC_PASCAL}" "$CONNECTORS_DIR/$TARGET.rs" "$CONNECTORS_DIR/$TARGET/" 2>/dev/null | grep -v "${TGT_PASCAL}" || true)
if [ -n "$STALE_PASCAL" ]; then
  echo "  FAIL: Stale ${SRC_PASCAL} references found:"
  echo "$STALE_PASCAL"
  ERRORS=$((ERRORS + 1))
else
  echo "  PASS: No stale ${SRC_PASCAL} references"
fi

# Check for stale quoted string literals
STALE_STRING=$(grep -rn "\"${SOURCE}\"" "$CONNECTORS_DIR/$TARGET.rs" "$CONNECTORS_DIR/$TARGET/" 2>/dev/null || true)
if [ -n "$STALE_STRING" ]; then
  echo "  FAIL: Stale \"${SOURCE}\" string literals found:"
  echo "$STALE_STRING"
  ERRORS=$((ERRORS + 1))
else
  echo "  PASS: No stale \"${SOURCE}\" string literals"
fi

# Comprehensive check: any remaining source references not covered by target
STALE_ANY=$(grep -rn "${SOURCE}" "$CONNECTORS_DIR/$TARGET.rs" "$CONNECTORS_DIR/$TARGET/" 2>/dev/null | grep -v "${TARGET}" | grep -v "${TGT_PASCAL}" | grep -v "${TGT_UPPER}" | grep -v "${TGT_DISPLAY}" || true)
if [ -n "$STALE_ANY" ]; then
  echo "  WARN: Possible stale references (review manually):"
  echo "$STALE_ANY"
else
  echo "  PASS: No stale references (comprehensive check)"
fi

# Verify line counts match
echo ""
echo "  Line count comparison:"
SRC_MAIN=$(wc -l < "$CONNECTORS_DIR/$SOURCE.rs")
TGT_MAIN=$(wc -l < "$CONNECTORS_DIR/$TARGET.rs")
if [ "$SRC_MAIN" = "$TGT_MAIN" ]; then
  echo "    Main module: $SRC_MAIN -> $TGT_MAIN ✓"
else
  echo "    Main module: $SRC_MAIN -> $TGT_MAIN MISMATCH"
  ERRORS=$((ERRORS + 1))
fi

if [ -d "$CONNECTORS_DIR/$SOURCE" ]; then
  for subfile in "$CONNECTORS_DIR/$SOURCE"/*.rs; do
    [ -f "$subfile" ] || continue
    bname=$(basename "$subfile")
    SRC_LINES=$(wc -l < "$subfile")
    TGT_LINES=$(wc -l < "$CONNECTORS_DIR/$TARGET/$bname")
    if [ "$SRC_LINES" = "$TGT_LINES" ]; then
      echo "    $bname: $SRC_LINES -> $TGT_LINES ✓"
    else
      echo "    $bname: $SRC_LINES -> $TGT_LINES MISMATCH"
      ERRORS=$((ERRORS + 1))
    fi
  done
fi

if [ $ERRORS -gt 0 ]; then
  echo ""
  echo "FAILED: $ERRORS verification error(s)"
  exit 1
fi

echo ""
echo "SUCCESS: Connector module cloned and verified."
echo ""
echo "Files created:"
echo "  $CONNECTORS_DIR/$TARGET.rs"
if [ -d "$CONNECTORS_DIR/$TARGET" ]; then
  for subfile in "$CONNECTORS_DIR/$TARGET"/*.rs; do
    [ -f "$subfile" ] && echo "  $subfile"
  done
fi
