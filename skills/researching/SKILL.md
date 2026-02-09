---
name: researching
description: Conduct structured research on any topic with source citations. Supports company, product, market, person, technical, competitive, and general research.
user-invocable: true
---

# Structured Research Skill

Conduct comprehensive, source-cited research and produce structured reports.

---

## Core Principles

- **Domain-explicit** — Always pass domain to web-researcher agent
- **Skill writes documents** — Agent returns findings, skill composes report
- **Template-driven** — Load template ONLY after agent returns findings
- **Source everything** — Every fact must have a cited source

---

## Workflow

Execute phases in order. Use `AskUserQuestion` for all user interaction.

---

### Phase 1: Initialize

**Goal:** Establish session date and project context

**Actions:**

1. **Session date:** !`date +%Y-%m-%d`

2. **Check for inherited project context:**
   - If args contain `--project={value}`, use that value and skip to step 4
   - Otherwise, continue to step 3

3. **Determine project context using AskUserQuestion:**

   **Question:** "Which project is this work for?"

   **Options:**

   | Option           | Description                                              |
   |------------------|----------------------------------------------------------|
   | **Platro**       | Platro payment platform — saves to `platro/platro-kb/`   |
   | **General/Root** | Cross-project or general work — saves to root `kb/`      |

4. **Set session variables based on selection:**

   | Project      | `{KB_ROOT}`         | `{GITHUB_REPO}`                            |
   |--------------|---------------------|--------------------------------------------|
   | Platro       | `platro/platro-kb`  | `https://github.com/roboosterai/platro-kb` |
   | General/Root | `kb`                | `~`                                        |

5. **Confirm to user:**

   > Starting research session
   > - Date: {DATE}
   > - Project: {PROJECT}
   > - KB: {KB_ROOT}/

**Proceed when:** Date and project context established

---

### Phase 2: Determine Research Type

**Goal:** Identify which domain to research

**Actions:**

1. **If domain is clear from user request** — proceed to Phase 3

2. **If domain is unclear** — use `AskUserQuestion`:

   **Question:** "What type of research do you need?"

   **Options:**
   | Option | Description |
   |--------|-------------|
   | **Company** | Deep analysis (funding, leadership, strategy, products, pricing) |
   | **Product** | Detailed product analysis (features, pricing, sentiment, alternatives) |
   | **Market** | Industry analysis (size, trends, players, outlook) |
   | **Person** | Individual profile (career, achievements, expertise) |
   | **Technical** | Framework, library, or API documentation analysis |
   | **Competitive** | Compare multiple entities side-by-side |
   | **General** | Flexible research on any other topic |

**Domain mapping:**

| User Intent | Domain |
|-------------|--------|
| Company analysis | `company` |
| Product analysis | `product` |
| Market/industry analysis | `market` |
| Person/team profile | `person` |
| Technology/docs | `technical` |
| Compare entities | `competitive` |
| Everything else | `general` |

**Proceed when:** Domain determined

---

### Phase 3: Gather Context

**Goal:** Collect subject(s) and specific research questions

**Actions:**

1. **For single-domain research:**

   Ask for subject based on domain:
   | Domain | Question |
   |--------|----------|
   | company | "Which company should I research?" |
   | product | "Which product should I research?" |
   | market | "Which market or industry should I analyze?" |
   | person | "Who should I research? (name and context)" |
   | technical | "Which technology, framework, or API should I research?" |
   | general | "What topic should I research?" |

2. **For competitive research:**

   Ask: "Which entities should I compare? (list all — companies or products)"

   Determine entity type (company or product) for agent calls.

3. **For multi-domain research** (user request spans multiple domains):

   Identify all required domains and subjects.

   Example: "Research the AI market and top 3 players"
   - Domain 1: `market` → "AI market"
   - Domain 2: `company` → "Company A"
   - Domain 3: `company` → "Company B"
   - Domain 4: `company` → "Company C"

4. **Gather focus areas:**

   If user hasn't specified: "Any specific questions or areas to focus on?"

**Proceed when:** Subject(s) and context gathered

---

### Phase 4: Spawn Agent(s)

**Goal:** Execute research via web-researcher agent(s)

**Agent call format:**

```
Task(
  subagent_type: "robooster-claude:web-researcher",
  prompt: "Domain: {domain}
Subject: {subject}
Date: {date}

Research context: {user's specific questions/focus areas}

Return structured findings. Do not write files.",
  description: "Researching {subject}"
)
```

**Scenarios:**

#### Single-Domain Research

One agent call:
```
Task(
  subagent_type: "robooster-claude:web-researcher",
  prompt: "Domain: company\nSubject: Stripe\nDate: 2026-01-21\n\nResearch context: Focus on payment processing capabilities and enterprise pricing.\n\nReturn structured findings. Do not write files.",
  description: "Researching Stripe"
)
```

#### Competitive Research

**CRITICAL:** Spawn agents IN PARALLEL (single message, multiple Task calls)

