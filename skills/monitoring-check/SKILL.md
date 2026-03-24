---
name: monitoring-check
description: Periodic platform health check — queries prod OpenSearch for ERROR and WARN logs across router and ledger services, analyzes patterns, classifies severity, and produces a formatted summary report. Use when checking platform health or for scheduled monitoring.
user-invocable: true
---

# Monitoring Check

Query prod OpenSearch for ERROR and WARN logs, analyze patterns, produce a formatted report. Self-contained — all opensearch query patterns are embedded below.

---

## OpenSearch Reference

### Critical Syntax Rule

**NEVER put query parameters inside `--path`. This causes "no handler found" errors.**

```
Wrong: opensearch-cli curl get --path "index/_search?q=keyword&size=10"
Right: opensearch-cli curl get --path "index/_search" --query-params "q=keyword&size=10" --pretty
```

### Index Naming

Pattern: `logs-platro-<service>-1-<YYYY-MM-DD>`

| Service | Index Example |
|---------|--------------|
| Router | `logs-platro-server-1-2026-03-24` |
| Ledger | `logs-platro-ledger-1-2026-03-24` |

### Field Reference

**Server index** (`logs-platro-server-*`):
- `level` — keyword: `ERROR`, `WARN`, `INFO`
- `flow` — keyword: `PaymentsCreate`, `PayoutsCreate`, `IncomingWebhookReceive`, `RefundsList`, etc.
- `connector` — keyword: connector name
- `merchant_id` — keyword
- `payment_id`, `payout_id` — keyword
- `message` — text: log message body
- `timestamp` — date (ISO 8601 UTC)

**Ledger index** (`logs-platro-ledger-*`):
- `LogLevel` — text: `Error`, `Warning`, `Information`
- `Category` — text: `AllocationExecutor`, `ChronologicalSyncOrchestrator`, `LedgerEntryService`, `Worker`
- `Message` — text: log message body
- `State.MerchantId`, `State.AllocationId` — text
- `timestamp` — date (ISO 8601 UTC)

---

## Workflow

### Phase 1: Query

**Goal**: Retrieve ERROR and WARN logs from the last 15 minutes.

**Actions**:

1. Get current UTC time and calculate time range:
   - `to` = now (UTC, ISO 8601 format: `YYYY-MM-DDTHH:MM:SSZ`)
   - `from` = now minus 15 minutes
   - `date` = today's date (`YYYY-MM-DD`) for index name

2. Run the following 4 queries via Bash. Replace `{date}`, `{from}`, `{to}` with calculated values.

**Query 1 — Router ERRORs:**
```bash
opensearch-cli curl post --path "logs-platro-server-1-{date}/_search" --data '{"query":{"bool":{"must":[{"term":{"level":"ERROR"}},{"range":{"timestamp":{"gte":"{from}","lte":"{to}"}}}]}},"size":50,"sort":[{"timestamp":{"order":"desc"}}],"_source":["level","flow","connector","merchant_id","message","timestamp"]}' --pretty --profile prod
```

**Query 2 — Router WARNs:**
```bash
opensearch-cli curl post --path "logs-platro-server-1-{date}/_search" --data '{"query":{"bool":{"must":[{"term":{"level":"WARN"}},{"range":{"timestamp":{"gte":"{from}","lte":"{to}"}}}]}},"size":50,"sort":[{"timestamp":{"order":"desc"}}],"_source":["level","flow","connector","merchant_id","message","timestamp"]}' --pretty --profile prod
```

**Query 3 — Ledger Errors:**
```bash
opensearch-cli curl post --path "logs-platro-ledger-1-{date}/_search" --data '{"query":{"bool":{"must":[{"match":{"LogLevel":"Error"}},{"range":{"timestamp":{"gte":"{from}","lte":"{to}"}}}]}},"size":50,"sort":[{"timestamp":{"order":"desc"}}],"_source":["LogLevel","Category","Message","State.MerchantId","timestamp"]}' --pretty --profile prod
```

**Query 4 — Ledger Warnings:**
```bash
opensearch-cli curl post --path "logs-platro-ledger-1-{date}/_search" --data '{"query":{"bool":{"must":[{"match":{"LogLevel":"Warning"}},{"range":{"timestamp":{"gte":"{from}","lte":"{to}"}}}]}},"size":50,"sort":[{"timestamp":{"order":"desc"}}],"_source":["LogLevel","Category","Message","State.MerchantId","timestamp"]}' --pretty --profile prod
```

3. Parse the JSON responses. Extract `hits.total.value` for counts and `hits.hits[]._source` for log entries.

### Phase 2: Analyze

**Goal**: Categorize findings and assess severity.

**Actions**:

1. Count totals: errors and warnings per service (router vs ledger)
2. Group errors by:
   - Router: by `flow` field (e.g., PaymentsCreate, IncomingWebhookReceive)
   - Ledger: by `Category` field (e.g., AllocationExecutor, Worker)
3. Identify repeated messages — same error text appearing 3+ times
4. Classify severity:
   - **Critical**: connector 5xx responses, container crash loops, DB connection failures, OOM errors, authentication failures
   - **Warning**: elevated warn rates, slow queries, retry attempts, timeout errors
   - **Informational**: single transient errors, validation failures, expected payment rejections (insufficient funds, etc.)

### Phase 3: Report

**Goal**: Produce a formatted markdown report as your final output.

**If zero errors and zero warnings found**, output:

```
✅ **Monitoring Check** — {from} to {to} UTC

All clear. No errors or warnings detected across router and ledger services.
```

**If issues found**, output using this template:

```
**Monitoring Report** — {from} to {to} UTC

**Status**: {status_emoji} {status_text}

**Summary**: {error_count} errors, {warn_count} warnings

**Router** ({router_error_count}E / {router_warn_count}W):
• {emoji} {flow}: {description} — {count}x
• ...

**Ledger** ({ledger_error_count}E / {ledger_warn_count}W):
• {emoji} {category}: {description} — {count}x
• ...

**Top Errors**:
1. {message_summary} — {count}x ({service})
2. ...

**Assessment**: {brief interpretation — what these errors mean, whether they indicate a systemic issue or are transient}
```

Status values:
- `🔴 Issues Found` — any critical errors
- `⚠️ Warnings Only` — warnings but no critical errors
- `✅ All Clear` — nothing found

**Important**: The report text IS your final response. Do not wrap it in code blocks or add any preamble — output the report directly so it can be sent to Telegram as-is.
