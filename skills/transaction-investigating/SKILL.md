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

### platro_services_db (snake_case — no quoting required)

All tables use `snake_case` column names. Do NOT double-quote identifiers. Enum values (e.g. `'Debit'`, `'PspAllocation'`) are PascalCase as strings, but column names are lowercase.

Every table in this DB now has a `platform_id uuid` column (platform-scoping). Queries rarely need to filter on it, but selecting it is harmless.

**`ledger_transactions`** — no `status` column

| Column | Type |
|--------|------|
| `id` | uuid PK |
| `type` | varchar (Payment, Payout, Fee, Allocation, Wire, ...) |
| `source_system` | varchar (e.g. `hyperswitch`) |
| `source_id` | varchar (payment_id or payout_id) |
| `description` | varchar |
| `metadata` | jsonb |
| `posted_at` | timestamptz |
| `platform_id` | uuid |
| `created_at` | timestamptz |

Lookup by: `source_id = '{entity_id}'` OR `metadata::text LIKE '%{entity_id}%'`

**`ledger_entries`**

| Column | Type |
|--------|------|
| `id` | uuid PK |
| `transaction_id` | uuid FK → `ledger_transactions.id` |
| `account_id` | uuid FK → `ledger_accounts.id` |
| `type` | varchar (Debit, Credit) |
| `amount` | bigint |
| `balance_after` | bigint |
| `posted_at` | timestamptz |
| `platform_id` | uuid |
| `created_at` | timestamptz |
| `source_reference` | jsonb |
| `settlement_day` | date |

Join with `ledger_accounts` on `account_id = la.id` to get `la.account_name`, `la.normal_balance`.

**`ledger_accounts`** — display name is `account_name`

| Column | Type |
|--------|------|
| `id` | uuid PK |
| `account_code` | varchar (`party:entity:type`, e.g. `merchant:merch_001:pending`) |
| `account_name` | varchar |
| `party_type` | varchar (Psp, Platform, Merchant) |
| `entity_id` | varchar |
| `account_type` | varchar (Pending, Available, Balance, FeePayable, FeeRevenue, OnHold, Adjustment) |
| `classification` | varchar |
| `normal_balance` | varchar (Debit, Credit) |
| `currency` | varchar(3) |
| `is_active` | boolean |
| `platform_id` | uuid |
| `created_at` | timestamptz |

**`allocation_batches`** — minimal columns; no status, total_amount, or wire_payout_id

| Column | Type |
|--------|------|
| `id` | uuid PK |
| `type` | varchar (PspAllocation, MerchantAllocation) |
| `entity_code` | varchar |
| `payment_ids` | jsonb array |
| `platform_id` | uuid |
| `created_at` | timestamptz |
| `ledger_transaction_id` | uuid FK → `ledger_transactions.id` |

**`payout_holds`**

| Column | Type |
|--------|------|
| `id` | uuid PK |
| `merchant_id` | varchar |
| `amount` | bigint |
| `currency` | varchar |
| `payout_id` | varchar |
| `mca_id` | varchar |
| `status` | varchar (Held, Matched, Released, Expired) |
| `platform_id` | uuid |
| `created_at` | timestamptz |
| `expires_at` | timestamptz |
| `matched_at` | timestamptz nullable |

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

   - `entity_id` — positional (e.g. `pay_abc123`, `payout_xyz456`)
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
   | `pay_`    | payment | payment_intent, payment_attempt |
   | `payout_` | payout | payouts, payout_attempt |

   If prefix is unrecognized, ask with `AskUserQuestion`:
   > "What type of transaction is this?"
   Options: Payment, Payout

   Note: Hyperswitch uses `payout_` (not `po_`) for payout IDs — e.g. `payout_HFOEX4RybAVrnxsAXSB3`.

