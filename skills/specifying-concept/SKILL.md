---
name: specifying-concept
description: Transform concept documents into formal PRDs (Product Requirements Documents). Use when you have an approved concept and need to create actionable requirements. Outputs to kb/requirements/ with Linear integration.
user-invocable: true
---

# Specifying Concept

Transform concept documents into structured PRDs that are optimized for AI consumption while remaining human-readable. The goal is a document that architecture agents can parse and execute against.

## Core Principles

- **Concept-driven** — Requirements trace back to concept; concept is source of truth
- **Intent over implementation** — Capture WHAT to build, not HOW
- **Explicit boundaries** — Out-of-scope and protected elements are as important as requirements
- **Testable criteria** — Every requirement should map to verifiable acceptance criteria
- **One question per message** — Keep interactions focused and unambiguous
- **Human gates** — User approves at key decision points

## Workflow

Execute these phases in order. Use `AskUserQuestion` tool for all questions.

---

### Phase 1: Initialize

**Goal:** Establish session date and project context

**Actions:**

1. **Get current date:**

   ```bash
   date +%Y-%m-%d
   ```

2. **Determine project context using AskUserQuestion:**

   **Question:** "Which project is this work for?"

   **Options:**

   | Option           | Description                                              |
   |------------------|----------------------------------------------------------|
   | **Platro**       | Platro payment platform — saves to `platro/platro-kb/`   |
   | **General/Root** | Cross-project or general work — saves to root `kb/`      |

   **Smart inference:** If loading from a concept path, suggest project based on path:
   - `platro/platro-kb/concepts/...` → suggest Platro
   - `kb/concepts/...` → suggest Root

3. **Set session variables based on selection:**

   | Project      | `{KB_ROOT}`         | `{GITHUB_REPO}`                            |
   |--------------|---------------------|--------------------------------------------|
   | Platro       | `platro/platro-kb`  | `https://github.com/roboosterai/platro-kb` |
   | General/Root | `kb`                | `~`                                        |

4. **Confirm to user:**

   > Starting PRD creation session
   > - Date: {DATE}
   > - Project: {PROJECT}
   > - KB: {KB_ROOT}/

**Proceed when:** Date and project context established

→ Proceed to Phase 2

---

### Phase 2: Input Collection

**Goal:** Load and validate the concept document input.

**Actions:**

1. **Identify concept source** — Ask user:
   - "Which concept should I convert to a PRD?"

   Options:
   - User provides file path (e.g., `{KB_ROOT}/concepts/20260120-concept-feature.md`)
   - User provides concept content directly
   - User asks to find recent concepts

2. **If user asks to find concepts:**
   - List recent files from `{KB_ROOT}/concepts/`
   - Present options and let user select

3. **Load and validate the concept:**
   - Read the document
   - Verify it contains required structure:
     - Overview
     - Problem Statement
     - Core Idea
     - Key Components
     - User Experience (optional)
     - Technical Considerations (optional)
   - If missing required elements, ask user to provide them or select a different concept

4. **Extract metadata:**
   - Extract Linear task ID if exists in concept frontmatter
   - Note concept status (draft, approved, etc.)

5. **Use project context from Phase 1:**
   - If project is Platro, prepare to explore Platro codebase in Phase 3
   - If project is General/Root, ask if there's an existing codebase to explore

6. **Present summary:**
   - "I found this concept about: [topic]"
   - "Core idea: [brief summary]"
   - "Key components: [list]"
   - "Ready to proceed with PRD creation?"

**Proceed when:** User confirms ready to proceed

→ Proceed to Phase 3

---

### Phase 3: Codebase Exploration

**CONDITIONAL:** Only if concept is for existing project with codebase

**Goal:** Understand existing code patterns relevant to requirements

**Actions:**

1. Read relevant CLAUDE.md files for the project

2. Launch code-explorer agent:

   ```
   Task(
     subagent_type: "code-explorer",
     prompt: "Explore codebase for patterns related to [concept topic].
              Focus on: existing implementations, conventions, extension points.
              Return summary of findings relevant to writing requirements.",
     description: "Explore codebase for PRD context"
   )
   ```

3. Note constraints and patterns for requirements:
   - Existing patterns to follow
   - Extension points to use
   - Constraints from current architecture

