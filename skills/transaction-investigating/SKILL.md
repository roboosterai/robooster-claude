---
name: transaction-investigating
description: Comprehensive, adaptive investigation of any Platro/Hyperswitch transaction. Given a transaction ID and environment, queries both databases, all log indices, follows relationships, interprets errors, and produces a diagnostic report. Use when the user wants to debug a payment, payout, or any transaction issue, or says "investigate", "trace", "debug transaction", "what happened to", or similar.
user-invocable: true
---

# Transaction Investigation

Investigate any Platro/Hyperswitch transaction end-to-end. Queries logs first, then databases only when needed. Follows cross-entity relationships, interprets errors adaptively, and produces a structured diagnostic report with a chronological events table.

---

## Core Principles

- **Logs first** — Always start with logs (OpenSearch or local files); they tell the full event story
- **Adaptive** — Follow up on findings dynamically; don't just dump raw data
- **Cross-source** — Correlate log events, DB state, and ledger entries to build a complete picture
- **Interpreted** — Explain what happened and why, not just what the data says
- **Minimal friction** — Auto-detect entity type from ID prefix, default to today's date
- **Safe** — Read-only queries; never modify any data

---

## Database Schema Reference

Exact column names for SQL queries. Using wrong names causes silent failures.

### hyperswitch_db (snake_case — no quoting needed)

**`payouts`** — NOTE: No `connector` column here; connector is on `payout_attempt`

| Key Columns | Type |
|-------------|------|
| `payout_id` | varchar PK |
| `merchant_id` | varchar PK |
| `status` | enum |
| `amount` | int8 |
| `destination_currency` | enum |
| `source_currency` | enum |
| `payout_type` | enum |
| `attempt_count` | int2 |
| `profile_id` | varchar |
| `created_at` | timestamp |
| `last_modified_at` | timestamp |

**`payout_attempt`** — Has the connector info

| Key Columns | Type |
|-------------|------|
| `payout_attempt_id` | varchar PK |
| `payout_id` | varchar FK |
| `merchant_id` | varchar PK |
| `connector` | varchar |
| `connector_payout_id` | varchar |
| `status` | enum |
| `error_code` | varchar |
| `error_message` | text |
| `created_at` | timestamp |
| `last_modified_at` | timestamp |

**`payment_intent`**

| Key Columns | Type |
|-------------|------|
| `payment_id` | varchar PK |
| `merchant_id` | varchar PK |
| `status` | enum |
| `amount` | int8 |
| `currency` | enum |
| `active_attempt_id` | varchar |
| `profile_id` | varchar |
| `created_at` | timestamp |
| `modified_at` | timestamp |

**`payment_attempt`**

| Key Columns | Type |
|-------------|------|
| `attempt_id` | varchar PK |
| `payment_id` | varchar FK |
| `merchant_id` | varchar PK |
| `status` | enum |
| `connector` | varchar |
| `connector_transaction_id` | varchar |
| `error_code` | varchar |
| `error_message` | text |
| `authentication_type` | enum |
| `payment_method` | varchar |
| `created_at` | timestamp |
| `modified_at` | timestamp |

**`refund`** — Column names differ from other tables!

| Key Columns | Type | NOTE |
|-------------|------|------|
| `refund_id` | varchar PK | |
| `payment_id` | varchar FK | |
| `attempt_id` | varchar FK | |
| `refund_status` | enum | NOT `status` |
| `refund_amount` | int8 | |
| `currency` | enum | |
| `connector` | varchar | |
| `connector_refund_id` | varchar | |
| `refund_error_code` | text | NOT `error_code` |
| `refund_error_message` | text | NOT `error_message` |
| `created_at` | timestamp | |
| `modified_at` | timestamp | |

**`dispute`** — Status column has prefix!

| Key Columns | Type | NOTE |
|-------------|------|------|
| `dispute_id` | varchar PK | |
| `payment_id` | varchar FK | |
| `attempt_id` | varchar FK | |
| `dispute_status` | enum | NOT `status` |
| `dispute_stage` | enum | |
| `amount` | varchar | |
| `currency` | varchar | |
| `connector` | varchar | |
| `connector_dispute_id` | varchar | |
| `dispute_amount` | int8 | |
| `created_at` | timestamp | |
| `modified_at` | timestamp | |