```
Task(subagent_type: "robooster-claude:web-researcher", prompt: "Domain: company\nSubject: Stripe\nDate: 2026-01-21...", description: "Researching Stripe")
Task(subagent_type: "robooster-claude:web-researcher", prompt: "Domain: company\nSubject: Adyen\nDate: 2026-01-21...", description: "Researching Adyen")
Task(subagent_type: "robooster-claude:web-researcher", prompt: "Domain: company\nSubject: PayPal\nDate: 2026-01-21...", description: "Researching PayPal")
```

#### Multi-Domain Research

**CRITICAL:** Spawn agents IN PARALLEL (single message, multiple Task calls)

```
Task(subagent_type: "robooster-claude:web-researcher", prompt: "Domain: market\nSubject: AI assistants market...", description: "Researching AI market")
Task(subagent_type: "robooster-claude:web-researcher", prompt: "Domain: company\nSubject: OpenAI...", description: "Researching OpenAI")
Task(subagent_type: "robooster-claude:web-researcher", prompt: "Domain: company\nSubject: Anthropic...", description: "Researching Anthropic")
```

**Proceed when:** All agent(s) return findings

---

### Phase 5: Receive Findings

**Goal:** Collect and validate agent output

**Actions:**

1. **Collect all agent findings**

2. **Validate coverage:**
   - Do findings address user's questions?
   - Are there critical gaps?

3. **If significant gaps** — optionally spawn additional agent(s) to fill gaps

**Agent output structure** (expected from web-researcher):
```
## Overview
[Key facts]

## Main Findings
### [Section 1]
[Content with source citations]

## Gaps & Limitations
[What couldn't be found]

## Sources
| Source | URL | Date | Reliability |

## Confidence Assessment
[High/Medium/Low + reasoning]
```

**Proceed when:** Findings validated

---

### Phase 6: Compose Document

**Goal:** Create final research document using template

**Actions:**

1. **Determine output type:**

   | Scenario | Output Type | Template |
   |----------|-------------|----------|
   | Single-domain | Same as domain | `templates/{domain}.md` |
   | Competitive | competitive | `templates/competitive.md` |
   | Multi-domain | general | `templates/general.md` |

2. **Read template:**
   ```
   Read: .claude/skills/researching/templates/{type}.md
   ```

   **CRITICAL:** Read template ONLY now, AFTER agents return findings

3. **Compose document:**
   - Fill template sections with agent findings
   - Preserve sources table from agent(s)
   - Preserve gaps and limitations
   - Set confidence based on agent assessment(s)

4. **For competitive research:**
   - Merge entity summaries into comparison matrix
   - Synthesize cross-entity analysis
   - Combine all sources tables

5. **For multi-domain research:**
   - Organize findings by domain
   - Synthesize overall conclusions
   - Combine all sources tables

**Proceed when:** Document composed

---

### Phase 7: Save and Present

**Goal:** Save document and present summary to user

**Actions:**

1. **Generate filename:**

   Pattern: `YYYYMMDD-research-{type}-{slug}.md`

   Examples:
   - `20260121-research-company-stripe.md`
   - `20260121-research-competitive-payment-providers.md`
   - `20260121-research-general-ai-code-generation.md`

2. **Save document:**

   Write to: `{KB_ROOT}/research/{filename}`

3. **Present to user** using output format below

**Proceed when:** File saved and summary presented

---

## Output Format

Present research completion to user:

```markdown
## Research Complete

**Subject:** {subject}
**Type:** {type}
**Confidence:** {confidence}
**Project:** {PROJECT}
**KB:** {KB_ROOT}/

### Summary

{2-3 sentence summary of key findings}

### Key Points

- {Key finding 1}
- {Key finding 2}
- {Key finding 3}

**Full report:** [{filename}]({KB_ROOT}/research/{filename})
```

---

## Frontmatter

All research documents require YAML frontmatter for machine parsing.

### Required Fields

```yaml
---
title: "{subject} - {Domain} Research"
description: "1-2 sentence summary of key findings (max 300 chars)"
type: research
status: draft
version: "1.0.0"
created: {YYYY-MM-DD}
updated: {YYYY-MM-DD}
author: skill::researching
modified_by: skill::researching
linear: ~
---
```

### Field Rules

| Field | Value |
|-------|-------|
| `title` | `{subject} - {Domain} Research` (e.g., "Stripe - Company Research") |
| `description` | Summarize key findings, not the research topic. Active voice. |
| `type` | Always `research` |
| `status` | Always `draft` for new documents |
| `version` | Always `"1.0.0"` for new documents |
| `created` / `updated` | Research date (from Phase 1) |
| `author` / `modified_by` | Always `skill::researching` |
| `linear` | Always `~` (research is standalone) |

### Description Guidelines

Write description AFTER composing the document. Summarize findings, not intent.

**Good:** "Stripe processes $1T+ annually with 135+ currency support. Enterprise pricing negotiable from 2.7%+30¢."

**Bad:** "Research about Stripe's payment processing capabilities."

---

## Rules

1. **Always pass domain explicitly** — never assume agent knows the domain
2. **Read template AFTER agent returns** — not before
3. **Spawn parallel agents** — for competitive and multi-domain research
4. **Preserve all sources** — merge source tables from all agents
5. **Flat file structure** — all research goes to `{KB_ROOT}/research/`
6. **Clean output** — brief summary, not full report dump
7. **Frontmatter required** — every document must have valid frontmatter

