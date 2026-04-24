---
name: portal-ui-testing
description: Comprehensive UI tests for the Platro portal embedded in Control Center. Tests page access control, data scoping per platform/role, allocation/wire/dispute operations, filters, CSV export, pagination, and cross-platform isolation. Uses Chrome browser automation to login as different users and interact with the portal. Use when the user wants to test the portal UI, verify platform scoping in the UI, or says "test portal", "UI tests", "check portal scoping", or similar.
user-invocable: true
---

# Portal UI Testing

Run comprehensive UI tests against the Platro portal embedded in Control Center. Tests page accessibility, data scoping per role/platform, all interactive operations (allocations, wires, filters, export), and cross-platform data isolation.

---

## Core Principles

- **Browser-based** — All tests run via Chrome extension tools (read_page, computer, javascript_tool)
- **Multi-user** — Tests login as different users (operator, merchant, cross-platform) to verify scoping
- **Evidence-based** — Every PASS/FAIL includes what was expected vs what was observed
- **Non-destructive** — Write operations (allocations, wires) use small amounts and are safe test data
- **Comprehensive** — Covers all 5 portal pages, all interactive elements, all role combinations

---

## Portal Architecture Reference

### Pages & Routes

| Page | Route | Role | Content |
|------|-------|------|---------|
| Merchant Balance | /merchant/balance | Merchant | 4 balance cards + transaction history table |
| Merchant Wires | /merchant/wires | Merchant | Available balance + Requests/History tabs |
| Operator Accounts | /operator/accounts | Operator | Balances/Transactions/Entries tabs |
| Operator Allocations | /operator/allocations | Operator | PSPs/Merchants tabs + entity selector + allocation list |
| Operator Wires | /operator/wires | Operator | PSPs/Merchants tabs + entity selector + Requests/History tabs |

### Role Determination

- JWT `role_id` = `org_admin` or `tenant_admin` → **Operator** (sees operator pages)
- Any other `role_id` → **Merchant** (sees merchant pages, auto-scoped to own merchant_id)

### CC Sidebar Navigation

Operator sees: **Accounts**, **Wires**, **Allocations** (under Platro section)
Merchant sees: **Balance**, **Wires** (under Platro section, though wires may not always be visible)

### Platform Scoping

- JWT `org_id` → resolves to platform via PlatformCache
- All API calls from portal carry the JWT → ledger scopes by platform
- Operator switching org in CC gets a new JWT with different org_id

---

## Test Users

| User | Password | Role | Platform | Merchant |
|------|----------|------|----------|----------|
| `ab@platro.ai` | Test123$ | tenant_admin → Operator | platro_org (default) | platro_merchant |
| `ab@platro.ai` | Test123$ | tenant_admin → Operator | platro_test_org (after org switch) | platro_test_merchant |
| `ab1@platro.ai` | Test123$ | merchant_view_only → Merchant | platro_org | merch_001 |
| `test_ab1@platro.ai` | Test123$ | merchant_view_only → Merchant | platro_test_org | test_merch_001 |

---

## Workflow

Execute phases in order. Use Chrome extension tools for all browser interactions. Use `AskUserQuestion` if blocked (e.g., tunnel down, service not running).

---

### Phase 1: Initialize

**Goal:** Verify CC and ledger are running, get browser context

**Actions:**

1. **Parse arguments:**

   Expected format: `--env <environment>` (default: `local`)

   | Env | CC URL | Ledger URL |
   |-----|--------|------------|
   | local | http://localhost:9000 | http://localhost:8180 |
   | dev | https://cc-dev.platro.app | https://ledger-dev.platro.app |
   | stage | https://cc-stage.platro.app | https://ledger-stage.platro.app |

2. **Get browser context:**
   ```
   mcp__claude-in-chrome__tabs_context_mcp(createIfEmpty: true)
   ```

3. **Verify ledger is running:**
   ```bash
   curl -s -o /dev/null -w "%{http_code}" {LEDGER_URL}/health
   ```
   If not 200, ask user to start the ledger.

4. **Create a fresh tab for testing:**
   ```
   mcp__claude-in-chrome__tabs_create_mcp(url: "{CC_URL}/dashboard/login")
   ```

5. **Confirm to user:**
   > Starting portal UI tests
   > - Environment: {env}
   > - CC: {CC_URL}
   > - Users to test: ab@platro.ai, ab1@platro.ai, test_ab1@platro.ai

---

### Phase 2: Login Helper

**Goal:** Reusable login procedure for each user

**Login procedure (called for each user):**

