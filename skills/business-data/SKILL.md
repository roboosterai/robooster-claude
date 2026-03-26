---
name: business-data
description: Retrieve business metrics from Platro databases — payment/payout conversion
  rates, volumes, counts, broken down by merchant, connector, or date. Uses semantic
  context with pre-defined measures and lets Claude compose SQL. Use when the user asks
  about conversion rates, payment volumes, payout success, transaction counts, daily
  summaries, or says "how many", "what was the rate", "show me payments", or similar.
user-invocable: true
---

# Business Data Retrieval

Answer business data questions by composing SQL queries against Platro databases.
You have measure definitions and entity schemas below — use them to build correct queries.

---

## Entities

### payment_intent (hyperswitch_db)

The payment order. One intent = one merchant payment request. Use this table for all
payment metrics unless connector breakdown is needed.

| Column | Type | Description |
|--------|------|-------------|
| payment_id | varchar(64) | PK, unique payment identifier |
| merchant_id | varchar(64) | PK, merchant code (e.g. `'merch_001'`) |
| organization_id | varchar(32) | Platform tenant ID — **ALWAYS filter by this** |
| status | enum | See status values below |
| amount | bigint | **Paisa** (smallest unit). 30000 = 300.00 INR |
| currency | enum | e.g. `'INR'` |
| created_at | timestamp | UTC, no timezone |
| active_attempt_id | varchar(64) | FK to payment_attempt.attempt_id (latest attempt) |
| attempt_count | smallint | Number of processing attempts |

**Status values:** `succeeded`, `failed`, `cancelled`, `processing`, `requires_customer_action`,
`requires_merchant_action`, `requires_payment_method`, `requires_confirmation`,
`requires_capture`, `expired`

**Success = `'succeeded'`**

### payment_attempt (hyperswitch_db)

Individual processing attempt against a connector. Multiple attempts per intent possible
(retries, fallbacks). **Only JOIN this table when connector breakdown is requested.**

| Column | Type | Description |
|--------|------|-------------|
| attempt_id | varchar(64) | PK |
| merchant_id | varchar(64) | PK |
| payment_id | varchar(64) | FK to payment_intent |
| status | enum | `'charged'` = success at attempt level |
| amount | bigint | Paisa |
| connector | varchar(64) | **PSP name** (e.g. `'indiapay'`, `'indiapay_q'`) |
| payment_method | varchar | e.g. `'upi'` |
| error_code | varchar(255) | Failure reason code |
| error_message | text | Failure details |
| created_at | timestamp | UTC |

**JOIN pattern** (intent → attempt):
```sql
JOIN payment_attempt pa ON pa.attempt_id = pi.active_attempt_id
  AND pa.merchant_id = pi.merchant_id
```

### payouts (hyperswitch_db)

Payout order. One payout = one merchant withdrawal request (IMPS bank transfer).

| Column | Type | Description |
|--------|------|-------------|
| payout_id | varchar(64) | PK |
| merchant_id | varchar(64) | PK |
| organization_id | varchar(32) | Platform tenant ID — **ALWAYS filter by this** |
| status | enum | See status values below |
| amount | bigint | **Paisa** |
| destination_currency | enum | e.g. `'INR'` |
| created_at | timestamp | UTC |
| last_modified_at | timestamp | UTC (note: different name than payment tables) |
| attempt_count | smallint | Number of processing attempts |

**Status values:** `success`, `failed`, `cancelled`, `initiated`, `expired`, `reversed`,
`pending`, `requires_creation`, `requires_confirmation`, `requires_payout_method_data`,
`requires_fulfillment`

**Success = `'success'`** (not `'succeeded'` — different from payments!)

### payout_attempt (hyperswitch_db)

Individual payout processing attempt. **Only JOIN when connector breakdown is requested.**

| Column | Type | Description |
|--------|------|-------------|
| payout_attempt_id | varchar(64) | PK |
| merchant_id | varchar(64) | PK |
| payout_id | varchar(64) | FK to payouts |
| status | enum | Same PayoutStatus as payouts table |
| connector | varchar(64) | **PSP name** |
| error_code | varchar(64) | Failure reason |
| error_message | text | Failure details |
| created_at | timestamp | UTC |

**JOIN pattern** (payout → attempt):
```sql
JOIN payout_attempt pa ON pa.payout_id = p.payout_id
  AND pa.merchant_id = p.merchant_id
```

---

## Measures

### Successful Payments
```
COUNT(*) FILTER (WHERE status = 'succeeded')
```
Source: `payment_intent`. Count of payments that completed successfully.

### Payment Conversion Rate
```
ROUND(
  COUNT(*) FILTER (WHERE status = 'succeeded') * 100.0
  / NULLIF(COUNT(*), 0),
2)
```
Source: `payment_intent`. Percentage of all payment intents that succeeded.

### Payment Volume
```
SUM(amount) FILTER (WHERE status = 'succeeded') / 100.0
```
Source: `payment_intent`. Total value of successful payments in INR.

### Successful Payouts
```
COUNT(*) FILTER (WHERE status = 'success')
```
Source: `payouts`. Count of payouts that completed successfully.

### Payout Conversion Rate
```
ROUND(
  COUNT(*) FILTER (WHERE status = 'success') * 100.0
  / NULLIF(COUNT(*), 0),
2)
```
Source: `payouts`. Percentage of all payouts that succeeded.