**Proceed when:** Codebase context understood or phase skipped (not a codebase project)

→ Proceed to Phase 4

---

### Phase 4: Deep Concept Analysis

**Goal:** Extract all implicit and explicit requirements from concept document

**Actions:**

1. Read concept systematically, section by section

2. Extract requirement candidates from:
   - Problem Statement → what must be solved
   - Core Idea → what must be implemented
   - Key Components → component-specific requirements
   - User Experience → user-facing requirements
   - Technical Considerations → constraints, NFRs
   - Open Questions → items needing resolution or deferral

3. Build initial FR candidate list with traceability:

   ```
   FR candidates:
   - FR-1: {requirement} [from: Core Idea]
   - FR-2: {requirement} [from: Key Components > Component 1]
   ```

4. Present extraction summary to user:
   > Based on the concept, I've extracted these requirement candidates:
   > [list FRs with sources]
   >
   > Is this extraction reasonable? Any missing requirements?

**Proceed when:** User confirms extraction is reasonable

→ Proceed to Phase 5

---

### Phase 5: Research

**OPTIONAL:** User chooses whether to conduct research

**Goal:** Gather additional context if needed for requirements clarity

**Actions:**

1. Ask user:
   "Do you need additional research to clarify any requirements?"

   Options:
   - **External research** — Market, technical, best practices (uses researching skill)
   - **No research needed** — Proceed to requirements elicitation

2. If research needed:

   ```
   Skill(skill="researching", args="{topic} --project={PROJECT}")
   ```

3. Synthesize findings into requirements context

**Proceed when:** Research complete or skipped

→ Proceed to Phase 6

---

### Phase 6: Requirements Elicitation

**Goal:** Refine and confirm functional requirements with user; elicit NFRs.

**Actions:**

1. **Group FRs by domain/component** (from Phase 4 extraction)

2. **Present each group for confirmation:**

   ```
   Here are the requirements for [Component X]:
   - FR-1: {requirement} [from: Core Idea]
   - FR-2: {requirement} [from: Key Components]

   Confirm, modify, or remove any?
   ```

3. **After all groups confirmed:** Ask "Any requirements missing?"

4. **Elicit Non-Functional Requirements:**
   - "Any response time or throughput expectations?" (Performance)
   - "Any security requirements?" (Security)
   - "Any scale expectations?" (Scalability)
   - "Any data retention or format requirements?" (Data)

5. **Define scope explicitly:**

   **In-Scope:**
   - "What MUST be included? List the essential capabilities."

   **Out-of-Scope:**
   - "What should we explicitly EXCLUDE?"
   - "Any features to defer to future iterations?"

   **Protected Elements:**
   - "Is there existing functionality that must NOT change?"
   - "Any database schemas, API contracts, or integrations to preserve?"

6. **Present scope summary:**

   ```
   Scope Definition:

   IN SCOPE:
   - {item 1}
   - {item 2}

   OUT OF SCOPE:
   - {item 1}
   - {item 2}

   PROTECTED (DO NOT CHANGE):
   - {item 1 or "None identified"}
   ```

7. **Verification checkpoint:**
   - "Are requirements and scope complete and accurate?"

**Proceed when:** User confirms requirements and scope are complete

→ Proceed to Phase 7

---

### Phase 7: Acceptance Criteria

**Goal:** Define testable success conditions.

**Actions:**

1. **Ask user preference:**
   - "What format do you prefer for acceptance criteria?"

   Options:
   - **Given/When/Then** — Structured BDD-style scenarios (recommended for complex features)
   - **Simple checklist** — Bullet points (faster for straightforward features)

2. **For Given/When/Then format:**
   Convert each requirement to scenarios:
   ```
   AC-1: Login validation
   - Given a user with valid credentials
   - When they submit the login form
   - Then they are redirected to the dashboard

   AC-2: Invalid credentials
   - Given a user with invalid credentials
   - When they submit the login form
   - Then they see an error message
   ```

3. **For Simple checklist format:**
   ```
   Acceptance Criteria:
   - [ ] User can log in with valid credentials
   - [ ] Invalid credentials show error message
   - [ ] Session persists across page refresh
   ```

