#!/bin/bash
# Verify a connector clone across backend and optionally frontend repos.
#
# Usage:
#   ./verify-clone.sh <backend_root> <source> <target> <SrcPascal> <TgtPascal> [<cc_root>] [<TGT_UPPER>] [<TgtDisplayVariant>]
#
# Example:
#   ./verify-clone.sh /path/to/platro-hs-backend indiapay indiapay_q Indiapay IndiapayQ /path/to/platro-hs-control-center INDIAPAY_Q IndiaPayQ
#
# <TgtDisplayVariant> is {TgtDisplay} with spaces removed — used to check the
# PlatroConnector enum in crates/platro_observability/src/types.rs. If omitted,
# defaults to <TgtPascal>.

set -uo pipefail

if [ $# -lt 5 ]; then
  echo "Usage: $0 <backend_root> <source> <target> <SrcPascal> <TgtPascal> [<cc_root>] [<TGT_UPPER>] [<TgtDisplayVariant>]"
  exit 1
fi

BACKEND="$1"
SOURCE="$2"
TARGET="$3"
SRC_PASCAL="$4"
TGT_PASCAL="$5"
CC_ROOT="${6:-}"
TGT_UPPER="${7:-$(echo "$TARGET" | tr '[:lower:]' '[:upper:]')}"
TGT_DISPLAY_VARIANT="${8:-$TGT_PASCAL}"

PASS=0
FAIL=0
WARN=0

check_pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
check_fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }
check_warn() { echo "  WARN: $1"; WARN=$((WARN + 1)); }

CONN_DIR="$BACKEND/crates/hyperswitch_connectors/src/connectors"

# ── Phase 1: Module Files ───────────────────────────────────────────────────

echo "Phase 1: Connector Module"

if [ -f "$CONN_DIR/$TARGET.rs" ]; then
  check_pass "$TARGET.rs exists"
else
  check_fail "$TARGET.rs not found"
fi