### platro_services_db (PascalCase — MUST double-quote)

**`ledger_transactions`** — No `"Status"` column!

| Column | Type |
|--------|------|
| `"Id"` | uuid PK |
| `"Type"` | enum (PayIn, PayOut, Fee, Allocation, Wire, ...) |
| `"SourceSystem"` | string |
| `"SourceId"` | string (payment_id or payout_id) |
| `"Description"` | string |
| `"Metadata"` | jsonb |
| `"PostedAt"` | timestamptz |
| `"CreatedAt"` | timestamptz |

Lookup by: `"Metadata"::text LIKE '%{entity_id}%'` OR `"SourceId" = '{entity_id}'`

**`ledger_entries`**

| Column | Type |
|--------|------|
| `"Id"` | uuid PK |
| `"TransactionId"` | uuid FK |
| `"AccountId"` | uuid FK |
| `"Type"` | enum (Debit, Credit) |
| `"Amount"` | int8 |
| `"BalanceAfter"` | int8 |
| `"PostedAt"` | timestamptz |
| `"CreatedAt"` | timestamptz |
| `"SourceReference"` | jsonb |
| `"SettlementDay"` | date |

Join with `ledger_accounts` on `"AccountId"` = `la."Id"` to get `la."AccountName"`, `la."NormalBalance"`

**`ledger_accounts`** — Display name is `"AccountName"`, NOT `"Name"`

| Column | Type |
|--------|------|
| `"Id"` | uuid PK |
| `"AccountCode"` | string (party:entity:type) |
| `"AccountName"` | string |
| `"PartyType"` | enum (Psp, Platform, Merchant) |
| `"EntityId"` | string |
| `"AccountType"` | enum (Pending, Available, Balance, FeePayable, FeeRevenue, OnHold, Adjustment) |
| `"NormalBalance"` | enum (Debit, Credit) |
| `"Currency"` | string |

**`allocation_batches`** — Minimal columns; no Status, TotalAmount, or WirePayoutId

| Column | Type |
|--------|------|
| `"Id"` | uuid PK |
| `"Type"` | enum (PspAllocation, MerchantAllocation) |
| `"EntityCode"` | string |
| `"PaymentIds"` | jsonb array |
| `"LedgerTransactionId"` | uuid FK |
| `"CreatedAt"` | timestamptz |

**`payout_holds`**

| Column | Type |
|--------|------|
| `"Id"` | uuid PK |
| `"MerchantId"` | string |
| `"Amount"` | int8 |
| `"Currency"` | string |
| `"PayoutId"` | string |
| `"McaId"` | string |
| `"Status"` | string (Held, Matched, Released, Expired) |
| `"CreatedAt"` | timestamptz |
| `"ExpiresAt"` | timestamptz |
| `"MatchedAt"` | timestamptz |

---

## Workflow

Execute phases in order. Use `AskUserQuestion` for human gates. Run all Bash commands yourself (psql, opensearch-cli, docker exec, grep).

---

### Phase 1: Initialize

**Goal:** Parse inputs, detect entity type, set connection variables, verify connectivity

**Actions:**

1. **Session date:** Run `date +%Y-%m-%d` to get today's date (used for OpenSearch index names)

2. **Parse arguments from skill invocation args:**

   Expected format: `<entity_id> --env <environment>`

   - `entity_id` — positional (e.g. `pay_abc123`, `po_xyz456`)
   - `--env` — environment: `local`, `dev`, `stage`, `prod` (default: `local`)

   If entity ID is missing, prompt with `AskUserQuestion`:
   > "What is the transaction ID to investigate?"
   (free text input)

   If environment is ambiguous, prompt with `AskUserQuestion`:
   > "Which environment?"
   Options: local, dev, stage, prod

3. **Auto-detect entity type from ID prefix:**

   | Prefix | Entity Type | Primary Tables |
   |--------|-------------|----------------|
   | `pay_` | payment | payment_intent, payment_attempt |
   | `po_`  | payout | payouts, payout_attempt |

   If prefix is unrecognized, ask with `AskUserQuestion`:
   > "What type of transaction is this?"
   Options: Payment, Payout