1. Navigate to `{CC_URL}/dashboard/login`
2. Wait for login page to load (read_page, look for email input)
3. Enter email in email field (form_input)
4. Click "Sign In" / "Continue" button (computer click)
5. Wait for password field to appear
6. Enter password: `Test123$` (form_input)
7. Click "Sign In" button (computer click)
8. Wait for dashboard to load (read_page, look for sidebar or dashboard content)
9. Take screenshot to confirm login success

**For org switch (ab@platro.ai testing platro_test_org):**

1. After initial login, find org switcher in CC header/sidebar
2. Click org switcher
3. Select "platro_test_org" organization
4. Wait for page reload with new context
5. Verify new org context in CC header

---

### Phase 3: Execute Test Categories

Run tests grouped by category. For each test, record:
- Test ID
- Description
- Expected result
- Actual result
- PASS/FAIL
- Evidence (screenshot reference, data observed)

#### Category 1: Page Access Control (PA)

**Login as: `ab@platro.ai` (operator)**

| ID | Test | Steps | Expected |
|----|------|-------|----------|
| PA-1 | Operator sidebar shows Platro pages | Read sidebar navigation items | Accounts, Allocations, Wires visible |
| PA-2 | Accounts page loads | Click Accounts in sidebar → read portal iframe | Page title "Accounts", 3 tabs visible |
| PA-3 | Allocations page loads | Click Allocations → read iframe | Page title "Allocations", PSPs/Merchants tabs |
| PA-4 | Wires page loads | Click Wires → read iframe | Page title "Wires", PSPs/Merchants tabs |

**Login as: `ab1@platro.ai` (merchant merch_001)**

| ID | Test | Steps | Expected |
|----|------|-------|----------|
| PA-5 | Merchant sidebar does NOT show operator pages | Read sidebar | No Accounts, no Allocations links |
| PA-6 | Merchant Balance page loads | Click Balance in sidebar → read iframe | 4 balance cards visible |

#### Category 2: Data Scoping — Operator (DS)

**Login as: `ab@platro.ai` in platro_org context**

| ID | Test | Steps | Expected |
|----|------|-------|----------|
| DS-1 | Accounts Balances shows only platro_org entities | Navigate to Accounts → Balances tab → read entity cards | Merchants: merch_001, merch_002 only. No test_merch_* |
| DS-2 | Allocations Merchants dropdown shows platro_org merchants | Navigate to Allocations → Merchants tab → read dropdown | merch_001, merch_002 only |
| DS-3 | Wires Merchants dropdown shows platro_org merchants | Navigate to Wires → Merchants tab → read dropdown | merch_001, merch_002 only |
| DS-4 | Transactions total count | Read total_count badge on Transactions tab | Note count for comparison |

**Switch org to platro_test_org:**

| ID | Test | Steps | Expected |
|----|------|-------|----------|
| DS-5 | Accounts Balances shows only platro_test_org entities | After org switch → Accounts → Balances | Merchants: test_merch_001, test_merch_002 only |
| DS-6 | Allocations Merchants dropdown shows platro_test_org merchants | Allocations → Merchants tab → dropdown | test_merch_001, test_merch_002 only |
| DS-7 | Wires Merchants dropdown shows platro_test_org merchants | Wires → Merchants tab → dropdown | test_merch_001, test_merch_002 only |
| DS-8 | Transactions total count differs from platro_org | Transactions tab → read total_count | Different from DS-4 count |
| DS-9 | Balance amounts differ between orgs | Compare PSP indiapay_q balance before/after switch | Different amounts |

#### Category 3: Data Scoping — Merchant (DM)

**Login as: `ab1@platro.ai` (merch_001, platro_org)**

| ID | Test | Steps | Expected |
|----|------|-------|----------|
| DM-1 | Balance page shows only merch_001 data | Read balance cards | Amounts match merch_001 balances |
| DM-2 | Transaction history shows only merch_001 transactions | Read entity column in table | All rows show merch_001 entity |
| DM-3 | Wires page shows only merch_001 wire requests | Read entity column | All rows show merch_001 |

**Login as: `test_ab1@platro.ai` (test_merch_001, platro_test_org)**

| ID | Test | Steps | Expected |
|----|------|-------|----------|
| DM-4 | Balance page shows only test_merch_001 data | Read balance cards | Amounts match test_merch_001 balances |
| DM-5 | Transaction history shows only test_merch_001 transactions | Read entity column | All rows show test_merch_001 |
| DM-6 | Wires page shows only test_merch_001 wire requests | Read entity column | No merch_001/002 data |
| DM-7 | Balance amounts differ from merch_001 | Compare DM-1 vs DM-4 | Different amounts |

