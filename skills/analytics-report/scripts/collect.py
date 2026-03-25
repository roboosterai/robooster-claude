#!/usr/bin/env python3
"""Collect payment/payout metrics from local PostgreSQL and output structured JSON.

Runs a single CTE-based SQL query via docker exec, parses results into a
hierarchical structure, and outputs JSON with:
- formatted_report: ready-to-send Telegram message
- metrics: structured data for AI analysis
"""

import subprocess
import json
from datetime import datetime, timezone

SQL = """
WITH pay AS (
  SELECT merchant_id, connector,
    count(*) as cnt, coalesce(sum(amount), 0) as amt
  FROM payment_attempt
  WHERE created_at >= current_date
  GROUP BY merchant_id, connector
),
pout AS (
  SELECT pa.merchant_id, pa.connector,
    count(*) as cnt, coalesce(sum(p.amount), 0) as amt
  FROM payout_attempt pa
  JOIN payouts p ON pa.payout_id = p.payout_id
    AND pa.merchant_id = p.merchant_id
  WHERE pa.created_at >= current_date
  GROUP BY pa.merchant_id, pa.connector
)
SELECT 'payment' as type, merchant_id, connector, cnt, amt FROM pay
UNION ALL
SELECT 'payout' as type, merchant_id, connector, cnt, amt FROM pout
ORDER BY type, merchant_id, connector;
"""


def run_query():
    result = subprocess.run(
        ["docker", "exec", "-i", "platro-pg-1", "psql",
         "-U", "db_user", "-d", "hyperswitch_db",
         "-t", "-A", "-F", "|", "-c", SQL],
        capture_output=True, text=True, timeout=30
    )
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


def format_report(metrics):
    today = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    p = metrics["platform"]
    lines = [
        f"**Analytics Report** — {today}",
        "",
        "**Platform Totals**",
        f"• Payments: {p['payments_count']} txns — {fmt_inr(p['payments_amount'])}",
        f"• Payouts: {p['payouts_count']} txns — {fmt_inr(p['payouts_amount'])}",
    ]

    if metrics["merchants"]:
        lines += ["", "**Merchants**"]
        for m_id, m in sorted(metrics["merchants"].items()):
            lines += [
                "",
                f"**{m_id}**:",
                f"  Payments: {m['payments_count']} txns — {fmt_inr(m['payments_amount'])}",
            ]
            for c_id, c in sorted(m["connectors"].items()):
                if c["payments_count"] > 0:
                    lines.append(f"    via {c_id}: {c['payments_count']} txns — {fmt_inr(c['payments_amount'])}")
            lines.append(f"  Payouts: {m['payouts_count']} txns — {fmt_inr(m['payouts_amount'])}")
            for c_id, c in sorted(m["connectors"].items()):
                if c["payouts_count"] > 0:
                    lines.append(f"    via {c_id}: {c['payouts_count']} txns — {fmt_inr(c['payouts_amount'])}")

    if metrics["connectors"]:
        lines += ["", "**PSP Connectors**"]
        for c_id, c in sorted(metrics["connectors"].items()):
            lines.append(
                f"• {c_id}: {c['payments_count']} pay / {c['payouts_count']} pout "
                f"— {fmt_inr(c['payments_amount'])} / {fmt_inr(c['payouts_amount'])}"
            )

    return "\n".join(lines)


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
