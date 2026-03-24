# Changelog

## 2.8.3 — 2026-03-24

**Changed**
- Improved monitoring-check report formatting for Telegram — removed code blocks and backticks, added critical output rules, structured assessment section

## 2.8.2 — 2026-03-24

**Changed**
- Set monitoring-check skill to use Sonnet model

## 2.8.1 — 2026-03-24

**Added**
- monitoring-check skill — periodic platform health check via prod OpenSearch (ERROR/WARN log analysis with severity classification and formatted reports)

## 2.8.0 — 2026-03-17

**Added**
- Auto-detect project context from working directory in 5 skills (brainstorming, concept-writing, researching, specs-writing, task-implementing)
- Shared rules system (setup-rules.sh + shared-rules/conventions.md)

**Changed**
- Plugin scope detection reads installed_plugins.json directly instead of CLI output
- Improved repo discovery paths in robooster-claude-updating (CWD, child, sibling, parent-sibling)

**Removed**
- Checkpoint-resume system (SessionStart hook, resume-checkpoint.sh, checkpoint writes in task-implementing)

## 2.7.0 — 2026-03-06

**Added**
- Incoming PSP webhook query (IncomingWebhookReceive flow search)
- Outgoing merchant webhook query (trigger_webhook_and_raise_event search)
- Connector API request/response query (execute_connector_processing_step search)
- Phase 2A-bis: Signature & Raw Body Retrieval via request_id pipeline
- Webhook & signature follow-up rules in Phase 2B
- Timeline event types: IncomingWebhook, SignatureVerified/Failed, OutgoingWebhook, ConnectorRequest/Response
- Adaptive investigation rules 14-19 for webhook/signature scenarios
- Payout search note about sparse payout_id keyword indexing

**Changed**
- OpenSearch Field Reference with new router index fields (incoming_webhook_payload, request_id, event_type, Key fns)

## 2.6.5 — 2026-03-06

**Changed**
- Renamed all server→router references in transaction-investigating skill (index names, source labels, field references)

## 2.6.4 — 2026-03-04

**Changed**
- Updated transaction-investigating skill: router log path (server.log → router.log), unified .env credential paths for remote envs

## 2.6.3 — 2026-03-02

**Fixed**
- Added missing platro-services ledger log path to transaction-investigating local env queries

## 2.6.2 — 2026-02-27

**Changed**
- Reordered transaction-investigating workflow: logs queried first, DB only when needed
- Simplified Phase 4 (Synthesize) with chronological events table as primary output

**Added**
- Database Schema Reference with verified column names for all 9 tables
- Chronological events table format with source labels and inline key data
- SourceId as secondary lookup path for ledger_transactions

**Fixed**
- SQL queries using wrong column names: refund_status, refund_error_code, refund_error_message, dispute_status, AccountName, BalanceAfter
- Removed non-existent columns: connector on payouts, Status on ledger_transactions, MerchantId/Status/TotalAmount/WirePayoutId on allocation_batches

## 2.6.1 — 2026-02-27

**Added**
- `transaction-investigating` skill for end-to-end transaction debugging across databases, logs, and ledger

## 2.6.0 — 2026-02-10

**Added**
- bug-reporter agent for registering bugs as KB markdown files
- Bug registration flow at Gate G3 in task-implementing for unresolved code-review findings

## 2.5.0 — 2026-02-10

**Added**
- spec-reviewing skill for guided iteration over feature spec documents

## 2.4.1 — 2026-02-09

**Changed**
- Simplified concept-reviewing skill: removed EnterPlanMode/ExitPlanMode ceremony, auto-decide codebase exploration, single-pass verification
- Added "no code changes" boundary rule to concept-reviewing

## 2.4.0 — 2026-02-09

**Added**
- concept-reviewing skill for guided iteration over concept documents

## 2.3.4 — 2026-02-09

**Removed**
- Debug CWD/cat probes from concept-writing skill
- Test template files (DRY experiment concluded)

## 2.3.3 — 2026-02-09

**Added**
- CWD and cat debug probes in concept-writing skill to validate template injection
- Template placeholder file for Phase 1 DRY experiment

## 2.3.2 — 2026-02-09

**Changed**
- Use inject-dynamic-context for session date in all 5 document-producing skills

## 2.3.1 — 2026-02-06

**Changed**
- Code reviewer agents receive only implementation files, excluding test files already validated by test-verifier

## 2.3.0 — 2026-02-06

**Added**
- Checkpoint-resume mechanism to survive context compacting in task-implementing skill
- resume-checkpoint.sh hook script for automatic state recovery after compacting
- SessionStart hook for compact event detection
- Iteration summary output between Phase 5 review rounds
- Smart agent re-run logic to skip clean agents on iteration 2+

**Changed**
- Switched code-reviewer, test-verifier, ac-verifier agents from opus to sonnet model
- Added 1500-token output budget constraint to 6 agents
- AC verification now displays condensed summary instead of full output
- Build/test command outputs truncated to last 100 lines

## 2.2.3 — 2026-02-03

**Changed**
- task-implementing skill now displays detailed ac-verifier output with verification summary, detailed results table, and evidence for each acceptance criterion

## 2.2.2 — 2026-02-03

**Added**
- CHANGELOG.md for tracking version history

**Changed**
- Auto-generated release notes and semantic commit messages in robooster-claude-updating skill

## 2.2.0 — 2026-02-02

**Added**
- test-verifier agent for mutation testing validation
- `--muttests` flag to task-implementing skill

**Changed**
- Task handoff documents now use structured format

## 2.1.0 — 2026-01-28

**Added**
- KB auto-sync hook for automatic knowledge base commits

## 2.0.0 — 2026-01-25

**Changed**
- Major restructure of skills and agents
- Moved from root kb to robooster-claude plugin

## 1.2.1 — 2026-01-24

**Fixed**
- Plugin version sync issues
