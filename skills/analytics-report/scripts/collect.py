#!/usr/bin/env python3
"""Collect payment/payout metrics from local PostgreSQL and output structured JSON.

Runs a single CTE-based SQL query via docker exec, parses results into a
hierarchical structure, and outputs JSON with:
- formatted_report: ready-to-send Telegram message
- metrics: structured data for AI analysis
"""

import os
import subprocess
import json
from datetime import datetime, timezone

# Platform codes excluded from production reports (test orgs).
# Mirrors platro-agents/src/lib/scopes.ts — keep in sync.
TEST_PLATFORM_CODES = ("platro_test_org",)

_test_orgs_sql = ", ".join(f"'{c}'" for c in TEST_PLATFORM_CODES)


def scope_by_merchant_id(alias=None):
    col = f"{alias}.merchant_id" if alias else "merchant_id"
    return (
        f"{col} NOT IN "
        f"(SELECT merchant_id FROM merchant_account WHERE organization_id IN ({_test_orgs_sql}))"
    )


SQL = f"""
WITH pay AS (
  SELECT merchant_id, connector,
    count(*) as cnt, coalesce(sum(amount), 0) as amt
  FROM payment_attempt
  WHERE created_at >= current_date
    AND {scope_by_merchant_id()}
  GROUP BY merchant_id, connector
),
pout AS (
  SELECT pa.merchant_id, pa.connector,
    count(*) as cnt, coalesce(sum(p.amount), 0) as amt
  FROM payout_attempt pa
  JOIN payouts p ON pa.payout_id = p.payout_id
    AND pa.merchant_id = p.merchant_id
  WHERE pa.created_at >= current_date
    AND {scope_by_merchant_id("pa")}
  GROUP BY pa.merchant_id, pa.connector
)
SELECT 'payment' as type, merchant_id, connector, cnt, amt FROM pay
UNION ALL
SELECT 'payout' as type, merchant_id, connector, cnt, amt FROM pout
ORDER BY type, merchant_id, connector;
"""


def run_query():
    db_host = os.environ.get("POSTGRES_HOST")

    if db_host:
        # Docker / prod: psql via network
        cmd = [
            "psql", "-h", db_host,
            "-p", os.environ.get("POSTGRES_PORT", "5432"),
            "-U", os.environ.get("POSTGRES_USER", "db_user"),
            "-d", "hyperswitch_db",
            "-t", "-A", "-F", "|", "-c", SQL,
        ]
        env = {**os.environ, "PGPASSWORD": os.environ.get("POSTGRES_PASSWORD", "")}
    else:
        # Local terminal (bun run dev): docker exec
        cmd = [
            "docker", "exec", "-i", "platro-pg-1", "psql",
            "-U", "db_user", "-d", "hyperswitch_db",
            "-t", "-A", "-F", "|", "-c", SQL,
        ]
        env = None

    result = subprocess.run(cmd, capture_output=True, text=True, timeout=30, env=env)
    if result.returncode != 0:
        raise RuntimeError(f"psql failed: {result.stderr.strip()}")
    return result.stdout.strip()


def parse_rows(raw):
    rows = []
    for line in raw.split("\n"):
        line = line.strip()
        if not line:
            continue
        parts = line.split("|")
        if len(parts) != 5:
            continue
        type_, merchant, connector, cnt, amt = parts
        rows.append({
            "type": type_.strip(),
            "merchant_id": merchant.strip(),
            "connector": (connector.strip() or "unknown"),
            "count": int(cnt.strip()),
            "amount": int(amt.strip()),
        })
    return rows