4. **Set connection variables per environment:**

   | Env | DB Method | DB Port | Log Method | Creds Source |
   |-----|-----------|---------|------------|--------------|
   | local | `docker exec -i platro-pg-1 psql -U db_user` | N/A | grep local log files | hardcoded `db_user`/`db_pass` |
   | dev | `psql -h localhost -p 8442 -U db_user` | 8442 | `opensearch-cli --profile dev` | user: `db_user`; password: `vars.secret.yaml.postgres_password` |
   | stage | `psql -h localhost -p 8452 -U db_user` | 8452 | `opensearch-cli --profile stage` | user: `db_user`; password: `vars.secret.yaml.postgres_password` |
   | prod | `psql -h localhost -p 8462 -U db_user` | 8462 | `opensearch-cli --profile prod` | user: `db_user`; password: `vars.secret.yaml.postgres_password` |

   **For remote environments (dev/stage/prod):**
   - User is hardcoded `db_user` (same as local).
   - Password lives in `platro/platro-base-deploy/{env}/server/vars.secret.yaml` under the key `postgres_password`. Extract with:
     ```bash
     PG_PASS=$(grep '^  postgres_password:' platro/platro-base-deploy/{env}/server/vars.secret.yaml | sed -E 's/.*"([^"]+)".*/\1/')
     ```
   - If `psql` is not in your PATH, use `/opt/homebrew/opt/libpq/bin/psql` (Homebrew macOS).

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