4. **Define success metrics:**
   - "How will we measure success? What metrics matter?"
   - Examples: adoption rate, error rate, response time, user satisfaction

5. **Present complete acceptance criteria**

6. **Verification checkpoint:**
   - "Are these criteria testable and complete?"

**Proceed when:** User confirms criteria are testable and complete

→ Proceed to Phase 8

---

### Phase 8: Draft PRD

**Goal:** Compose the complete PRD document and iterate with user.

**Actions:**

1. **Assemble PRD** using all gathered information:

```markdown
---
title: "{Feature Name}"
description: "{1-2 sentence summary (max 300 chars)}"
type: requirements
status: draft
version: "1.0.0"
created: {YYYY-MM-DD}
updated: {YYYY-MM-DD}
author: skill::specifying-concept
modified_by: skill::specifying-concept
linear: {TASK-ID or ~}
---

# {Feature Name}

## Problem

{Problem statement from concept - 2-3 sentences}

## Solution

{Solution overview from concept Core Idea - 2-3 sentences}

## Requirements

### Functional Requirements

{From Phase 4 & 6 - grouped by component}

### Non-Functional Requirements

{From Phase 6 - Performance, Security, Scalability, Data}

### User Stories

{From concept User Experience section}

## Scope

### In Scope

{From Phase 6}

### Out of Scope

{From Phase 6}

### Protected Elements

{From Phase 6 - always include, even if "None identified"}

## Success Metrics

{From Phase 7}

## Acceptance Criteria

{From Phase 7}

## Dependencies

{Any identified dependencies, or "None identified"}

## Open Questions

{Any unresolved questions for architecture phase, or "None"}

## References

- Concept: [{filename}]({KB_ROOT}/concepts/{filename})
- Research: [{filename}]({KB_ROOT}/research/{filename}) (if applicable)
```

2. **Present draft to user:**
   - Show the complete PRD
   - "Here's the draft PRD. Please review each section."

3. **Iterate based on feedback:**
   - Make requested changes
   - Re-present updated sections

4. **Human gate:**
   - "Is this PRD ready for approval? Any final changes?"
   - Only proceed when user confirms approval

**Proceed when:** User approves PRD draft

→ Proceed to Phase 9

---

### Phase 9: Concept-PRD Alignment Check

**Goal:** Ensure PRD covers all concept aspects; fix discrepancies

**Actions:**

1. **Systematic comparison:**
   - Concept Key Components → PRD has FRs for each?
   - Concept User Scenarios → PRD has acceptance criteria?
   - Concept Problem Statement → PRD Problem section aligned?
   - Concept Open Questions → Resolved or in PRD Open Questions?

2. **For each discrepancy, ask user:**
   "Concept mentions [X] but PRD doesn't have requirement for it."

   Options:
   - **Add requirement to PRD** — Add missing FR/NFR
   - **Update concept** — Remove/modify in concept document
   - **Keep as-is** — Add to Open Questions

3. **If user chooses "Update concept":**

   ```
   Task(
     subagent_type: "kb-maintainer",
     prompt: "target_file: {KB_ROOT}/concepts/{filename}
              section: {section name}
              action_type: update
              content: {new content}
              reason: PRD alignment - {explanation}",
     description: "Update concept for PRD alignment"
   )
   ```

4. **Final alignment confirmation:**
   - "All concept aspects are covered in PRD. Ready to finalize?"

**Proceed when:** All discrepancies resolved

→ Proceed to Phase 10

---

### Phase 10: Linear Integration

**Goal:** Optionally create or link Linear task for PRD tracking.

**Actions:**

1. **Check if Linear task exists from concept:**
   - If concept had Linear ID → use that as parent/reference

2. **Ask about Linear integration:**
   - "Would you like me to create a Linear task for this PRD?"

   Options:
   - **Yes, create task** — Create new Linear issue with PRD link
   - **Yes, link to existing** — User provides existing issue ID
   - **No, skip for now** — Just save without Linear link

3. **If creating Linear task:**

   ```
   Task(
     subagent_type: "task-manager",
     prompt: "Create Linear task for PRD: {title}.
              Description: {summary}.
              Set status to backlog.
              KB context: {kb_identifier}={KB_ROOT}, github_repo={GITHUB_REPO}
              Documents: PRD={KB_ROOT}/requirements/{filename}",
     description: "Create Linear task for PRD"
   )
   ```

   - Update PRD frontmatter with Linear issue ID