#### Category 4: Allocation Operations (FN-A)

**Login as: `ab@platro.ai` (operator, platro_org context)**

| ID | Test | Steps | Expected |
|----|------|-------|----------|
| FN-A1 | "New Allocation" button exists | Allocations → Merchants tab → select merch_001 → look for button | Blue button with "New Allocation" text |
| FN-A2 | Click "New Allocation" → dialog opens | Click button → read_page for dialog | Dialog title "New Allocation", Entity field pre-filled |
| FN-A3 | Entity field is disabled (pre-filled) | Read entity input in dialog | Disabled, shows selected entity code |
| FN-A4 | N-Window field accepts 0 | Enter 0 in N-Window → check Create button state | Create button enabled |
| FN-A5 | Submit allocation → success | Click Create → wait for dialog to close | Dialog closes, table refreshes |
| FN-A6 | New allocation appears in table with Status "Pending" | Read first row in table | Status badge = Pending |
| FN-A7 | After ~30s, allocation status updates | Wait 30s → click refresh button | Status = Completed or Empty |
| FN-A8 | Balance cards update after allocation | Check pending/available shift | Pending decreased, Available increased (if Completed) |

#### Category 5: Wire Operations (FN-W)

**Login as: `ab@platro.ai` (operator, platro_org context)**

Navigate to Wires → Merchants tab → select merch_001

| ID | Test | Steps | Expected |
|----|------|-------|----------|
| FN-W1 | "New Request" button exists | Read page for wire request create button | Button visible |
| FN-W2 | Click "New Request" → dialog opens | Click button → read dialog | Dialog with Amount field |
| FN-W3 | Enter amount → paise preview updates | Type 100 in Amount → read preview text | Shows "10000 paise" or similar |
| FN-W4 | Submit wire request → success | Enter valid amount → Click Create | Dialog closes, new row appears |
| FN-W5 | New request has Status "New" | Read status column | Badge = New |
| FN-W6 | Click "Approve" button on new request | Find Approve button → click | Approve dialog opens |
| FN-W7 | Approve dialog shows amount summary | Read dialog content | Amount, Fee, Net Amount visible |
| FN-W8 | Enter exchange rate → USD preview calculates | Type rate → read USD amount | USD = Net Amount / Rate |
| FN-W9 | Submit approve → status changes to "Approved" | Click Approve → read table | Status badge = Approved |
| FN-W10 | Click approved row → navigates to History tab | Click row | URL changes to view=history, wire visible |

**Reject flow (create another wire request first):**

| ID | Test | Steps | Expected |
|----|------|-------|----------|
| FN-W11 | Click "Reject" on a New request → dialog opens | Click Reject button | Dialog with Reason textarea |
| FN-W12 | Reason field required — Reject button disabled without reason | Check button state | Disabled until text entered |
| FN-W13 | Enter reason → submit → status changes to "Rejected" | Type reason → click Reject | Status badge = Rejected |

#### Category 6: Filters, Tabs, CSV, Pagination (FN-T)

**Login as: `ab@platro.ai` (operator)**

Navigate to Accounts → Transactions tab

| ID | Test | Steps | Expected |
|----|------|-------|----------|
| FN-T1 | Tab switching: click "Ledger Entries" tab | Click tab | URL updates to ?tab=entries, table changes |
| FN-T2 | Tab switching: click "Balances" tab | Click tab | Balance overview grid appears |
| FN-T3 | URL-driven navigation | Navigate to URL with ?tab=transactions | Transactions tab active |
| FN-T4 | Date range filter: apply date range | Select from/to dates | Table row count changes, all dates in range |
| FN-T5 | Clear filters button appears when filter active | Apply any filter | "Clear" button visible |
| FN-T6 | Clear filters restores full data | Click Clear | Count returns to unfiltered total |
| FN-T7 | CSV export button clicks | Click CSV button | File download triggers |
| FN-T8 | Pagination: next page | Click next page button | Page indicator increments, new data loads |
| FN-T9 | Pagination: page count matches total | Read "page X of Y" | Y = ceil(total_count / page_size) |
| FN-T10 | Entity card click → Transactions tab filtered | Click merchant card on Balances | URL: ?tab=transactions&entity=merch_001, table filtered |

Navigate to Allocations page

| ID | Test | Steps | Expected |
|----|------|-------|----------|
| FN-T11 | Entity selector dropdown works | Click dropdown → select different entity | Data changes, URL updates |
| FN-T12 | Status filter: select "Completed" | Check Completed checkbox | Only Completed rows shown |
| FN-T13 | Mode filter: select "Scheduled" | Select from dropdown | Only Scheduled mode rows |
| FN-T14 | Multiple filters combine | Apply Status + Date range | Intersection of both filters |