6. **Strict ID validation (gate — runs before any full log sweep):**

   The supplied ID may not actually be a Hyperswitch payment_id / payout_id — users sometimes paste merchant-side reference strings that end up only in the `description` or `metadata` field of a different entity. Loose text-matching in Phase 2 would produce a false-positive timeline. Validate first with exact-match DB + structured log term queries:

   ```sql
   -- For pay_*
   SELECT payment_id, merchant_id, status, created_at
   FROM payment_intent WHERE payment_id = '{entity_id}';

   -- For payout_*
   SELECT payout_id, merchant_id, status, created_at
   FROM payouts WHERE payout_id = '{entity_id}';
   ```

   Also run a strict structured log term query (today's index):
   ```
   term: payment_id = {entity_id}   (or payout_id for payout_*)
   index: logs-platro-router-1-{today}
   size: 1
   ```

   **If both return 0 rows**, the ID is not a real entity ID. Run fuzzy fallback to surface candidates:

   ```sql
   -- hyperswitch_db — search description/metadata of recent entities
   SELECT payment_id, merchant_id, status, description, created_at
   FROM payment_intent
   WHERE description LIKE '%{entity_id}%'
      OR metadata::text LIKE '%{entity_id}%'
   ORDER BY created_at DESC LIMIT 5;

   -- Equivalent for payouts
   SELECT payout_id, merchant_id, status, created_at
   FROM payouts
   WHERE metadata::text LIKE '%{entity_id}%'
   ORDER BY created_at DESC LIMIT 5;
   ```

   Also phrase-match in logs:
   ```
   match_phrase: message contains "{entity_id}"
   index: logs-platro-router-1-{today}
   size: 5, _source: [timestamp, payment_id, payout_id, merchant_id]
   ```

   Present candidates to the user via `AskUserQuestion`:
   > "`{entity_id}` is not a recognized payment_id/payout_id. I found these candidates where it appears as a reference — which one do you want to investigate?"
   Options: each candidate as `<real_id> (<status>, <merchant>, <created_at>)`; plus "None of these — cancel."

   Only proceed to Phase 2 after the user confirms a concrete real ID. If the user cancels or no candidates are found, stop the skill with a clear "not found" report.

7. **Confirm to user:**

   > Starting investigation
   > - Entity: `{entity_id}` ({entity_type})
   > - Environment: {env}
   > - Date: {date}
   > - Indices: `logs-platro-*-1-{date}`

**Proceed when:** Entity ID validated (strict or user-confirmed after fuzzy fallback), type, environment, and connectivity confirmed.

---

### Phase 2: Collect

**Goal:** Gather data from logs first, then databases only when needed

Run all queries in this phase. Present a brief summary of findings after each section (not raw JSON dumps — summarize key fields inline).

#### 2A: Logs (always first)

Logs tell the full event story: creation, connector API calls, webhooks, errors, sync attempts. **Always query logs first.**

> **Payout search note:** The `payout_id` keyword field is sparsely indexed — many log entries only contain the payout ID in text fields (`message`, `event`). For complete results, the skill MUST search `message` text, `event` text, AND the `payout_id` keyword field. The existing queries already cover `message` and `payout_id`; the webhook and connector queries below also search the `event` field.

**Remote envs — OpenSearch (query all 4 indices in parallel):**

**Router logs (legacy event_logger — creation, outgoing webhooks, etc.):**

```bash
opensearch-cli curl post \
  --path "logs-platro-router-1-{date}/_search" \
  --data '{"query":{"bool":{"must":[{"match":{"message":"event_logger"}},{"bool":{"should":[{"match_phrase":{"{id_field}":"{entity_id}"}},{"match_phrase":{"event":"{entity_id}"}}],"minimum_should_match":1}}],"must_not":[{"terms":{"flow.keyword":["PaymentsList","PaymentsRetrieve","PayoutsList","PayoutsRetrieve"]}},{"prefix":{"full_name.keyword":"platro_observability::logging::"}}]}},"size":50,"sort":[{"timestamp":{"order":"asc"}}]}' \
  --pretty --profile {env}
```

Where `{id_field}` is `payment_id` for payments or `payout_id` for payouts.

**Why the `must_not: prefix full_name.keyword = "platro_observability::logging::"`:**
The Platro observability crate (see Phase 2A-ter) emits logs where the whole structured payload is baked into `message` as a stringified JSON containing the substring `"message":"event_logger"` inside it. Without this filter, those opaque blobs get mixed into this query's results with no usable top-level fields — Phase 2A-ter handles them specifically. Excluding them here keeps the legacy event_logger timeline clean.

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
# Router log
grep -i "{entity_id}" platro/platro-hs-backend/logs/router.log | tail -50

# PSP Emulator log
grep -i "{entity_id}" platro/platro-psp-emulator/logs/run.log | tail -50

# Ledger service log
grep -i "{entity_id}" platro/platro-services/logs/ledger.log | tail -50
```

**Remote envs — OpenSearch webhook & connector queries (run in parallel with above):**

**Incoming PSP webhooks:**

```bash
opensearch-cli curl post \
  --path "logs-platro-router-1-{date}/_search" \
  --data '{"query":{"bool":{"must":[{"match":{"flow":"IncomingWebhookReceive"}},{"bool":{"should":[{"match_phrase":{"message":"{entity_id}"}},{"match_phrase":{"{id_field}":"{entity_id}"}}],"minimum_should_match":1}}]}},"size":20,"sort":[{"timestamp":{"order":"asc"}}],"_source":["message","flow","fn","file","timestamp","level","request_id"]}' \
  --pretty --profile {env}
```

**Outgoing merchant webhooks:**

```bash
opensearch-cli curl post \
  --path "logs-platro-router-1-{date}/_search" \
  --data '{"query":{"bool":{"must":[{"match":{"fn":"trigger_webhook_and_raise_event"}},{"match":{"file":"event_logger"}},{"bool":{"should":[{"match_phrase":{"event":"{entity_id}"}},{"match_phrase":{"{id_field}":"{entity_id}"}}],"minimum_should_match":1}}]}},"size":20,"sort":[{"timestamp":{"order":"asc"}}]}' \
  --pretty --profile {env}
```

**Connector API request/response:**

```bash
opensearch-cli curl post \
  --path "logs-platro-router-1-{date}/_search" \
  --data '{"query":{"bool":{"must":[{"match":{"fn":"execute_connector_processing_step"}},{"match":{"file":"event_logger"}},{"match_phrase":{"event":"{entity_id}"}}]}},"size":20,"sort":[{"timestamp":{"order":"asc"}}]}' \
  --pretty --profile {env}
```

**Local env — additional grep patterns:**

```bash
# Incoming webhook
grep -i "IncomingWebhookReceive" platro/platro-hs-backend/logs/router.log | grep "{entity_id}" | tail -20

# Outgoing webhook
grep -i "trigger_webhook_and_raise_event" platro/platro-hs-backend/logs/router.log | grep "{entity_id}" | tail -20

# Signature
grep -i "signature" platro/platro-hs-backend/logs/router.log | grep -B2 -A2 "{entity_id}" | tail -20
```

#### 2A-bis: Signature & Raw Body Retrieval

**Goal:** When incoming webhook logs are found, extract the full signature verification pipeline using `request_id`.

This is a **follow-up step** that runs after Phase 2A if any `IncomingWebhookReceive` log entries were found.

**Step 1:** Extract `request_id` from any IncomingWebhookReceive log entry that matched the entity ID.

**Step 2:** Query by `request_id` + `fn=incoming_webhooks_core` to get the signature pipeline:

**Remote:**

```bash
opensearch-cli curl post \
  --path "logs-platro-router-1-{date}/_search" \
  --data '{"query":{"bool":{"must":[{"match_phrase":{"request_id":"{request_id}"}},{"match":{"fn":"incoming_webhooks_core"}}]}},"size":20,"sort":[{"timestamp":{"order":"asc"}}]}' \
  --pretty --profile {env}
```

This returns:
- Signature entry: `IndiaPay signature=<hash>` (no entity ID — only findable by request_id)
- Source message: `IndiaPay source message={JSON}:<ts>` (raw PSP body)

**Step 3:** Query by `request_id` + `incoming_webhook_payload` exists:

**Remote:**

```bash
opensearch-cli curl post \
  --path "logs-platro-router-1-{date}/_search" \
  --data '{"query":{"bool":{"must":[{"match_phrase":{"request_id":"{request_id}"}},{"exists":{"field":"incoming_webhook_payload"}}]}},"size":10,"sort":[{"timestamp":{"order":"asc"}}]}' \
  --pretty --profile {env}
```

This returns the structured JSON webhook payload field.

**Local env:** Use the timestamp from the entity's webhook log and grep ±2 lines for "signature" in the router log:

```bash
grep -B2 -A2 "signature" platro/platro-hs-backend/logs/router.log | grep -B4 -A4 "{approximate_timestamp}" | tail -20
```

**IMPORTANT:** When presenting signature/raw body data, print the RAW messages as-is without reformatting — the whole point is to see the exact payload content.

#### 2A-ter: Platro observability logs (connector request/response/webhook/timing)

**Gate:** Run this section ONLY if the entity's connector is in the instrumented set:
- `indiapay`, `indiapay_h`, `indiapay_q`, `inpayu`

The connector is on `payment_attempt.connector` (for payments) or `payout_attempt.connector` (for payouts). If the connector is unknown at this stage, you can still run Query 1 cheaply — it will naturally return nothing for uninstrumented connectors. If a non-instrumented connector is confirmed, skip this section and note in the report: "Platro observability not instrumented for connector X."

The `platro_observability` crate emits two structurally different log shapes. See `.claude/rules/opensearch.md` → "Platro Observability Logs" for the full field reference.

**Query 1 — Timing enumeration (structured, cheap).** Gives you every connector flow invoked for the entity, with wall-clock latency.

```bash
# Primary: by payment_id / payout_id (works for Authorize, PayoutCreate)
opensearch-cli curl post \
  --path "logs-platro-router-1-{date}/_search" \
  --data '{"query":{"bool":{"must":[{"term":{"operation.keyword":"timing"}},{"term":{"{id_field}":"{entity_id}"}}]}},"size":20,"sort":[{"timestamp":{"order":"asc"}}],"_source":["timestamp","connector","flow","duration_ms","status","request_id","merchant_id","profile_name"]}' \
  --pretty --profile {env}
```

If Query 1 returns fewer timing logs than expected (e.g. an Authorize but no PSync even though the payment reached `charged`), run the **merchant-window fallback** because of known obs-crate Bug E (PSync and some other flows put a Rust-debug string into the `payment_id` tracing field):

```bash
# Fallback: by merchant_id + timestamp window (±60s around the Authorize timing log)
opensearch-cli curl post \
  --path "logs-platro-router-1-{date}/_search" \
  --data '{"query":{"bool":{"must":[{"term":{"operation.keyword":"timing"}},{"term":{"merchant_id":"{merchant_id}"}},{"range":{"timestamp":{"gte":"{t_minus_60s}","lte":"{t_plus_60s}"}}}]}},"size":40,"sort":[{"timestamp":{"order":"asc"}}],"_source":["timestamp","connector","flow","duration_ms","status","request_id","merchant_id","payment_id","payout_id"]}' \
  --pretty --profile {env}
```

Trust `duration_ms` on timing logs only — it is NOT reliable on the response logs below (obs-crate Bug F).

**Query 2 — Request / response bodies (stringified JSON in `message`).** Phrase-match by the real ID, filter by the two HTTP emitters.

```bash
opensearch-cli curl post \
  --path "logs-platro-router-1-{date}/_search" \
  --data '{"query":{"bool":{"must":[{"terms":{"full_name.keyword":["platro_observability::logging::call_connector_service","platro_observability::logging::execute_connector_processing_step"]}},{"match_phrase":{"message":"\"{id_field}\":\"{entity_id}\""}}]}},"size":20,"sort":[{"timestamp":{"order":"asc"}}],"_source":["timestamp","full_name","message"]}' \
  --pretty --profile {env}
```

For each hit, extract the structured payload by parsing the JSON after the `] ` separator in `message`. Example:
```
message = "[CALL_CONNECTOR_SERVICE - EVENT] {\"timestamp\":\"…\",\"operation\":\"request\",\"flow\":\"Authorize\",\"url\":\"…\",\"body\":{…}}"
```
Split once on `"] "` and `json.loads` the right-hand side (or use a shell `sed 's/^[^{]*//'`). Surface in the timeline:
- `operation` (`request` / `response`)
- `flow` (`Authorize`, `PSync`, `ErrorResponse`, etc.)
- `method`, `url`
- `status_code` (response only)
- `body` (truncate to ~500 chars unless user asks for full)

**Pairing request→response (important — obs-crate Bug D):** The `request_id` inside the JSON differs across `request`, `response`, and `timing` logs for the same PSP call (three different UUID generators). Do NOT pair by `request_id`. Pair instead by: same `{id_field}` + same `flow`, then group by timestamp order within a ±2s window of each timing log.

**Query 3 — Incoming webhook payload (operation = webhook).** Webhook logs don't carry `payment_id` at top level (routing happens after), so scope by connector + timestamp window around nearby PSync/sync activity:

```bash
opensearch-cli curl post \
  --path "logs-platro-router-1-{date}/_search" \
  --data '{"query":{"bool":{"must":[{"term":{"full_name.keyword":"platro_observability::logging::incoming_webhooks_core"}},{"match_phrase":{"message":"\"connector\":\"{connector}\""}},{"range":{"timestamp":{"gte":"{t_minus_10s}","lte":"{t_plus_10s}"}}}]}},"size":5,"sort":[{"timestamp":{"order":"asc"}}],"_source":["timestamp","message"]}' \
  --pretty --profile {env}