4. **Set connection variables per environment:**

   | Env | DB Method | DB Port | Log Method | Creds Source |
   |-----|-----------|---------|------------|--------------|
   | local | `docker exec -i platro-pg-1 psql -U db_user` | N/A | grep local log files | hardcoded `db_user`/`db_pass` |
   | dev | `psql -h localhost -p 8442` | 8442 | `opensearch-cli --profile dev` | `platro/platro-base-deploy/dev/server/.env` |
   | stage | `psql -h localhost -p 8452` | 8452 | `opensearch-cli --profile stage` | `platro/platro-base-deploy/stage/server/.env` |
   | prod | `psql -h localhost -p 8462` | 8462 | `opensearch-cli --profile prod` | `platro/platro-base-deploy/prod/server/.env` |

   **For remote environments (dev/stage/prod):**
   - Read DB credentials from env files:
     ```bash
     PG_USER=$(grep POSTGRES_USER platro/platro-base-deploy/{env}/server/.env.public | cut -d= -f2)
     PG_PASS=$(grep POSTGRES_PASSWORD platro/platro-base-deploy/{env}/server/.env.secret | cut -d= -f2)
     ```

5. **Verify connectivity (remote envs only):**

   Test OpenSearch connectivity first (logs are queried first):
   ```bash
   opensearch-cli curl get --path "_cluster/health" --pretty --profile {env}
   ```

   If connection fails, tell the user:
   > Tunnel appears to be down. Please start it with:
   > `cd platro/platro-base-deploy/{env}/server && just tunnel`
   > Then re-run the investigation.

   Stop the skill if connectivity fails.

6. **Confirm to user:**

   > Starting investigation
   > - Entity: `{entity_id}` ({entity_type})
   > - Environment: {env}
   > - Date: {date}
   > - Indices: `logs-platro-*-1-{date}`

**Proceed when:** Entity ID, type, environment, and connectivity confirmed

---

### Phase 2: Collect

**Goal:** Gather data from logs first, then databases only when needed

Run all queries in this phase. Present a brief summary of findings after each section (not raw JSON dumps — summarize key fields inline).

#### 2A: Logs (always first)

Logs tell the full event story: creation, connector API calls, webhooks, errors, sync attempts. **Always query logs first.**

**Remote envs — OpenSearch (query all 4 indices in parallel):**

**Server logs (event_logger, connector API, webhooks):**

```bash
opensearch-cli curl post \
  --path "logs-platro-server-1-{date}/_search" \
  --data '{"query":{"bool":{"must":[{"match":{"message":"event_logger"}},{"bool":{"should":[{"match_phrase":{"{id_field}":"{entity_id}"}},{"match_phrase":{"event":"{entity_id}"}}],"minimum_should_match":1}}],"must_not":[{"terms":{"flow.keyword":["PaymentsList","PaymentsRetrieve","PayoutsList","PayoutsRetrieve"]}}]}},"size":50,"sort":[{"timestamp":{"order":"asc"}}]}' \
  --pretty --profile {env}
```

Where `{id_field}` is `payment_id` for payments or `payout_id` for payouts.

**Consumer logs (sync workflows):**

```bash
opensearch-cli curl post \
  --path "logs-platro-consumer-1-{date}/_search" \
  --data '{"query":{"bool":{"must":[{"match":{"message":"event_logger"}},{"bool":{"should":[{"match_phrase":{"{id_field}":"{entity_id}"}},{"match_phrase":{"event":"{entity_id}"}}],"minimum_should_match":1}}]}},"size":20,"sort":[{"timestamp":{"order":"asc"}}]}' \
  --pretty --profile {env}
```

**PSP Emulator logs:**

```bash
opensearch-cli curl post \
  --path "logs-platro-psp-emulator-1-{date}/_search" \
  --data '{"query":{"bool":{"should":[{"match_phrase":{"message":"{entity_id}"}},{"match_phrase":{"payment_id":"{entity_id}"}},{"match_phrase":{"payout_id":"{entity_id}"}}],"minimum_should_match":1}},"size":20,"sort":[{"timestamp":{"order":"asc"}}]}' \
  --pretty --profile {env}
```

