---
name: analytics-report
description: Platform analytics report — payments and payouts metrics by merchant
  and connector. Pre-executes SQL queries via Python script and formats results.
  Use for periodic analytics or when asked about business metrics.
model: haiku
user-invocable: true
---

# Analytics Report

## Data

!`python3 ${CLAUDE_SKILL_DIR}/scripts/collect.py`

## Instructions

The data above is a JSON object with two fields:

- **formatted_report**: A pre-formatted Telegram message. Output this EXACTLY as-is
  as the first part of your response. Do not modify, reformat, or add to it.

- **metrics**: Structured data for your analysis. If not null, append a brief
  **Summary** section (2-3 bullets) covering:
  - Notable patterns (e.g., one merchant dominates volume)
  - Payment-to-payout ratio and whether it looks normal
  - Anything unusual or worth flagging

If metrics is null (error case), just output the formatted_report as-is.

CRITICAL: Start your response with the formatted_report content directly.
No preamble, no "Here is the report", no thinking out loud.