```

Parse the JSON tail and surface: `method`, `uri`, `headers` (highlight `x-signature` if present), `body`. If the body contains the entity's `m_order_id` / `connector_transaction_id`, confirm it matches. Webhook logs fire BEFORE signature verification, so a hit here proves the PSP delivered a payload regardless of whether validation passed.

**Known observability-crate limitations** (worked around above; not fixed in this skill):
- **Bug D**: `request_id` is not stable across request/response/timing for the same call. Workaround: pair by `{id_field}` + `flow` + timestamp adjacency.
- **Bug E**: On PSync/PayoutSync/Capture/RefundSync, the `payment_id` top-level tracing field may contain `connector_transaction_id = "<uuid>"` instead of the real payment_id. Workaround: merchant+window fallback (Query 1 fallback form).
- **Bug F**: `duration_ms` inside response-log JSON is always `0`. Workaround: use timing log's `duration_ms` only.
- **Top-level `target`** is always `"platro_observability::logging"` (Rust module path); the actual connector name lives inside the stringified JSON — filter via `full_name.keyword`, not `target`.

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

4. **Webhook & signature follow-up rules:**

   | Finding | Follow-Up Action |
   |---------|-----------------|
   | IncomingWebhookReceive logs found | Extract `request_id`, run signature pipeline query (Phase 2A-bis), present raw incoming payload |
   | Outgoing webhook event_logger entry found | Present `event.content` as the raw merchant webhook payload |
   | Signature log found | Compare with source message; note if signature verification passed (no error) or failed (look for ERROR level around same timestamp) |
   | No incoming webhook logs | PSP webhook may not have been sent; check if transaction is still pending |
   | No outgoing webhook logs | Merchant webhook may not be configured; check `error while fetching merchant webhook config` warning |

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

**For payouts (`payout_*`) — hyperswitch_db:**

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

**Ledger data — platro_services_db (snake_case, no quoting):**

```sql
-- Find ledger transactions by source_id or metadata
SELECT id, type, source_system, source_id, description, metadata, posted_at, created_at
FROM ledger_transactions
WHERE source_id = '{entity_id}'
   OR metadata::text LIKE '%{entity_id}%'