**Ledger logs:**

```bash
opensearch-cli curl post \
  --path "logs-platro-ledger-1-{date}/_search" \
  --data '{"query":{"bool":{"should":[{"match_phrase":{"Message":"{entity_id}"}},{"match_phrase":{"{id_field}":"{entity_id}"}},{"match_phrase":{"State.PaymentId":"{entity_id}"}}],"minimum_should_match":1}},"size":20,"sort":[{"timestamp":{"order":"asc"}}]}' \
  --pretty --profile {env}
```

**Local env — grep log files:**

```bash
# Server log
grep -i "{entity_id}" platro/platro-hs-backend/logs/router.log | tail -50

# PSP Emulator log
grep -i "{entity_id}" platro/platro-psp-emulator/logs/run.log | tail -50

# Ledger service log
grep -i "{entity_id}" platro/platro-services/logs/ledger.log | tail -50
```

#### 2B: Interpret & follow up on logs

Analyze what the logs reveal. This is the most important step — logs contain the event narrative.

**Actions:**

1. **Summarize log findings** — What happened chronologically? What flows were triggered? Any errors?
2. **Run follow-up log queries** based on what was found:
   - If connector API call seen → search for detailed request/response with `connector_transaction_id`
   - If webhook received → extract `raw_body` from `IncomingWebhookReceive` flow logs
   - If error logged → search for surrounding context (request_id, time range ±30s)
   - If no logs found → try previous day's index (entity may have been created yesterday)
3. **Assess what's still unclear** — Decide if DB queries are needed

#### 2C: DB queries — only if needed

Query DB only when logs leave gaps or when entity status/ledger data is needed. Examples:
- Entity status unclear from logs alone
- Need to check ledger balances or entry details
- `connector_transaction_id` not visible in logs
- Need to verify which connector was used (from `payout_attempt`)
- Need allocation batch or payout hold status

**If uncertain whether DB queries are needed, ask the user via `AskUserQuestion`:**
> "Logs show {brief summary}. Do you want me to also check the database for {specific thing}?"

**For payments (`pay_*`) — hyperswitch_db:**

```sql
-- payment_intent
SELECT payment_id, status, amount, currency, merchant_id, active_attempt_id,
       profile_id, created_at, modified_at
FROM payment_intent WHERE payment_id = '{entity_id}';

-- payment_attempt (all attempts)
SELECT attempt_id, payment_id, status, connector, connector_transaction_id,
       error_code, error_message, authentication_type, payment_method,
       created_at, modified_at
FROM payment_attempt WHERE payment_id = '{entity_id}' ORDER BY created_at ASC;

-- refund (if any) — NOTE: refund_status, refund_error_code, refund_error_message
SELECT refund_id, payment_id, attempt_id, refund_status, refund_amount, currency,
       connector, connector_refund_id, refund_error_code, refund_error_message,
       created_at, modified_at
FROM refund WHERE payment_id = '{entity_id}' ORDER BY created_at ASC;

-- dispute (if any) — NOTE: dispute_status, dispute_stage
SELECT dispute_id, payment_id, attempt_id, dispute_status, dispute_stage,
       amount, currency, connector, connector_dispute_id, dispute_amount,
       created_at, modified_at
FROM dispute WHERE payment_id = '{entity_id}' ORDER BY created_at ASC;
```

**For payouts (`po_*`) — hyperswitch_db:**

```sql
-- payouts — NOTE: no `connector` column here; connector is on payout_attempt
SELECT payout_id, merchant_id, status, amount, destination_currency, source_currency,
       payout_type, attempt_count, profile_id, created_at, last_modified_at
FROM payouts WHERE payout_id = '{entity_id}';

-- payout_attempt (all attempts) — has the connector info
SELECT payout_attempt_id, payout_id, status, connector, connector_payout_id,
       error_code, error_message, created_at, last_modified_at
FROM payout_attempt WHERE payout_id = '{entity_id}' ORDER BY created_at ASC;
```

**Ledger data — platro_services_db:**

