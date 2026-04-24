---
name: ledger-auth-testing
description: Comprehensive platform scoping and JWT auth security tests for the Platro ledger API. Generates JWT tokens, probes all endpoints with cross-platform credentials, detects data leaks, and produces a structured test report. Use when the user wants to verify platform isolation, test auth boundaries, or says "test auth", "check scoping", "platform isolation test", or similar.
user-invocable: true
---

# Ledger Auth & Platform Scoping Tests

Run a comprehensive security test suite against the Platro ledger API. Tests platform isolation across all endpoints using generated JWT tokens and per-platform API keys. Detects cross-platform data leaks, broken auth boundaries, and missing platformId threading.

---

## Core Principles

- **Read-only** — Never modify ledger data; only create test tokens and fire GET/POST requests that are rejected or harmless
- **Evidence-based** — Every PASS/FAIL is backed by HTTP codes and response data (counts, IDs)
- **Cross-platform** — Every test compares platro_org vs platro_test_org behavior
- **Comprehensive** — Tests all 3 auth vectors (JWT, platform API key, admin API key) across all endpoints
- **Deterministic** — Generates JWT tokens programmatically; no browser login needed

---

## Reference: Ledger API Endpoints

| # | Method | Path | Auth Pattern | Platform Scoping |
|---|--------|------|-------------|------------------|
| 1 | GET | /api/ledger/accounts | Public (M2) | AccountsFilter.PlatformId |
| 2 | GET | /api/ledger/allocations | Admin | AllocationFilter.PlatformId |
| 3 | POST | /api/ledger/allocations | Admin | Request.PlatformId |
| 4 | GET | /api/ledger/allocations/{id} | Admin | Controller guard |
| 5 | GET | /api/ledger/allocations/schedules | Admin | Service.PlatformId |
| 6 | POST | /api/ledger/allocations/schedules | Admin | Request.PlatformId |
| 7 | GET | /api/ledger/allocations/schedules/{id} | Admin | Controller guard |
| 8 | PUT | /api/ledger/allocations/schedules/{id} | Admin | Controller pre-check |
| 9 | DELETE | /api/ledger/allocations/schedules/{id} | Admin | Controller pre-check |
| 10 | GET | /api/ledger/corrections | Admin | **KNOWN GAP** |
| 11 | POST | /api/ledger/corrections | Admin | Service.PlatformId |
| 12 | GET | /api/ledger/corrections/{id} | Admin | Controller guard |
| 13 | GET | /api/ledger/disputes | Admin | **KNOWN GAP** |
| 14 | POST | /api/ledger/disputes | Admin | Request.PlatformId |
| 15 | GET | /api/ledger/disputes/{id} | Admin | Controller guard |
| 16 | POST | /api/ledger/eligibility | ApiKey | Three-path resolution |
| 17 | GET | /api/ledger/holds | Public (M2) | Service.PlatformId |
| 18 | GET | /api/merchants | ApiKey | **KNOWN GAP** |
| 19 | POST | /api/merchants | ApiKey | Request.PlatformId |
| 20 | GET | /api/merchants/{code} | ApiKey | Controller guard |
| 21 | PUT | /api/merchants/{code} | ApiKey | Controller pre-check |
| 22 | DELETE | /api/merchants/{code} | ApiKey | Controller pre-check |
| 23 | GET | /api/ledger/transactions | Admin | **KNOWN GAP** |
| 24 | GET | /api/ledger/transactions/{id} | Admin | Controller guard |
| 25 | GET | /api/ledger/entries | Admin | **KNOWN GAP** |
| 26 | GET | /api/ledger/wires | Public | **KNOWN GAP** |
| 27 | GET | /api/ledger/wires/{id} | Public | Controller guard |
| 28 | GET | /api/ledger/wire-requests | Public | **KNOWN GAP** |
| 29 | POST | /api/ledger/wire-requests | Public | Service.PlatformId |
| 30 | GET | /api/ledger/wire-requests/{id} | Public | Controller guard |
| 31 | POST | /api/ledger/wire-requests/{id}/approve | Admin | Service.PlatformId |
| 32 | POST | /api/ledger/wire-requests/{id}/reject | Admin | Controller pre-check only |
| 33 | GET | /api/ledger/merchants/{id}/transactions | Public (E1) | Repository.PlatformId |

---

## Workflow

Execute phases in order. Run all tests yourself via Bash (curl, python3, psql/docker exec). Present results in the structured report format at the end.

---

### Phase 1: Initialize

**Goal:** Detect environment, load credentials, verify connectivity

**Actions:**