ORDER BY created_at ASC;

-- Ledger entries for found transactions (run for each transaction ID)
SELECT le.id, le.transaction_id, la.account_name, la.normal_balance,
       le.type, le.amount, le.balance_after, le.created_at
FROM ledger_entries le
JOIN ledger_accounts la ON le.account_id = la.id
WHERE le.transaction_id = '{transaction_id}'
ORDER BY le.created_at ASC;
```

**For payouts — payout holds:**

```sql
SELECT id, payout_id, merchant_id, amount, status, matched_at, created_at
FROM payout_holds
WHERE payout_id = '{entity_id}';
```

**For payments — allocation batches:**

```sql
SELECT id, type, entity_code, payment_ids, ledger_transaction_id, created_at
FROM allocation_batches
WHERE payment_ids::text LIKE '%{entity_id}%'
ORDER BY created_at DESC
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
# Extract password once per session
PG_PASS=$(grep '^  postgres_password:' platro/platro-base-deploy/{env}/server/vars.secret.yaml | sed -E 's/.*"([^"]+)".*/\1/')

# hyperswitch_db
PGPASSWORD=$PG_PASS psql -h localhost -p {port} -U db_user -d hyperswitch_db -t -A -c "SELECT row_to_json(t) FROM ({query}) t;"

# platro_services_db
PGPASSWORD=$PG_PASS psql -h localhost -p {port} -U db_user -d platro_services_db -t -A -c "SELECT row_to_json(t) FROM ({query}) t;"
```
If `psql` isn't in PATH, use `/opt/homebrew/opt/libpq/bin/psql`.

**Note:** `platro_services_db` uses `snake_case` column names — no quoting required. Double quotes would cause "column does not exist" errors. Double-quote identifiers only in `hyperswitch_db` if you ever need case-sensitive matches (rare; snake_case is the norm there too).

#### 2D: Present Initial Findings Summary

After collecting all data (logs + any DB queries), present a concise summary:

```markdown
## Initial Findings