```sql
-- Find ledger transactions by SourceId or Metadata
SELECT "Id", "Type", "SourceSystem", "SourceId", "Description", "Metadata", "PostedAt", "CreatedAt"
FROM ledger_transactions
WHERE "SourceId" = '{entity_id}'
   OR "Metadata"::text LIKE '%{entity_id}%'
ORDER BY "CreatedAt" ASC;

-- Ledger entries for found transactions (run for each transaction ID)
SELECT le."Id", le."TransactionId", la."AccountName", la."NormalBalance",
       le."Type", le."Amount", le."BalanceAfter", le."CreatedAt"
FROM ledger_entries le
JOIN ledger_accounts la ON le."AccountId" = la."Id"
WHERE le."TransactionId" = '{transaction_id}'
ORDER BY le."CreatedAt" ASC;
```

**For payouts — payout holds:**

```sql
SELECT "Id", "PayoutId", "MerchantId", "Amount", "Status", "MatchedAt", "CreatedAt"
FROM payout_holds
WHERE "PayoutId" = '{entity_id}';
```

**For payments — allocation batches:**

```sql
SELECT "Id", "Type", "EntityCode", "PaymentIds", "LedgerTransactionId", "CreatedAt"
FROM allocation_batches
WHERE "PaymentIds"::text LIKE '%{entity_id}%'
ORDER BY "CreatedAt" DESC
LIMIT 5;
```

**Execution pattern (local):**
```bash
# hyperswitch_db
docker exec -i platro-pg-1 psql -U db_user -d hyperswitch_db -c "SELECT row_to_json(t) FROM ({query}) t;"

# platro_services_db
docker exec -i platro-pg-1 psql -U db_user -d platro_services_db -c 'SELECT row_to_json(t) FROM ({query}) t;'
```

**Execution pattern (remote):**
```bash
# hyperswitch_db
PG_USER=$(grep POSTGRES_USER platro/platro-base-deploy/{env}/server/.env | cut -d= -f2) && PG_PASS=$(grep POSTGRES_PASSWORD platro/platro-base-deploy/{env}/server/.env | cut -d= -f2) && PGPASSWORD=$PG_PASS psql -h localhost -p {port} -U $PG_USER -d hyperswitch_db -t -A -c "SELECT row_to_json(t) FROM ({query}) t;"

# platro_services_db
PG_USER=$(grep POSTGRES_USER platro/platro-base-deploy/{env}/server/.env | cut -d= -f2) && PG_PASS=$(grep POSTGRES_PASSWORD platro/platro-base-deploy/{env}/server/.env | cut -d= -f2) && PGPASSWORD=$PG_PASS psql -h localhost -p {port} -U $PG_USER -d platro_services_db -t -A -c 'SELECT row_to_json(t) FROM ({query}) t;'
```

**CRITICAL:** PascalCase columns MUST be double-quoted. In shell commands for platro_services_db, use single quotes for the `-c` argument and escape inner single quotes with `'\''`.

#### 2D: Present Initial Findings Summary

After collecting all data (logs + any DB queries), present a concise summary:

```markdown
## Initial Findings

**Entity:** `{entity_id}` ({entity_type})
**Environment:** {env}

### Log Summary
- **Server events:** {count} events ({key flows seen})
- **Consumer events:** {count} events
- **Emulator events:** {count} events
- **Ledger events:** {count} events

### Key observations from logs
- {What happened: creation, connector calls, webhooks, errors}

### DB State (if queried)
- **Status:** {status}
- **Amount:** {amount} {currency}
- **Merchant:** {merchant_id}
- **Connector:** {connector from attempt table}
- **Attempts:** {count} ({brief status of each})
- **Ledger transactions:** {count} found
- **Balance check:** {debits == credits ? "balanced" : "IMBALANCED"}

### Anomalies Detected
- {List any issues found — errors, missing data, stuck states, imbalances}
```

**Proceed when:** Initial data collected from all sources

---

### Phase 3: Analyze & Follow Up

**Goal:** Interpret findings, run targeted follow-up queries, iterate up to 3 times

**Actions:**