1. **Parse arguments:**

   Expected format: `--env <environment>` (default: `local`)

   Environments: `local`, `dev`, `stage`, `prod`

2. **Load API keys from platro-psp-tests/.env:**

   Read from: `{PLATRO_ROOT}/platro-psp-tests/.env`

   Extract these variables (where `{ENV}` = env name uppercased):
   ```
   {ENV}_MERCH_001_API_KEY          → HS key for merch_001
   {ENV}_MERCH_002_API_KEY          → HS key for merch_002
   {ENV}_TEST_MERCH_001_API_KEY     → HS key for test_merch_001
   {ENV}_TEST_MERCH_002_API_KEY     → HS key for test_merch_002
   {ENV}_PLATRO_ORG_LEDGER_API_KEY  → Platform API key for platro_org
   {ENV}_PLATRO_TEST_ORG_LEDGER_API_KEY → Platform API key for platro_test_org
   {ENV}_LEDGER_API_KEY             → Admin/legacy API key
   ```

3. **Resolve JWT secret:**

   | Env | Source |
   |-----|--------|
   | local | Hardcoded: `super-secret-jwt-key-for-local-dev` |
   | dev/stage/prod | Read from `{PLATRO_ROOT}/platro-base-deploy/{env}/server/vars.secret.yaml` → `env.jwt_secret` |

4. **Resolve ledger base URL:**

   | Env | URL |
   |-----|-----|
   | local | `http://localhost:8180` |
   | dev | `https://ledger-dev.platro.app` |
   | stage | `https://ledger-stage.platro.app` |
   | prod | `https://ledger.platro.app` |

5. **Resolve DB connection** (for collecting cross-platform entity IDs):

   | Env | Method |
   |-----|--------|
   | local | `docker exec -i platro-pg-1 psql -U db_user -d platro_services_db` |
   | dev | `PGPASSWORD=db_pass psql -h localhost -p 8442 -U db_user -d platro_services_db` |
   | stage | `PGPASSWORD=db_pass psql -h localhost -p 8452 -U db_user -d platro_services_db` |
   | prod | Read password from `platro-base-deploy/{env}/server/.env.secret`; port 8462 |

6. **Verify connectivity:**
   ```bash
   curl -s -o /dev/null -w "%{http_code}" {BASE}/health
   ```
   If not 200, tell user to start the ledger service and stop.

7. **Confirm:**
   > Starting ledger auth & platform scoping tests
   > - Environment: {env}
   > - Ledger URL: {BASE}
   > - Platform keys: ORG ✓ / TEST ✓
   > - Admin key: ✓
   > - JWT secret: loaded

---

### Phase 2: Generate JWT Tokens

**Goal:** Create 6 JWT tokens covering all auth scenarios

Use Python3 to generate HS256-signed JWTs:

```python
import json, hmac, hashlib, base64, time

SECRET = "{jwt_secret}"
exp = int(time.time()) + 3600

def b64url(data):
    return base64.urlsafe_b64encode(data).rstrip(b'=').decode()

def make_jwt(payload):
    header = b64url(json.dumps({"alg":"HS256","typ":"JWT"}).encode())
    body = b64url(json.dumps(payload).encode())
    sig_input = f"{header}.{body}"
    sig = b64url(hmac.new(SECRET.encode(), sig_input.encode(), hashlib.sha256).digest())
    return f"{header}.{body}.{sig}"
```

**Tokens to generate:**

| Name | role_id | org_id | merchant_id | Purpose |
|------|---------|--------|-------------|---------|
| `JWT_ADMIN_ORG` | tenant_admin | platro_org | platro_merchant | Admin scoped to platro_org |
| `JWT_ADMIN_TEST` | tenant_admin | platro_test_org | platro_test_merchant | Admin scoped to platro_test_org |
| `JWT_MERCH_ORG` | merchant_view_only | platro_org | merch_001 | Merchant viewer in platro_org |
| `JWT_MERCH_TEST` | merchant_view_only | platro_test_org | test_merch_001 | Merchant viewer in platro_test_org |
| `JWT_BAD_ORG` | tenant_admin | nonexistent_org | platro_merchant | Admin with invalid org_id |
| `JWT_EXPIRED` | merchant_view_only | platro_org | merch_001 | Expired token (exp = now - 60) |

Store all tokens as shell variables for subsequent phases.

---

### Phase 3: Collect Cross-Platform Entity IDs

**Goal:** Get one entity ID per type from each platform for GetById/mutation tests

Run these SQL queries against platro_services_db:

```sql
-- One allocation ID per platform
SELECT a.id, p.platform_code FROM allocations a
JOIN platforms p ON a.platform_id = p.id
GROUP BY p.platform_code, a.id LIMIT 1;  -- repeat for each platform

-- One transaction ID per platform
-- One wire ID per platform
-- One wire_request ID per platform
-- One schedule ID per platform
-- One correction ID per platform
-- One dispute ID per platform
-- One payment source_id per platform (for dispute cross-platform test)
```

Store as: `ORG_ALLOC_ID`, `TEST_ALLOC_ID`, `ORG_TXN_ID`, etc.

If a platform has no data for a given entity type, skip the corresponding GetById test.

---

### Phase 4: Execute Tests

**Goal:** Run all test cases, capture results

Use a bash function for each test:

```bash
run_test() {
    local id="$1" desc="$2" method="$3" url="$4" auth_header="$5" expected="$6" body="${7:-}"
    # curl with -s -o /tmp/test_body.txt -w "%{http_code}"
    # Compare HTTP code and/or response data against expected
    # Print: [T{id}] PASS/FAIL — {desc} (HTTP {code})
}
```

#### Category A: Auth Edge Cases (4 tests)

| ID | Test | Auth | Expected |
|----|------|------|----------|
| A1 | No auth header | None | HTTP 401 |
| A2 | Invalid JWT signature | Mangled Bearer | HTTP 401 |
| A3 | Expired JWT | JWT_EXPIRED | HTTP 401 |
| A4 | Admin JWT with nonexistent org_id | JWT_BAD_ORG | Accounts: should return 0 items (platformId=null for JWT admin = LEAK if data returned) |

#### Category B: List Endpoint Data Leak Detection (7 tests)

For each endpoint, query with all 3 keys (ORG, TEST, ADMIN) and compare `total_count`:

| ID | Endpoint | Method |
|----|----------|--------|
| B1 | GET /api/ledger/corrections | Compare ORG vs TEST vs ADMIN total_count |
| B2 | GET /api/ledger/disputes | Same |
| B3 | GET /api/merchants | Same |
| B4 | GET /api/ledger/transactions | Same |
| B5 | GET /api/ledger/entries | Same |
| B6 | GET /api/ledger/wires | Same |
| B7 | GET /api/ledger/wire-requests | Same |

**PASS:** ORG_count < ADMIN_count AND TEST_count < ADMIN_count AND ORG_count + TEST_count ≈ ADMIN_count
**LEAK:** ORG_count == ADMIN_count OR TEST_count == ADMIN_count

#### Category C: Secure List Endpoints (4 tests)

Same count comparison for endpoints that should already be scoped:

| ID | Endpoint |
|----|----------|
| C1 | GET /api/ledger/accounts |
| C2 | GET /api/ledger/allocations |
| C3 | GET /api/ledger/allocations/schedules |
| C4 | GET /api/ledger/holds |

**PASS:** ORG_count < ADMIN_count (or ADMIN sees combined totals)

#### Category D: GetById Cross-Platform Isolation (8 tests)

Use TEST platform key to access ORG entity IDs:

| ID | Endpoint | Expected |
|----|----------|----------|
| D1 | GET /api/ledger/allocations/{ORG_ALLOC_ID} | HTTP 404 |
| D2 | GET /api/ledger/allocations/schedules/{ORG_SCHED_ID} | HTTP 404 |
| D3 | GET /api/ledger/transactions/{ORG_TXN_ID} | HTTP 404 |
| D4 | GET /api/ledger/wires/{ORG_WIRE_ID} | HTTP 404 |
| D5 | GET /api/ledger/wire-requests/{ORG_WREQ_ID} | HTTP 404 |
| D6 | GET /api/ledger/corrections/{ORG_CORR_ID} | HTTP 404 |
| D7 | GET /api/ledger/disputes/{ORG_DISP_ID} | HTTP 404 |
| D8 | GET /api/merchants/merch_001 | HTTP 404 |

#### Category E: Write/Mutation Cross-Platform Blocking (9 tests)

Use TEST platform key to mutate ORG entities:

| ID | Test | Expected |
|----|------|----------|
| E1 | POST allocation for merch_001 | HTTP 400 |
| E2 | POST correction on merchant:merch_001:pending | HTTP 400 |
| E3 | POST wire-request for merch_001 | HTTP 404 |
| E4 | PUT schedule {ORG_SCHED_ID} (reactivate) | HTTP 404 |
| E5 | DELETE schedule {ORG_SCHED_ID} | HTTP 404 |
| E6 | PUT merchant merch_001 | HTTP 404 |
| E7 | POST approve wire-request {ORG_WREQ_ID} | HTTP 404 |
| E8 | POST reject wire-request {ORG_WREQ_ID} | HTTP 404 |
| E9 | POST dispute with ORG payment_id | HTTP 400 |