**Entity:** `{entity_id}` ({entity_type})
**Environment:** {env}

### Log Summary
- **Router events:** {count} events ({key flows seen})
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
   | `error_code` on attempt | Search router logs for connector response body: `opensearch-cli` with `connector_transaction_id` and `ConnectorApiLogs` |
   | Succeeded in HS but no ledger entries | Search ledger logs for processing errors by `{entity_id}` in `Message` field |
   | Multiple attempts exist | Compare `connector`, `status`, `error_code` across attempts; check if retried or different connectors |
   | Webhook status change detected | Find `IncomingWebhookReceive` logs: filter by `flow` + entity ID, extract `raw_body` |
   | Payout stuck in `pending`/`initiated` | Check consumer sync workflow logs for this payout; look for timeout or error |
   | Refund exists | Trace refund through router logs separately; check refund ledger transaction |
   | Dispute exists | Trace dispute through router logs; check dispute ledger entries and `dispute_lost_fee` |
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
   | 1 | 14:45:28 | Router-Log | PayoutsCreate — request received, amount=1100 INR |
   | 2 | 14:45:38 | Router-Log | ConnectorApi — POST to indiapay, response: pending |
   | 3 | 14:50:26 | Router-Log | IncomingWebhookReceive — PSP reports status=success |
   | 4 | 14:50:27 | Router-Log | PoSync ERROR — PSP returned 500 |
   ```

   **Rules:**
   - Always present — this is the primary output of every investigation
   - Include event number for easy reference in discussion
   - Collapse timestamps to time-only (HH:MM:SS) when all events are same day
   - One row per meaningful event (not per log line)
   - Include key data inline (status, error codes, amounts)
   - Source labels: `Router-Log`, `Consumer-Log`, `Ledger-Log`, `Emulator-Log`, `HS-DB`, `Ledger-DB`
   - Include these event types when found:
     - `IncomingWebhook` — PSP webhook received (legacy `IncomingWebhookReceive` flow), include raw status from payload
     - `SignatureVerified` — Signature check passed (no ERROR after signature log)
     - `SignatureFailed` — Signature check failed (ERROR after signature log)
     - `OutgoingWebhook` — Merchant webhook sent, include event_type from payload
     - `ConnectorRequest` — Raw request sent to PSP connector (legacy event_logger)
     - `ConnectorResponse` — Raw response received from PSP connector (legacy event_logger)
   - Phase 2A-ter (Platro observability) event types — prefer these when present, they carry more detail:
     - `PSP-Request` — obs `operation:"request"`; include `flow`, `method`, `url`, summarize body
     - `PSP-Response` — obs `operation:"response"`; include `flow`, `status_code`, summarize body
     - `PSP-Error` — obs response with `flow:"ErrorResponse"`; highlight PSP error code/message from body
     - `PSP-Timing` — obs `operation:"timing"`; use when more informative than the request/response pair (e.g. `duration_ms > 1000` or `status:"5xx"`)
     - `RawWebhook` — obs `operation:"webhook"`; raw pre-verification payload with `method`, `uri`, signature header, body

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

# platro_services_db (snake_case — no quoting of column identifiers needed)
docker exec -i platro-pg-1 psql -U db_user -d platro_services_db -c "{query}"
```