1. **Apply investigation rules to findings:**

   | Finding | Follow-Up Action |
   |---------|-----------------|
   | `error_code` on attempt | Search server logs for connector response body: `opensearch-cli` with `connector_transaction_id` and `ConnectorApiLogs` |
   | Succeeded in HS but no ledger entries | Search ledger logs for processing errors by `{entity_id}` in `Message` field |
   | Multiple attempts exist | Compare `connector`, `status`, `error_code` across attempts; check if retried or different connectors |
   | Webhook status change detected | Find `IncomingWebhookReceive` logs: filter by `flow` + entity ID, extract `raw_body` |
   | Payout stuck in `pending`/`initiated` | Check consumer sync workflow logs for this payout; look for timeout or error |
   | Refund exists | Trace refund through server logs separately; check refund ledger transaction |
   | Dispute exists | Trace dispute through server logs; check dispute ledger entries and `dispute_lost_fee` |
   | Allocation batch found | Check `AllocationExecutor` logs in ledger index for batch processing |
   | Payout hold not matched | Cross-check payout terminal status; search `ChronologicalSyncOrchestrator` logs |
   | Ledger debits != credits | Flag as critical; search for failed/partial transaction processing |
   | Missing connector_transaction_id | Connector may not have received the request; check `ConnectorApiLogs` for HTTP errors |
   | Entity created but no logs | Check if date is correct (entity may be from a different day); try previous day's index |

2. **Run follow-up queries** based on the rules that match

3. **Present follow-up findings** with interpretation

4. **Gate G1 — Ask with `AskUserQuestion`:**

   > "Investigation so far: {brief summary of what was found and interpreted}. What would you like to do?"

   **Options:**

   | Option | Description |
   |--------|-------------|
   | **Sufficient — produce report** | Proceed to synthesis and report |
   | **Investigate further** | Run another round of targeted queries |
   | **Investigate specific aspect** | User provides a specific question to pursue |

5. **If "Investigate further" or specific question:** Run another round (max 3 total). After 3 rounds, recommend proceeding to report.

**Proceed when:** User selects "Sufficient" or 3 follow-up rounds completed

---

### Phase 4: Synthesize

**Goal:** Build a structured understanding from all collected evidence

**Actions:**

1. **Chronological events table** — the primary deliverable of every investigation:

   Build from all collected data (logs + DB if queried). Merge events from all sources into a single ordered table:

   ```
   | # | Time (UTC) | Source | Event |
   |---|------------|--------|-------|
   | 1 | 14:45:28 | Server-Log | PayoutsCreate — request received, amount=1100 INR |
   | 2 | 14:45:38 | Server-Log | ConnectorApi — POST to indiapay, response: pending |
   | 3 | 14:50:26 | Server-Log | IncomingWebhookReceive — PSP reports status=success |
   | 4 | 14:50:27 | Server-Log | PoSync ERROR — PSP returned 500 |
   ```

   **Rules:**
   - Always present — this is the primary output of every investigation
   - Include event number for easy reference in discussion
   - Collapse timestamps to time-only (HH:MM:SS) when all events are same day
   - One row per meaningful event (not per log line)
   - Include key data inline (status, error codes, amounts)
   - Source labels: `Server-Log`, `Consumer-Log`, `Ledger-Log`, `Emulator-Log`, `HS-DB`, `Ledger-DB`

2. **Root cause analysis** (if transaction failed or is stuck):

   - What was the immediate error?
   - What caused the error? (connector response, timeout, validation, etc.)
   - Was it retried? Did retry succeed?
   - Is the transaction recoverable?

3. **Ledger entry summary** (if ledger transactions exist):

   ```
   Account                    | Debit    | Credit   | Net
   ---------------------------+----------+----------+--------
   psp:{connector}:pending    | {amount} |          | {net}
   merchant:{id}:pending      |          | {amount} | {net}
   ...
   ---------------------------+----------+----------+--------
   TOTAL                      | {sum}    | {sum}    | {should be 0}
   ```

   Flag if debits != credits.

4. **Cross-entity map:**

   List all related entities discovered:
   - Refunds: `{refund_ids}`
   - Disputes: `{dispute_ids}`
   - Allocation batches: `{batch_ids}`
   - Wire payouts: `{wire_payout_ids}`
   - Payout holds: `{hold_ids}`

**Proceed when:** Synthesis complete