#### Category 7: Cross-Platform UI Isolation (CP)

**Login as: `ab@platro.ai` — start in platro_org**

| ID | Test | Steps | Expected |
|----|------|-------|----------|
| CP-1 | Record platro_org data | Accounts → Balances → note merchant list and PSP balance | Save for comparison |
| CP-2 | Switch to platro_test_org | Use org switcher in CC | New JWT with org_id=platro_test_org |
| CP-3 | Portal data changes after switch | Accounts → Balances | Different merchant list (test_merch_*) |
| CP-4 | Balance amounts differ | Compare PSP balance | Different from CP-1 |
| CP-5 | Allocations entity selector changes | Allocations → Merchants tab | test_merch_001, test_merch_002 |
| CP-6 | Switch back to platro_org | Use org switcher | Original data restored |

#### Category 8: Data Integrity (DI)

**Login as: `ab@platro.ai` (operator)**

| ID | Test | Steps | Expected |
|----|------|-------|----------|
| DI-1 | All balance amounts non-negative | Accounts → Balances → read all cards | No negative balances |
| DI-2 | Currency labels show INR | Read all amount fields | INR on all amounts |
| DI-3 | Transaction table total_count matches pagination | Read total badge, count pages | Consistent |
| DI-4 | Copy button works on IDs | Click copy icon on an ID → try paste | ID copied correctly |
| DI-5 | Empty state renders for entity with no data | Select entity with no allocations | "No allocations" message |
| DI-6 | Refresh button triggers data reload | Click refresh → watch for loading state | Loading spinner, then fresh data |

---

### Phase 4: Report

**Goal:** Produce structured test results

**Format:**

```
═══════════════════════════════════════════════════════════
  PORTAL UI TEST REPORT
  Environment: {env} | Date: {date}
═══════════════════════════════════════════════════════════

─── Summary ───────────────────────────────────────────────
  Total: {total} | Pass: {pass} | Fail: {fail}

─── Page Access Control ({pass}/{total}) ──────────────────
  [PA-1] PASS — Operator sidebar shows Accounts, Allocations, Wires
  [PA-2] PASS — Accounts page loads
  ...

─── Data Scoping — Operator ({pass}/{total}) ──────────────
  [DS-1] PASS — platro_org: only merch_001, merch_002 in Balances
  [DS-5] PASS — platro_test_org: only test_merch_001, test_merch_002
  ...

─── Data Scoping — Merchant ({pass}/{total}) ──────────────
  [DM-1] PASS — merch_001 viewer: Balance shows merch_001 only
  ...

─── Allocation Operations ({pass}/{total}) ────────────────
  [FN-A1] PASS — "New Allocation" button exists
  ...

─── Wire Operations ({pass}/{total}) ──────────────────────
  [FN-W1] PASS — "New Request" button exists
  ...

─── Filters, Tabs, CSV, Pagination ({pass}/{total}) ──────
  [FN-T1] PASS — Tab switching updates URL
  ...

─── Cross-Platform Isolation ({pass}/{total}) ─────────────
  [CP-1] PASS — platro_org data recorded
  ...

─── Data Integrity ({pass}/{total}) ───────────────────────
  [DI-1] PASS — All balances non-negative
  ...

─── Findings ──────────────────────────────────────────────

  CRITICAL:
  - {any data leaks, cross-platform visibility issues}

  FUNCTIONAL:
  - {any broken UI operations}

  COSMETIC:
  - {formatting issues, missing labels}

═══════════════════════════════════════════════════════════
```

---

## Rules

1. **Non-destructive** — Allocation and wire operations use minimal amounts; nothing that corrupts production data
2. **Screenshot evidence** — Take screenshots at key checkpoints (login, page loads, dialog opens, results)
3. **Multi-user** — Must test with at least 3 users (operator org, operator test_org, merchant)
4. **DB verification** — For data scoping tests, cross-reference UI values with direct DB/API queries
5. **Login fresh** — Each user gets a fresh login session; don't reuse tokens across user tests
6. **Wait for loads** — After navigation or action, wait for page/data to load before reading
7. **URL verification** — Check URL state after tab switches and filter changes
8. **One session** — Complete all tests in a single run; report at the end
9. **Pause on block** — If CC login fails, portal doesn't load, or browser tool errors repeatedly, pause and ask the user via AskUserQuestion