def build_metrics(rows):
    metrics = {
        "platform": {
            "payments_count": 0, "payments_amount": 0,
            "payouts_count": 0, "payouts_amount": 0,
        },
        "merchants": {},
        "connectors": {},
    }

    for r in rows:
        m = r["merchant_id"]
        c = r["connector"]
        t = r["type"]

        # Platform totals
        if t == "payment":
            metrics["platform"]["payments_count"] += r["count"]
            metrics["platform"]["payments_amount"] += r["amount"]
        else:
            metrics["platform"]["payouts_count"] += r["count"]
            metrics["platform"]["payouts_amount"] += r["amount"]

        # Per merchant
        if m not in metrics["merchants"]:
            metrics["merchants"][m] = {
                "payments_count": 0, "payments_amount": 0,
                "payouts_count": 0, "payouts_amount": 0,
                "connectors": {},
            }
        mm = metrics["merchants"][m]
        if t == "payment":
            mm["payments_count"] += r["count"]
            mm["payments_amount"] += r["amount"]
        else:
            mm["payouts_count"] += r["count"]
            mm["payouts_amount"] += r["amount"]

        # Per merchant-connector
        if c not in mm["connectors"]:
            mm["connectors"][c] = {
                "payments_count": 0, "payments_amount": 0,
                "payouts_count": 0, "payouts_amount": 0,
            }
        mc = mm["connectors"][c]
        if t == "payment":
            mc["payments_count"] += r["count"]
            mc["payments_amount"] += r["amount"]
        else:
            mc["payouts_count"] += r["count"]
            mc["payouts_amount"] += r["amount"]

        # Per connector (PSP)
        if c not in metrics["connectors"]:
            metrics["connectors"][c] = {
                "payments_count": 0, "payments_amount": 0,
                "payouts_count": 0, "payouts_amount": 0,
            }
        cc = metrics["connectors"][c]
        if t == "payment":
            cc["payments_count"] += r["count"]
            cc["payments_amount"] += r["amount"]
        else:
            cc["payouts_count"] += r["count"]
            cc["payouts_amount"] += r["amount"]

    return metrics


def fmt_inr(paisa):
    """Format paisa amount as INR with commas."""
    rupees = paisa / 100
    if rupees >= 1_00_000:
        return f"₹{rupees:,.0f}"
    elif rupees >= 1:
        return f"₹{rupees:,.2f}"
    else:
        return "₹0"


def row(label, count, amount):
    """Fixed-width row: label(16) count(5) amount(10)."""
    return f"{label:<16}{count:>5}  {amount:>10}"


def format_report(metrics):
    today = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    p = metrics["platform"]

    lines = [
        "PLATFORM",
        row("  Payments", p["payments_count"], fmt_inr(p["payments_amount"])),
        row("  Payouts", p["payouts_count"], fmt_inr(p["payouts_amount"])),
    ]

    for m_id, m in sorted(metrics["merchants"].items()):
        lines.append("")
        lines.append(m_id)
        lines.append(row("  Payments", m["payments_count"], fmt_inr(m["payments_amount"])))
        for c_id, c in sorted(m["connectors"].items()):
            if c["payments_count"] > 0:
                lines.append(row(f"    {c_id}", c["payments_count"], fmt_inr(c["payments_amount"])))
        lines.append(row("  Payouts", m["payouts_count"], fmt_inr(m["payouts_amount"])))
        for c_id, c in sorted(m["connectors"].items()):
            if c["payouts_count"] > 0:
                lines.append(row(f"    {c_id}", c["payouts_count"], fmt_inr(c["payouts_amount"])))

    if metrics["connectors"]:
        lines.append("")
        lines.append("PSP CONNECTORS")
        for c_id, c in sorted(metrics["connectors"].items()):
            lines.append(row(f"  {c_id}", c["payments_count"], fmt_inr(c["payments_amount"])))

    body = "\n".join(lines)
    title = f"**Analytics Report** — {today}"
    return f"{title}\n\n<pre>{body}</pre>"


def main():
    try:
        raw = run_query()
        rows = parse_rows(raw)
        metrics = build_metrics(rows)
        report = format_report(metrics)

        output = {
            "formatted_report": report,
            "metrics": metrics,
        }
    except Exception as e:
        output = {
            "error": str(e),
            "formatted_report": f"⚠️ **Analytics Report** — DB connection failed\n\n{e}",
            "metrics": None,
        }

    print(json.dumps(output, indent=2))


if __name__ == "__main__":
    main()