---

### Phase 5: Report

**Goal:** Present the investigation report and optionally save to KB

**Actions:**

1. **Present the structured report inline:**

   ```markdown
   ## Investigation Report

   **Entity:** `{entity_id}` ({entity_type})
   **Environment:** {env}
   **Date:** {date}
   **Status:** {current_status}
   **Verdict:** {one-line summary — e.g. "Payment succeeded end-to-end", "Payout failed due to insufficient balance at PSP", "Payment stuck — webhook not received"}

   ### Timeline

   | # | Time (UTC) | Source | Event |
   |---|------------|--------|-------|
   | ... | ... | ... | ... |

   ### Root Cause (if applicable)

   {Detailed explanation}

   ### Ledger Summary (if applicable)

   {Debit/credit table}

   ### Related Entities

   {Cross-entity map}

   ### Recommendations

   - {Actionable next steps, if any}
   ```

2. **Gate G2 — Ask with `AskUserQuestion`:**

   > "Investigation complete. Save report to knowledge base?"

   **Options:**

   | Option | Description |
   |--------|-------------|
   | **Yes — save to KB** | Save as markdown file to `platro/platro-kb/investigations/` |
   | **No — done** | End the session |

3. **If saving:**

   **Filename:** `YYYYMMDD-investigation-{type}-{entity_id}.md`

   **Location:** `platro/platro-kb/investigations/`

   **File content — use this template:**

   ```yaml
   ---
   title: "Investigation: {entity_type} {entity_id}"
   description: "{verdict — max 300 chars}"
   type: investigation
   status: complete
   version: "1.0.0"
   created: {YYYY-MM-DD}
   updated: {YYYY-MM-DD}
   author: skill::transaction-investigating
   modified_by: skill::transaction-investigating
   linear: ~
   ---
   ```

   Followed by the full report content (timeline, root cause, ledger summary, related entities, recommendations).

4. **Present completion summary:**

   > Investigation complete.
   > - **Entity:** `{entity_id}` ({entity_type})
   > - **Verdict:** {verdict}
   > - **Report saved:** {path or "not saved"}

**Session complete.**

---

## Human Gates

| Gate | Phase | Question | Pass | Fail |
|------|-------|----------|------|------|
| G1 | Phase 3 | "Sufficient or investigate further?" | Proceed to synthesis | Run more follow-up queries |
| G2 | Phase 5 | "Save report to KB?" | Save file | End session |

---

## Environment Connection Reference

### Database Commands

**Local (docker exec):**
```bash
# hyperswitch_db
docker exec -i platro-pg-1 psql -U db_user -d hyperswitch_db -c "{query}"

# platro_services_db
docker exec -i platro-pg-1 psql -U db_user -d platro_services_db -c '{query}'
```

**Remote (psql via tunnel):**
```bash
# Read credentials
PG_USER=$(grep POSTGRES_USER platro/platro-base-deploy/{env}/server/.env | cut -d= -f2)
PG_PASS=$(grep POSTGRES_PASSWORD platro/platro-base-deploy/{env}/server/.env | cut -d= -f2)

# hyperswitch_db
PGPASSWORD=$PG_PASS psql -h localhost -p {port} -U $PG_USER -d hyperswitch_db -t -A -c "{query}"

# platro_services_db
PGPASSWORD=$PG_PASS psql -h localhost -p {port} -U $PG_USER -d platro_services_db -t -A -c '{query}'
```

| Env | DB Port |
|-----|---------|
| dev | 8442 |
| stage | 8452 |
| prod | 8462 |

### OpenSearch Commands

```bash
opensearch-cli curl {get|post} --path "{index}/_search" --data '{query_json}' --pretty --profile {env}
```

| Env | Profile |
|-----|---------|
| dev | `dev` |
| stage | `stage` |
| prod | `prod` |

### OpenSearch Index Names

Pattern: `logs-platro-{service}-1-{YYYY-MM-DD}`

| Service | Index Example |
|---------|---------------|
| server | `logs-platro-server-1-2026-02-27` |
| consumer | `logs-platro-consumer-1-2026-02-27` |
| psp-emulator | `logs-platro-psp-emulator-1-2026-02-27` |
| ledger | `logs-platro-ledger-1-2026-02-27` |

