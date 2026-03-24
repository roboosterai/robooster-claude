---
name: monitoring-check
description: Periodic platform health check — queries prod OpenSearch for ERROR and WARN logs across router and ledger services, analyzes patterns, classifies severity, and produces a formatted summary report. Use when checking platform health or for scheduled monitoring.
model: sonnet
allowed-tools: Agent, Bash
user-invocable: true
---

# Monitoring Check

Query prod OpenSearch for ERROR and WARN logs, analyze patterns, produce a formatted report. Self-contained — all opensearch query patterns are embedded below.

---

## OpenSearch Reference

### Access

Query OpenSearch via curl using environment variables `OPENSEARCH_URL` and `OPENSEARCH_PASSWORD`:

```bash
curl -sk -u "admin:${OPENSEARCH_PASSWORD}" -X POST \
  "${OPENSEARCH_URL}/<index>/_search" \
  -H "Content-Type: application/json" \
  -d '<query_json>'
```

Always use `-sk` (silent + insecure SSL for self-signed certs).

### Index Naming

Pattern: `logs-platro-<service>-1-<YYYY-MM-DD>`

| Service | Index Example |
|---------|--------------|
| Router | `logs-platro-router-1-2026-03-24` |
| Ledger | `logs-platro-ledger-1-2026-03-24` |

### Field Reference

**Router index** (`logs-platro-router-*`):
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

### Phase 1: Collect Data

**Goal**: Retrieve ERROR and WARN logs using the log-collector subagent (runs on haiku for cost efficiency).

**Actions**:

1. Calculate the time range:
   - `to` = current UTC time (ISO 8601: YYYY-MM-DDTHH:MM:SSZ)
   - `from` = current UTC time minus the number of minutes specified in the prompt
   - `date` = today's date (YYYY-MM-DD) for index names

2. Use the Agent tool to spawn the **log-collector** subagent with this prompt:

   Run these 4 curl queries against OpenSearch and return structured results.
   Time range: {from} to {to}. Index date: {date}.

   Query 1 — Router ERRORs:
   curl -sk -u "admin:${OPENSEARCH_PASSWORD}" -X POST "${OPENSEARCH_URL}/logs-platro-router-1-{date}/_search" -H "Content-Type: application/json" -d '{"query":{"bool":{"must":[{"term":{"level":"ERROR"}},{"range":{"timestamp":{"gte":"{from}","lte":"{to}"}}}]}},"size":50,"sort":[{"timestamp":{"order":"desc"}}],"_source":["level","flow","connector","merchant_id","message","timestamp"]}'

   Query 2 — Router WARNs:
   curl -sk -u "admin:${OPENSEARCH_PASSWORD}" -X POST "${OPENSEARCH_URL}/logs-platro-router-1-{date}/_search" -H "Content-Type: application/json" -d '{"query":{"bool":{"must":[{"term":{"level":"WARN"}},{"range":{"timestamp":{"gte":"{from}","lte":"{to}"}}}]}},"size":50,"sort":[{"timestamp":{"order":"desc"}}],"_source":["level","flow","connector","merchant_id","message","timestamp"]}'

   Query 3 — Ledger Errors:
   curl -sk -u "admin:${OPENSEARCH_PASSWORD}" -X POST "${OPENSEARCH_URL}/logs-platro-ledger-1-{date}/_search" -H "Content-Type: application/json" -d '{"query":{"bool":{"must":[{"match":{"LogLevel":"Error"}},{"range":{"timestamp":{"gte":"{from}","lte":"{to}"}}}]}},"size":50,"sort":[{"timestamp":{"order":"desc"}}],"_source":["LogLevel","Category","Message","State.MerchantId","timestamp"]}'

   Query 4 — Ledger Warnings:
   curl -sk -u "admin:${OPENSEARCH_PASSWORD}" -X POST "${OPENSEARCH_URL}/logs-platro-ledger-1-{date}/_search" -H "Content-Type: application/json" -d '{"query":{"bool":{"must":[{"match":{"LogLevel":"Warning"}},{"range":{"timestamp":{"gte":"{from}","lte":"{to}"}}}]}},"size":50,"sort":[{"timestamp":{"order":"desc"}}],"_source":["LogLevel","Category","Message","State.MerchantId","timestamp"]}'

   If an index is not found (404), try without the "-1" suffix (e.g., logs-platro-router-{date}).
   Return counts and grouped summaries per query.

3. Wait for the subagent to return. Use its structured results for Phase 2.

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

**Goal**: Produce a formatted report as your final output.

**CRITICAL OUTPUT RULES**:
- Output ONLY the report text below — no preamble, no "Let me compile...", no "Here is the report", no thinking out loud
- Do NOT use backticks or inline code formatting anywhere in the report — use plain text for all values, field names, error messages
- Do NOT use --- horizontal rules
- Start your response directly with the first line of the report template
- This text will be sent to Telegram as-is — it must be clean and human-readable

**If zero errors and zero warnings found**, output exactly:

✅ **Monitoring Check** — {from} to {to} UTC

All clear. No errors or warnings detected across router and ledger services.

**If issues found**, output using this template:

**Monitoring Report** — {from} to {to} UTC

**Status**: {status_emoji} {status_text}

**Summary**: {error_count} errors, {warn_count} warnings

**Router** ({router_error_count}E / {router_warn_count}W):
• {emoji} {flow}: {description} — {count}x

**Ledger** ({ledger_error_count}E / {ledger_warn_count}W):
• {emoji} {category}: {description} — {count}x

**Top Errors**:
1. {message_summary} — {count}x ({service})
2. ...

**Assessment**:
• {one-line root cause or pattern interpretation}
• {whether this is systemic or transient}
• {recommended action if any, or "No action needed"}

Status values:
- 🔴 Issues Found — any critical errors
- ⚠️ Warnings Only — warnings but no critical errors
- ✅ All Clear — nothing found