**Remote (psql via tunnel):**
```bash
# Read password (user is hardcoded `db_user`)
PG_PASS=$(grep '^  postgres_password:' platro/platro-base-deploy/{env}/server/vars.secret.yaml | sed -E 's/.*"([^"]+)".*/\1/')

# hyperswitch_db
PGPASSWORD=$PG_PASS psql -h localhost -p {port} -U db_user -d hyperswitch_db -t -A -c "{query}"

# platro_services_db (snake_case — use double quotes around the SQL string, not around column names)
PGPASSWORD=$PG_PASS psql -h localhost -p {port} -U db_user -d platro_services_db -t -A -c "{query}"
```
If `psql` isn't in PATH, use `/opt/homebrew/opt/libpq/bin/psql`.

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
| router | `logs-platro-router-1-2026-02-27` |
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
Router index fields (logs-platro-router-*):
  Keyword:  flow, level, merchant_id, payment_id, payout_id, connector
  Text:     message, event, raw_body, payload
  Date:     timestamp
  Object:   incoming_webhook_payload, event
  Keyword:  request_id, event_type, event_id, log_type
  Key flows: PaymentsCreate, PayoutsCreate, IncomingWebhookReceive, RefundsList
  Key fns:  incoming_webhooks_core, trigger_webhook_and_raise_event,
            create_event_and_trigger_outgoing_webhook, execute_connector_processing_step

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
| 1 | `error_code` on payment_attempt | Connector rejected the request | Search router logs for `ConnectorApiLogs` with `connector_transaction_id` |
| 2 | Payment succeeded but 0 ledger entries | Ledger processing failed or hasn't run yet | Search ledger logs for entity ID in `Message`; check `LedgerEntryService` category |
| 3 | Multiple payment attempts | Payment was retried (possibly different connector) | Compare status/error/connector across attempts |
| 4 | `IncomingWebhookReceive` flow in logs | PSP sent a webhook callback | Extract `raw_body` to see PSP payload; check if status changed |
| 5 | Payout stuck `pending`/`initiated` | Sync workflow hasn't completed or connector hasn't confirmed | Search consumer logs; check `ChronologicalSyncOrchestrator` in ledger logs |
| 6 | Refund record exists | Payment was (partially) refunded | Trace refund in router logs; check refund ledger transaction |
| 7 | Dispute record exists | Chargeback or dispute opened | Trace dispute in router logs; verify `dispute_lost_fee` ledger entries |
| 8 | Allocation batch contains payment | Payment is part of a merchant wire allocation | Check `AllocationExecutor` logs in ledger index |
| 9 | Payout hold exists but `Status` != `Matched` | Hold not yet matched to a completed payout | Check payout terminal status; search `ChronologicalSyncOrchestrator` |
| 10 | Ledger debits != credits | Double-entry invariant broken — critical | Flag immediately; search for partial transaction processing |
| 11 | No `connector_transaction_id` | Request may not have reached the PSP | Check `ConnectorApiLogs` for HTTP-level errors (timeout, 5xx) |
| 12 | Entity exists in DB but no logs found | Logs may be on a different day | Retry with previous day's index; check `created_at` date |
| 13 | Payment `requires_capture` status | Payment authorized but not captured | Check if auto-capture is enabled; look for capture attempt in logs |
| 14 | Incoming webhook received | PSP callback arrived | Extract request_id → query signature pipeline → present raw body |
| 15 | Signature log found without error | Signature verification passed | Note in timeline; no further action needed |
| 16 | ERROR near signature timestamp | Signature verification may have failed | Search for ERROR level logs with same request_id |
| 17 | Outgoing webhook event found | Merchant was notified | Present event.content; check if webhook delivery succeeded |
| 18 | `error while fetching merchant webhook config` | Merchant webhook URL not configured | Note in report; this means merchant won't receive callbacks |
| 19 | `Outgoing webhooks retry config not found` | Webhook retry not configured | Note as informational; single delivery attempt only |
| 20 | Obs timing log for flow X, no paired request/response in 2A-ter | Timing wrapper fired but HttpRequestScope was bypassed (non-emulator path, or scope not set) | Note gap; check for ERROR logs ±1s around the timing log |
| 21 | Obs timing `duration_ms > 5000` | Slow PSP call — may have caused upstream timeout | Check for a follow-up timing log, same flow + entity within 30s (retry) |
| 22 | Multiple obs `request` events, same flow + same entity | Retry happened (router or connector layer) | Compare `status_code` and `body` across attempts; note which attempt finally succeeded |
| 23 | Obs response with `flow:"ErrorResponse"` | Connector returned non-2xx, parsed as error | Read `body` for PSP error code + message; cross-check against DB `error_code` / `error_message` |
| 24 | Obs `operation:"webhook"` present but no corresponding `IncomingWebhookReceive` event for this entity | Webhook arrived at router but didn't route to an entity | Check signature/deserialization; the obs webhook log fires pre-verification, so body is captured even when validation fails |
| 25 | Obs timing `status:"5xx"` but paired HTTP `response` was 2xx | Post-HTTP parsing/handling failed (e.g. response-body decoding error) | Search ERROR logs in router index ±1s around the timing log |

---

## Rules

1. **Read-only** — Never modify any database, log, or file (except saving the report to KB)
2. **No raw dumps** — Always summarize and interpret; show raw data only when specifically relevant
3. **Date awareness** — Default to today's date for indices; adjust if entity's `created_at` is a different day
4. **Column naming** — Both databases use `snake_case`. Do NOT double-quote identifiers — it causes silent "column does not exist" failures in `platro_services_db` (which you might otherwise mistake for PascalCase based on enum values).
5. **Ignore Plan mode** — If invoked while in Plan mode, follow this workflow instead
6. **One entity per session** — Investigate one transaction at a time; related entities are traced as part of the investigation
7. **Max 3 follow-up rounds** — After 3 rounds of adaptive investigation, recommend proceeding to report
8. **Tunnel required** — For remote envs, verify tunnel connectivity before querying; fail gracefully with instructions