if [ -d "$CONN_DIR/$TARGET" ]; then
  for subfile in "$CONN_DIR/$SOURCE"/*.rs; do
    [ -f "$subfile" ] || continue
    bname=$(basename "$subfile")
    if [ -f "$CONN_DIR/$TARGET/$bname" ]; then
      check_pass "$TARGET/$bname exists"
    else
      check_fail "$TARGET/$bname not found"
    fi
  done
fi

# Stale references in target files
stale=$( (grep -rn "${SRC_PASCAL}" "$CONN_DIR/$TARGET.rs" "$CONN_DIR/$TARGET/" 2>/dev/null || true) | (grep -v "${TGT_PASCAL}" || true) | wc -l | tr -d ' ')
if [ "$stale" = "0" ]; then
  check_pass "No stale ${SRC_PASCAL} in target files"
else
  check_fail "$stale stale ${SRC_PASCAL} references in target files"
fi

stale_str=$( (grep -rn "\"${SOURCE}\"" "$CONN_DIR/$TARGET.rs" "$CONN_DIR/$TARGET/" 2>/dev/null || true) | wc -l | tr -d ' ')
if [ "$stale_str" = "0" ]; then
  check_pass "No stale \"${SOURCE}\" strings in target files"
else
  check_fail "$stale_str stale \"${SOURCE}\" strings in target files"
fi

# Line counts
if [ -f "$CONN_DIR/$SOURCE.rs" ]; then
  src_lines=$(wc -l < "$CONN_DIR/$SOURCE.rs" | tr -d ' ')
  tgt_lines=$(wc -l < "$CONN_DIR/$TARGET.rs" | tr -d ' ')
  if [ "$src_lines" = "$tgt_lines" ]; then
    check_pass "Main module line count: $tgt_lines"
  else
    check_fail "Main module line count mismatch: $src_lines vs $tgt_lines"
  fi
fi

echo ""

# ── Phase 2: Backend Registration ────────────────────────────────────────────

echo "Phase 2: Backend Registration"

check_file_contains() {
  local file="$1" pattern="$2" label="$3"
  local relpath=$(echo "$file" | sed "s|${BACKEND}/||")
  if grep -q "$pattern" "$file" 2>/dev/null; then
    check_pass "$relpath contains $label"
  else
    check_fail "$relpath missing $label"
  fi
}

check_file_contains "$BACKEND/crates/common_enums/src/connector_enums.rs" "${TGT_PASCAL}," "enum variant"
check_file_contains "$BACKEND/crates/api_models/src/enums.rs" "${TGT_PASCAL}" "PayoutConnectors"
check_file_contains "$BACKEND/crates/euclid/src/enums.rs" "${TGT_PASCAL}" "RoutableConnectors"
check_file_contains "$BACKEND/crates/hyperswitch_connectors/src/connectors.rs" "pub mod ${TARGET};" "module declaration"
check_file_contains "$BACKEND/crates/hyperswitch_connectors/src/connectors.rs" "${TGT_PASCAL}" "re-export"
check_file_contains "$BACKEND/crates/router/src/connector.rs" "${TARGET}" "router import"
check_file_contains "$BACKEND/crates/router/src/types/api/feature_matrix.rs" "${TGT_PASCAL}" "feature matrix"
check_file_contains "$BACKEND/crates/router/src/types/api/connector_mapping.rs" "${TGT_PASCAL}" "connector mapping"
check_file_contains "$BACKEND/crates/router/src/types/connector_transformers.rs" "${TGT_PASCAL}" "connector transformers"
check_file_contains "$BACKEND/crates/router/src/core/connector_validation.rs" "${TGT_PASCAL}" "auth validation"
check_file_contains "$BACKEND/crates/connector_configs/src/connector.rs" "${TARGET}" "config struct"
check_file_contains "$BACKEND/crates/hyperswitch_domain_models/src/connector_endpoints.rs" "${TARGET}" "connector endpoints"

# Phase 2l: PlatroConnector enum must have the new variant, as_str() arm, and
# from_str() arm. Each check is independent so a partial 2l completion surfaces
# as multiple FAILs rather than one.
PO_TYPES="$BACKEND/crates/platro_observability/src/types.rs"
if [ -f "$PO_TYPES" ]; then
  if grep -q "^[[:space:]]*${TGT_DISPLAY_VARIANT}," "$PO_TYPES"; then
    check_pass "platro_observability/types.rs contains PlatroConnector::${TGT_DISPLAY_VARIANT} variant"
  else
    check_fail "platro_observability/types.rs missing PlatroConnector::${TGT_DISPLAY_VARIANT} variant"
  fi
  if grep -q "Self::${TGT_DISPLAY_VARIANT} => \"${TARGET}\"" "$PO_TYPES"; then
    check_pass "platro_observability/types.rs contains as_str() arm for ${TGT_DISPLAY_VARIANT}"
  else
    check_fail "platro_observability/types.rs missing as_str() arm: Self::${TGT_DISPLAY_VARIANT} => \"${TARGET}\""
  fi
  if grep -q "\"${TARGET}\" => Some(Self::${TGT_DISPLAY_VARIANT})" "$PO_TYPES"; then
    check_pass "platro_observability/types.rs contains from_str() arm for ${TGT_DISPLAY_VARIANT}"
  else
    check_fail "platro_observability/types.rs missing from_str() arm: \"${TARGET}\" => Some(Self::${TGT_DISPLAY_VARIANT})"
  fi
else
  check_warn "platro_observability/types.rs not found (crate may have been removed)"
fi

echo ""

# ── Phase 3: Default Implementations + TOMLs ─────────────────────────────────

echo "Phase 3: Default Implementations + TOMLs"

for impl_file in default_implementations.rs default_implementations_v2.rs; do
  f="$BACKEND/crates/hyperswitch_connectors/src/$impl_file"
  if [ -f "$f" ]; then
    src_count=$(grep -c "connectors::${SRC_PASCAL}," "$f" || true)
    tgt_count=$(grep -c "connectors::${TGT_PASCAL}," "$f" || true)
    if [ "$src_count" = "$tgt_count" ] && [ "$tgt_count" -gt 0 ]; then
      check_pass "$impl_file: $tgt_count entries (matches source)"
    else
      check_fail "$impl_file: $tgt_count target vs $src_count source entries"
    fi
  fi
done

# TOML base_urls
toml_count=$( (grep -rl "^${TARGET}\.base_url" "$BACKEND/config/" "$BACKEND/loadtest/" --include='*.toml' 2>/dev/null || true) | wc -l | tr -d ' ')
src_toml_count=$( (grep -rl "^${SOURCE}\.base_url" "$BACKEND/config/" "$BACKEND/loadtest/" --include='*.toml' 2>/dev/null || true) | wc -l | tr -d ' ')
if [ "$toml_count" = "$src_toml_count" ] && [ "$toml_count" -gt 0 ]; then
  check_pass "TOML base_url: $toml_count files (matches source)"
else
  check_fail "TOML base_url: $toml_count target vs $src_toml_count source files"
fi

# Connector config TOMLs
for toml in production.toml development.toml sandbox.toml; do
  f="$BACKEND/crates/connector_configs/toml/$toml"
  if [ -f "$f" ]; then
    if grep -q "^\[${TARGET}\]" "$f" && grep -q "^\[${TARGET}_payout\]" "$f"; then
      check_pass "connector_configs/$toml: [${TARGET}] + [${TARGET}_payout] sections"
    else
      check_fail "connector_configs/$toml: missing [${TARGET}] or [${TARGET}_payout] section"
    fi
  fi
done

# Test files
check_file_contains "$BACKEND/crates/router/tests/connectors/main.rs" "mod ${TARGET};" "test module"
if [ -f "$BACKEND/crates/router/tests/connectors/${TARGET}.rs" ]; then
  check_pass "Test file ${TARGET}.rs exists"
else
  check_fail "Test file ${TARGET}.rs not found"
fi
check_file_contains "$BACKEND/crates/test_utils/src/connector_auth.rs" "${TARGET}" "test auth"
check_file_contains "$BACKEND/crates/router/tests/connectors/sample_auth.toml" "[${TARGET}]" "sample auth"

echo ""

# ── Phase 5: Frontend (optional) ─────────────────────────────────────────────

if [ -n "$CC_ROOT" ] && [ -d "$CC_ROOT" ]; then
  echo "Phase 5: Frontend"

  check_file_contains "$CC_ROOT/src/screens/Connectors/ConnectorTypes.res" "${TGT_UPPER}" "processorTypes"
  check_file_contains "$CC_ROOT/src/screens/Connectors/ConnectorUtils.res" "${TGT_UPPER}" "ConnectorUtils"

  cc_count=$(grep -c "${TGT_UPPER}\|${TARGET}" "$CC_ROOT/src/screens/Connectors/ConnectorUtils.res" 2>/dev/null || echo 0)
  if [ "$cc_count" -ge 13 ]; then
    check_pass "ConnectorUtils.res: $cc_count entries (>= 13 expected)"
  else
    check_fail "ConnectorUtils.res: only $cc_count entries (expected >= 13)"
  fi

  if [ -f "$CC_ROOT/public/hyperswitch/assets/Gateway/${TGT_UPPER}.svg" ]; then
    check_pass "SVG icon ${TGT_UPPER}.svg exists"
  else
    check_fail "SVG icon ${TGT_UPPER}.svg not found"
  fi

  echo ""
fi

# ── Summary ──────────────────────────────────────────────────────────────────

echo "════════════════════════════════════════════"
echo "  PASS: $PASS  |  FAIL: $FAIL  |  WARN: $WARN"
echo "════════════════════════════════════════════"

if [ $FAIL -gt 0 ]; then
  exit 1
fi