4. **If linking to existing:**
   - Update PRD frontmatter with provided issue ID
   - Optionally update Linear issue with PRD link

**Proceed when:** Linear integration complete or skipped

→ Proceed to Phase 11

---

### Phase 11: Save & Summary

**Goal:** Save the PRD and present session summary.

**Actions:**

1. **Generate filename:**
   - Format: `YYYYMMDD-requirements-{title-slug}.md`
   - Title slug: lowercase, hyphenated (e.g., "User Authentication" → "user-authentication")
   - Example: `20260118-requirements-user-authentication.md`

2. **Save PRD:**
   - Path: `{KB_ROOT}/requirements/{filename}`
   - Create directory if needed: `mkdir -p {KB_ROOT}/requirements`
   - Write the file

3. **Present summary:**

   ```
   PRD Created Successfully!

   File: {KB_ROOT}/requirements/{filename}
   Project: {PROJECT}
   KB: {KB_ROOT}/
   Linear: {issue ID or "Not linked"}
   Concept: {source concept path}

   Next Steps:
   1. Review the PRD in your editor
   2. Share with stakeholders for final approval
   3. When ready, proceed to Architecture phase with /designing-architecture
   ```

**Session complete.**

---

## Human Gates

| Gate | Phase | Question | Pass | Fail |
|------|-------|----------|------|------|
| G1 | Phase 2 | "Ready to proceed with PRD creation?" | Continue | Select different concept |
| G2 | Phase 4 | "Is this extraction reasonable?" | Continue | Clarify |
| G3 | Phase 6 | "Are requirements complete?" | Continue | Iterate |
| G4 | Phase 8 | "Is PRD ready for approval?" | Continue | Iterate |
| G5 | Phase 9 | "Alignment complete?" | Continue | Fix discrepancies |
| G6 | Phase 10 | "Linear task preference?" | Create/Link/Skip | N/A |

---

## Output Template

### File Naming

`{KB_ROOT}/requirements/YYYYMMDD-requirements-{title-slug}.md`

Example: `20260121-requirements-wallet-privacy-model.md`

### Frontmatter

```yaml
---
title: "{Feature Name}"
description: "{1-2 sentence summary (max 300 chars)}"
type: requirements
status: draft
version: "1.0.0"
created: {YYYY-MM-DD}
updated: {YYYY-MM-DD}
author: skill::specifying-concept
modified_by: skill::specifying-concept
linear: {TASK-ID or ~}
---
```

### Document Structure

The PRD follows this structure (10 sections):

| Section | Purpose | AI Importance |
| ------- | ------- | ------------- |
| Problem | Why we're building this | Context for decisions |
| Solution | High-level what | Direction setting |
| Functional Requirements | Detailed what | Implementation guide |
| Non-Functional Requirements | Quality attributes | Constraints |
| User Stories | User perspective | Edge case discovery |
| In Scope | What to build | Boundary definition |
| Out of Scope | What NOT to build | Prevents scope creep |
| Protected Elements | What NOT to change | Prevents regressions |
| Success Metrics | How to measure | Validation criteria |
| Acceptance Criteria | Testable conditions | Test generation |

---

## Rules

1. **No code changes** — This skill only produces documents
2. **No architecture decisions** — That's for designing-architecture
3. **Concept is source of truth** — Requirements trace back to concept
4. **Always validate concept first** — Reject invalid/deprecated concepts
5. **Smart grouping** — Group related FRs for efficient confirmation
6. **Invoke researching skill for external research** — Never bypass to agents
7. **Always check alignment** — Concept and PRD must match
8. **Use kb-maintainer for concept updates** — Don't edit concept directly
9. **Frontmatter required** — V2 specification
10. **User approves at gates** — Don't proceed without confirmation

---

## Example Invocations

```
/specifying-concept
```

(Will prompt for concept document)

```
/specifying-concept from concept kb/concepts/20260121-concept-wallet-privacy.md
```

(Will load specified concept)

```
/specifying-concept for platro-services
```

(Will list concepts for specified project)