#### Category F: JWT Merchant Boundary (6 tests)

| ID | Test | Auth | Expected |
|----|------|------|----------|
| F1 | merch_001 viewer → merch_002 transactions | JWT_MERCH_ORG | HTTP 403 |
| F2 | test_merch_001 viewer → merch_001 transactions | JWT_MERCH_TEST | HTTP 403 |
| F3 | test_merch_001 viewer → accounts | JWT_MERCH_TEST | Only test_merch_001 entity_ids |
| F4 | merch_001 viewer → holds | JWT_MERCH_ORG | Only merch_001 entity_id |
| F5 | test_merch_001 viewer → wires | JWT_MERCH_TEST | 0 items or only test_merch_001 |
| F6 | test_merch_001 viewer → wire-requests | JWT_MERCH_TEST | 0 items or only test_merch_001 |

#### Category G: JWT Admin Scoping (4 tests)

| ID | Test | Auth | Expected |
|----|------|------|----------|
| G1 | tenant_admin ORG → accounts | JWT_ADMIN_ORG | Has data, scoped to platro_org |
| G2 | tenant_admin TEST → accounts | JWT_ADMIN_TEST | Has data, scoped to platro_test_org |
| G3 | tenant_admin ORG → allocations | JWT_ADMIN_ORG | Has data |
| G4 | tenant_admin TEST → allocations | JWT_ADMIN_TEST | Has data |

#### Category H: Eligibility Cross-Platform (2 tests)

| ID | Test | Auth | Expected |
|----|------|------|----------|
| H1 | TEST key + merch_001 | Platform key TEST | HTTP 400 (merchant not in platform) |
| H2 | Admin key + test_merch_001 | Admin key | HTTP 200 (derives platro_test_org) |

#### Category I: Data Integrity (3 tests)

| ID | Test | Method |
|----|------|--------|
| I1 | ORG accounts + TEST accounts ≤ ADMIN accounts | Count comparison |
| I2 | ORG allocation IDs ∩ TEST allocation IDs = ∅ | ID set comparison |
| I3 | DR == CR per platform | DB query |

---

### Phase 5: Report

**Goal:** Produce a structured test results report

**Format:**

```
═══════════════════════════════════════════════════════════
  LEDGER AUTH & PLATFORM SCOPING TEST REPORT
  Environment: {env} | Date: {date}
═══════════════════════════════════════════════════════════

─── Summary ───────────────────────────────────────────────
  Total: {total} | Pass: {pass} | Fail: {fail} | Leak: {leak}

─── Auth Edge Cases ({pass}/{total}) ──────────────────────
  [A1] PASS — No auth → 401
  [A2] PASS — Bad JWT → 401
  ...

─── Data Leak Detection ({pass}/{total}) ──────────────────
  [B1] LEAK — Corrections: ORG=30 TEST=30 ADMIN=30 (no scoping)
  [B2] LEAK — Disputes: ORG=76 TEST=76 ADMIN=76 (no scoping)
  ...

  (repeat for each category)

─── Findings ──────────────────────────────────────────────

  CRITICAL:
  - {description of each data leak with endpoint and evidence}

  MODERATE:
  - {description of each controller-only guard finding}

  SECURE:
  - {list of properly scoped endpoints}

─── Fix Proposals ─────────────────────────────────────────

  Priority 1 — Thread platformId through List endpoints:
  | Controller | Method | Fix |
  |------------|--------|-----|
  | {controller} | {method} | Add platformId to service + repository |
  ...

  Priority 2 — Reject null PlatformId for JWT admin callers:
  | File | Change |
  |------|--------|
  | DualAuthMiddleware | Reject 401 when JWT org_id resolves to null platform |

═══════════════════════════════════════════════════════════
```

---

## Rules

1. **Read-only** — Never modify the database or any production data
2. **No browser** — Generate JWT tokens programmatically; never use browser automation
3. **Evidence required** — Every FAIL/LEAK must include HTTP code and data counts as evidence
4. **Safe write tests** — Cross-platform write tests use entity codes that will be rejected by guardrails; never create real data
5. **Env awareness** — Adapt connection method and credentials per environment
6. **Keys from .env** — Always load API keys from `platro-psp-tests/.env`; never hardcode keys
7. **Fail gracefully** — If connectivity fails or a key is missing, skip affected tests and note in report
8. **One run per session** — Complete all tests in a single execution; don't ask for incremental approval
