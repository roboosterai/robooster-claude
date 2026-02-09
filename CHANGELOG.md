# Changelog

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