### Local Log File Paths

```
platro/platro-hs-backend/logs/router.log
platro/platro-psp-emulator/logs/run.log
platro/platro-services/logs/ledger.log
```

---

## OpenSearch Field Reference

```
Server index fields (logs-platro-server-*):
  Keyword:  flow, level, merchant_id, payment_id, payout_id, connector
  Text:     message, event, raw_body, payload
  Date:     timestamp
  Key flows: PaymentsCreate, PayoutsCreate, IncomingWebhookReceive, RefundsList

Consumer index fields (logs-platro-consumer-*):
  Keyword:  flow, level, payment_id, payout_id
  Text:     message, event
  Date:     timestamp

PSP Emulator index fields (logs-platro-psp-emulator-*):
  Text:     message, payment_id, payout_id
  Date:     timestamp

Ledger index fields (logs-platro-ledger-*):
  Text+KW:  Category, Message, LogLevel
  Keyword:  merchant_id, payment_id, payout_id
  Nested:   State.AllocationId, State.MerchantId, State.EntryId, State.PaymentId
  Numeric:  State.ElapsedMilliseconds, State.StatusCode, State.Count
  Date:     timestamp
  Key categories: AllocationExecutor, ChronologicalSyncOrchestrator, LedgerEntryService, Worker
```

---

## Adaptive Investigation Rules

| # | Finding | Interpretation | Follow-Up Query |
|---|---------|---------------|-----------------|
| 1 | `error_code` on payment_attempt | Connector rejected the request | Search server logs for `ConnectorApiLogs` with `connector_transaction_id` |
| 2 | Payment succeeded but 0 ledger entries | Ledger processing failed or hasn't run yet | Search ledger logs for entity ID in `Message`; check `LedgerEntryService` category |
| 3 | Multiple payment attempts | Payment was retried (possibly different connector) | Compare status/error/connector across attempts |
| 4 | `IncomingWebhookReceive` flow in logs | PSP sent a webhook callback | Extract `raw_body` to see PSP payload; check if status changed |
| 5 | Payout stuck `pending`/`initiated` | Sync workflow hasn't completed or connector hasn't confirmed | Search consumer logs; check `ChronologicalSyncOrchestrator` in ledger logs |
| 6 | Refund record exists | Payment was (partially) refunded | Trace refund in server logs; check refund ledger transaction |
| 7 | Dispute record exists | Chargeback or dispute opened | Trace dispute in server logs; verify `dispute_lost_fee` ledger entries |
| 8 | Allocation batch contains payment | Payment is part of a merchant wire allocation | Check `AllocationExecutor` logs in ledger index |
| 9 | Payout hold exists but `Status` != `Matched` | Hold not yet matched to a completed payout | Check payout terminal status; search `ChronologicalSyncOrchestrator` |
| 10 | Ledger debits != credits | Double-entry invariant broken — critical | Flag immediately; search for partial transaction processing |
| 11 | No `connector_transaction_id` | Request may not have reached the PSP | Check `ConnectorApiLogs` for HTTP-level errors (timeout, 5xx) |
| 12 | Entity exists in DB but no logs found | Logs may be on a different day | Retry with previous day's index; check `created_at` date |
| 13 | Payment `requires_capture` status | Payment authorized but not captured | Check if auto-capture is enabled; look for capture attempt in logs |

---

## Rules

1. **Read-only** — Never modify any database, log, or file (except saving the report to KB)
2. **No raw dumps** — Always summarize and interpret; show raw data only when specifically relevant
3. **Date awareness** — Default to today's date for indices; adjust if entity's `created_at` is a different day
4. **Shell quoting** — Use single quotes for `-c` args with PascalCase columns; escape inner singles with `'\''`
5. **Ignore Plan mode** — If invoked while in Plan mode, follow this workflow instead
6. **One entity per session** — Investigate one transaction at a time; related entities are traced as part of the investigation
7. **Max 3 follow-up rounds** — After 3 rounds of adaptive investigation, recommend proceeding to report
8. **Tunnel required** — For remote envs, verify tunnel connectivity before querying; fail gracefully with instructions