### Payout Volume
```
SUM(amount) FILTER (WHERE status = 'success') / 100.0
```
Source: `payouts`. Total value of successful payouts in INR.

---

## Verified Queries

Use these as reference patterns when composing SQL.

### Q: "What was the conversion rate for merch_001 yesterday?"

```sql
SELECT
  COUNT(*) AS total,
  COUNT(*) FILTER (WHERE status = 'succeeded') AS succeeded,
  ROUND(COUNT(*) FILTER (WHERE status = 'succeeded') * 100.0 / NULLIF(COUNT(*), 0), 2) AS rate_pct
FROM payment_intent
WHERE merchant_id = 'merch_001'
  AND organization_id = 'platro_org'
  AND created_at >= CURRENT_DATE - INTERVAL '1 day'
  AND created_at < CURRENT_DATE;
```

### Q: "Payout volume this week"

```sql
SELECT
  COUNT(*) FILTER (WHERE status = 'success') AS succeeded,
  ROUND(SUM(amount) FILTER (WHERE status = 'success') / 100.0, 2) AS volume_inr
FROM payouts
WHERE organization_id = 'platro_org'
  AND created_at >= date_trunc('week', CURRENT_DATE)
  AND created_at < CURRENT_DATE + INTERVAL '1 day';
```

### Q: "Payment volume by connector for merch_002 today"

```sql
SELECT
  pa.connector,
  COUNT(*) AS total,
  COUNT(*) FILTER (WHERE pi.status = 'succeeded') AS succeeded,
  ROUND(SUM(pi.amount) FILTER (WHERE pi.status = 'succeeded') / 100.0, 2) AS volume_inr
FROM payment_intent pi
JOIN payment_attempt pa ON pa.attempt_id = pi.active_attempt_id
  AND pa.merchant_id = pi.merchant_id
WHERE pi.merchant_id = 'merch_002'
  AND pi.organization_id = 'platro_org'
  AND pi.created_at >= CURRENT_DATE
  AND pi.created_at < CURRENT_DATE + INTERVAL '1 day'
GROUP BY pa.connector
ORDER BY volume_inr DESC;
```

### Q: "Daily payment and payout summary for the last 7 days"

```sql
WITH payments AS (
  SELECT
    created_at::date AS day,
    COUNT(*) AS total,
    COUNT(*) FILTER (WHERE status = 'succeeded') AS succeeded,
    ROUND(COUNT(*) FILTER (WHERE status = 'succeeded') * 100.0 / NULLIF(COUNT(*), 0), 2) AS rate_pct,
    ROUND(SUM(amount) FILTER (WHERE status = 'succeeded') / 100.0, 2) AS volume_inr
  FROM payment_intent
  WHERE organization_id = 'platro_org'
    AND created_at >= CURRENT_DATE - INTERVAL '7 days'
  GROUP BY created_at::date
),
payouts AS (
  SELECT
    created_at::date AS day,
    COUNT(*) AS total,
    COUNT(*) FILTER (WHERE status = 'success') AS succeeded,
    ROUND(COUNT(*) FILTER (WHERE status = 'success') * 100.0 / NULLIF(COUNT(*), 0), 2) AS rate_pct,
    ROUND(SUM(amount) FILTER (WHERE status = 'success') / 100.0, 2) AS volume_inr
  FROM payouts
  WHERE organization_id = 'platro_org'
    AND created_at >= CURRENT_DATE - INTERVAL '7 days'
  GROUP BY created_at::date
)
SELECT
  COALESCE(p.day, po.day) AS day,
  p.succeeded AS pay_ok, p.total AS pay_total, p.rate_pct AS pay_rate, p.volume_inr AS pay_vol,
  po.succeeded AS out_ok, po.total AS out_total, po.rate_pct AS out_rate, po.volume_inr AS out_vol
FROM payments p
FULL OUTER JOIN payouts po ON p.day = po.day
ORDER BY day DESC;
```

---

## Rules

1. **Platform isolation**: ALWAYS include `WHERE organization_id = 'platro_org'` in every query.
   Use `'platro_org'` unless the user explicitly asks for a different organization.

2. **Amounts**: Stored as bigint in paisa. Present results in INR: divide by 100, show 2 decimal
   places, use comma formatting for thousands (e.g. `1,25,000.00`).

3. **Dates**: All timestamps are UTC. No timezone conversions. "Yesterday" means yesterday UTC.
   "This week" means from Monday 00:00 UTC. "Today" means from today 00:00 UTC.

4. **Status strings differ**: Payments succeed with `'succeeded'`, payouts with `'success'`.
   Getting this wrong silently returns zero. Double-check every query.

5. **Connector breakdown**: Only JOIN attempt tables when the user explicitly asks about
   connectors or PSPs. Otherwise query intent/payout tables directly.

6. **Query safety**: Read-only. Never INSERT/UPDATE/DELETE. Use `LIMIT 100` unless the user
   asks for more. Queries that scan large date ranges should include date filters.

7. **Show your work**: Always show the SQL you executed so the operator can verify.

8. **Format output**: Present results as an aligned text table. For single-value answers
   (e.g. "what's the conversion rate"), respond with just the number and brief context.

---

## Execution

Run queries via psql against the local PostgreSQL instance:

```
docker exec -i platro-pg-1 psql -U db_user -d hyperswitch_db -c "SQL_HERE"
```

The environment is inherited from the runtime context. Never ask the user which environment.
All queries target `hyperswitch_db`.
