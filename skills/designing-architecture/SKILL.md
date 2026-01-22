---
name: designing-architecture
description: Design comprehensive architecture from PRD and concept documents. Reviews inputs for gaps, explores codebase deeply, creates actionable architecture blueprints, and ensures PRD alignment.
user-invocable: true
---

# Designing Architecture

Bridge the gap between specification (PRD/Concept) and implementation by creating comprehensive architecture documents. This skill takes PRD, Concept documents, and optionally a Linear task as input, performs bidirectional gap analysis, and produces actionable architecture blueprints.

## Core Principles

- **Gap analysis first** — Thoroughly review PRD and Concept for inconsistencies before designing
- **Bidirectional comparison** — Check PRD->Concept and Concept->PRD alignment
- **Context-bound design** — Architecture design stays in this skill (not delegated to agents)
- **PRD alignment** — Keep PRD in sync with technical reality discovered during design
- **Deep codebase exploration** — Use code-explorer agents for thorough understanding
- **Ask, don't assume** — For each discrepancy, ask user to decide resolution
- **Human gates at key points** — Document review, architecture draft, PRD updates
- **One question per message** — Keep interactions focused
- **Comprehensive output** — Architecture must cover all aspects needed for implementation

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

   **Smart inference:** If loading from a PRD/Concept path, suggest project based on path:
   - `platro/platro-kb/requirements/...` → suggest Platro
   - `kb/requirements/...` → suggest Root

3. **Set session variables based on selection:**

   | Project      | `{KB_ROOT}`         | `{GITHUB_REPO}`                            |
   |--------------|---------------------|--------------------------------------------|
   | Platro       | `platro/platro-kb`  | `https://github.com/roboosterai/platro-kb` |
   | General/Root | `kb`                | `~`                                        |

4. **Confirm to user:**

   > Starting architecture design session
   > - Date: {DATE}
   > - Project: {PROJECT}
   > - KB: {KB_ROOT}/

**Proceed when:** Date and project context established

-> Proceed to Phase 2

---

### Phase 2: Input Collection

**Goal:** Gather all input documents (PRD required, Concept optional, Linear task optional)

**Actions:**

1. **Ask user what inputs they have:**
   - "What documents do you have for this architecture design?"

   Options:
   - PRD file path
   - Concept file path
   - Linear task ID
   - Combination of above

2. **If Linear task provided:**
   - Fetch task details using Linear MCP tools
   - Extract references to PRD/Concept from task description
   - Read referenced documents

3. **If PRD missing:**
   - PRD is **required** — cannot proceed without it
   - Redirect to specifying-concept skill:
     > "You need a PRD first. Would you like to run /specifying-concept to create one?"
   - Do NOT proceed until PRD is provided

4. **If Concept missing:**
   - Concept is **optional** but recommended
   - Ask if they have one — proceed without if not available
   - Note: Gap analysis will be limited to PRD alone if no Concept

5. **Load and display document summaries:**
   ```
   Documents Loaded:
   - PRD: {title} - {problem summary}
   - Concept: {title} - {scope summary} (or "Not provided")
   - Linear Task: {identifier} - {title} (or "Not linked")
   ```

**Human Gate G1:** "Documents loaded. Ready to proceed with gap analysis?"
- Pass: Continue to Phase 3
- Fail: Provide missing inputs or select different documents

---

### Phase 3: Document Review & Gap Analysis

**Goal:** Thoroughly review PRD and Concept, identify gaps and inconsistencies bidirectionally

**CRITICAL:** This phase must not be skipped.

**Actions:**

1. **Extract key sections from PRD:**
   - Problem statement
   - Functional requirements (FR-1, FR-2, etc.)
   - Non-functional requirements
   - In-scope / Out-of-scope
   - Protected elements
   - Acceptance criteria
   - Success metrics

2. **Extract key sections from Concept (if available):**
   - Core idea / Technical approach
   - Data models
   - Transaction/operation flows
   - Configuration models
   - Key components
   - Dependencies and constraints

3. **Bidirectional comparison:**

   **PRD -> Concept check:**
   - For each requirement in PRD, check if Concept addresses it
   - Flag requirements not covered in Concept

   **Concept -> PRD check:**
   - For each technical component/approach in Concept, check if PRD has corresponding requirement
   - Flag implementation ideas not backed by requirements

4. **Identify inconsistencies:**
   - Conflicting statements between documents
   - Ambiguous or underspecified requirements
   - Missing error handling or edge cases
   - Scope mismatches

5. **Present findings:**
   ```
   ## Document Review Findings

   ### Coverage Analysis
   - FR-1: Covered in Concept sections 4, 5 [check]
   - FR-2: Not explicitly addressed in Concept [warning]

   ### Concept -> PRD Gaps
   - Concept proposes component X with no corresponding requirement

   ### Inconsistencies Found
   - PRD says X, Concept says Y

   ### Gaps Identified
   - No error handling specified for scenario Z
   - Edge case Q not addressed
   ```

6. **For each gap/inconsistency, ask user to decide:**

   Use `AskUserQuestion` for each discrepancy:

   **Question:** "PRD requirement FR-2 is not addressed in Concept. How should we resolve this?"

   **Options:**
   | Option | Description |
   |--------|-------------|
   | **Add to PRD** | Add missing requirement/clarification to PRD |
   | **Update Concept** | Modify concept to address this |
   | **Keep as-is** | Add to Open Questions in architecture |

7. **If user chooses "Add to PRD" or "Update Concept":**

   ```
   Task(
     subagent_type: "kb-maintainer",
     prompt: "target_file: {KB_ROOT}/{document path}
              section: {section name}
              action_type: update
              content: {new/modified content}
              reason: Architecture gap analysis - {explanation}",
     description: "Update document for architecture alignment"
   )
   ```

8. **Repeat for all discrepancies**

**Human Gate G2:** "All discrepancies resolved or documented. Ready to explore codebase?"
- Pass: Continue to Phase 4
- Fail: Fix remaining discrepancies

---

### Phase 4: Codebase Exploration

**Goal:** Deeply understand existing code patterns, conventions, and similar features

**Actions:**

1. **Launch 2-3 code-explorer agents in parallel:**

   Agent prompts based on PRD/Concept content:

   ```
   Task(
     subagent_type: "code-explorer",
     prompt: "Find features similar to [feature from PRD] and trace through their implementation comprehensively. Focus on patterns, abstractions, and conventions used. Return a list of 5-10 key files to read.",
     description: "Explore similar features"
   )
   ```

   ```
   Task(
     subagent_type: "code-explorer",
     prompt: "Map the architecture and abstractions for [relevant area]. Understand module boundaries, data flow patterns, and extension points. Return a list of 5-10 key files to read.",
     description: "Map architecture patterns"
   )
   ```

   ```
   Task(
     subagent_type: "code-explorer",
     prompt: "Analyze how [relevant systems from PRD] integrate with each other. Find existing patterns for [specific integration need]. Return a list of 5-10 key files to read.",
     description: "Analyze integration points"
   )
   ```

2. **Read key files identified by agents** to build detailed context

3. **Identify services/projects to be touched:**
   - From PRD scope and agent findings, identify which services will be modified
   - **Read CLAUDE.md for each identified service** (e.g., `platro/platro-services/CLAUDE.md`)
   - Note service-specific conventions, patterns, and requirements
   - **Flag if `platro-services` is involved** (implementation will require XML documentation)

4. **Summarize findings:**
   ```
   ## Codebase Exploration Findings

   ### Services Involved
   - {service 1}: {CLAUDE.md conventions noted}
   - {service 2}: {CLAUDE.md conventions noted}

   ### Existing Patterns
   - Pattern A: Used in [files] for [purpose]
   - Pattern B: Standard approach for [scenario]

   ### Conventions
   - Naming: [conventions found]
   - Structure: [module organization]
   - Testing: [test patterns]

   ### Similar Features
   - [Feature X] in [location] - relevant because [reason]

   ### Integration Points
   - [System A] connects via [mechanism]
   ```

5. **Ask clarifying questions:**
   - Questions about design choices not clear from code
   - Questions about undocumented conventions
   - Questions about technical constraints

**Human Gate G3:** "Do I have enough context to design the architecture? Any areas I should explore further?"
- Pass: Continue to Phase 5
- Fail: Explore more areas

---

### Phase 5: Architecture Design

**Goal:** Create comprehensive architecture document with all implementation details

**IMPORTANT:** This skill performs architecture design directly — do NOT delegate to code-architect agent. This is context-bound work requiring full conversation history.

**Actions:**

1. **Design decisions:**
   For each significant technical choice:
   - State the decision clearly
   - List alternatives considered
   - Explain rationale for chosen approach
   - Note trade-offs accepted

2. **Component design:**
   For each component:
   - File path (new or existing)
   - Responsibilities
   - Dependencies
   - Public interface
   - Internal structure

3. **Data model:**
   - New entities/tables
   - Schema changes
   - Relationships
   - Migration requirements

4. **API design (if applicable):**
   - Endpoints
   - Request/response formats
   - Error codes
   - Versioning considerations

5. **Flow diagrams:**
   - Key operation flows (ASCII diagrams)
   - State transitions
   - Error paths

6. **Implementation sequence:**
   - Ordered list of implementation steps
   - Dependencies between steps
   - Parallel work opportunities

7. **Present draft architecture to user:**
   - Walk through each section
   - Highlight key decisions
   - Ask for feedback

**Human Gate G4:** "Does this architecture meet all the requirements? Any concerns or changes needed?"
- Pass: Continue to Phase 6
- Fail: Iterate on architecture

---

### Phase 6: PRD Alignment

**Goal:** Ensure PRD is fully aligned with the architecture

**Actions:**

1. **Compare architecture with PRD:**
   - Every FR must map to architecture components
   - Every acceptance criterion must be achievable with the design
   - Protected elements must be preserved in design

2. **Identify PRD updates needed:**
   - Requirements that need clarification based on architecture
   - New requirements discovered during design
   - Scope adjustments based on technical reality

3. **Propose PRD updates:**
   ```
   ## Recommended PRD Updates

   1. FR-3: Clarify to specify [detail]
   2. Add FR-12: [new requirement discovered]
   3. Update AC-5: Change expected behavior to [new behavior]
   ```

4. **Get user approval on PRD changes**

5. **If user approves updates:**

   ```
   Task(
     subagent_type: "kb-maintainer",
     prompt: "target_file: {KB_ROOT}/requirements/{PRD filename}
              section: {section name}
              action_type: update
              content: {updated content}
              reason: Architecture alignment - {explanation}
              Also update: version (increment minor), updated date, modified_by: skill::designing-architecture",
     description: "Update PRD for architecture alignment"
   )
   ```

6. **Update PRD references section** to link to architecture document

**Human Gate G5:** "PRD and architecture are now aligned. Ready to finalize?"
- Pass: Continue to Phase 7
- Fail: Iterate on updates

---

### Phase 7: Linear Integration

**Goal:** Create or link Linear task for architecture tracking

**Actions:**

1. **Ask about Linear task:**

   **Question:** "Would you like to create or link a Linear task for this architecture?"

   **Options:**
   | Option | Description |
   |--------|-------------|
   | **Create new task** | Create a new Linear task and link it to this architecture |
   | **Link to existing task** | Associate with an existing Linear task (I'll ask for the ID) |
   | **No task needed** | This architecture doesn't need a Linear task right now |

2. **If "Create new task":**

   ```
   Task(
     subagent_type: "task-manager",
     prompt: "Create a Linear task for architecture: {title}.
              Description: {summary}
              Set status to backlog or appropriate state.
              KB context: {kb_identifier}={KB_ROOT}, github_repo={GITHUB_REPO}
              Documents: Architecture={KB_ROOT}/architecture/{filename}, PRD={KB_ROOT}/requirements/{prd_filename}
              Return the task ID.",
     description: "Create Linear task for architecture"
   )
   ```

   - Extract task ID from result
   - Set `linear:` field in frontmatter

3. **If "Link to existing task":**
   - Ask for Linear task ID
   - Validate format (e.g., PROJ-123)
   - Set `linear:` field in frontmatter

   ```
   Task(
     subagent_type: "task-manager",
     prompt: "Update Linear task {ID}: Add document references section with:
              KB context: {kb_identifier}={KB_ROOT}, github_repo={GITHUB_REPO}
              Documents:
              - Architecture: {KB_ROOT}/architecture/{filename}
              - PRD: {KB_ROOT}/requirements/{prd_filename}
              - Concept: {KB_ROOT}/concepts/{concept_filename} or N/A
              Update status to 'to-dev' if appropriate.",
     description: "Update Linear task with architecture docs"
   )
   ```

4. **If "No task needed":**
   - Set `linear: ~` in frontmatter

**Human Gate G6:** Linear task preference recorded
- Create/Link/Skip: Proceed to Phase 8

---

### Phase 8: Finalize & Save

**Goal:** Save the architecture document and provide summary

**Actions:**

1. **Generate filename:**
   - Format: `YYYYMMDD-architecture-{title-slug}.md`
   - Use same title-slug as PRD for traceability
   - Example: `20260121-architecture-3-role-ledger.md`

2. **Assemble final architecture document** using the Output Template below

3. **Save to `{KB_ROOT}/architecture/`**
   - Create directory if needed: `mkdir -p {KB_ROOT}/architecture`

4. **Update PRD references section** to link to architecture doc (if not already done):

   ```
   Task(
     subagent_type: "kb-maintainer",
     prompt: "target_file: {KB_ROOT}/requirements/{prd_filename}
              section: References
              action_type: update
              content: Add link to architecture document: [Architecture]({KB_ROOT}/architecture/{filename})
              reason: Link PRD to completed architecture",
     description: "Link PRD to architecture"
   )
   ```

5. **Present summary:**

   ```
   ## Architecture Complete

   Architecture: {KB_ROOT}/architecture/{filename}
   Project: {PROJECT}
   KB: {KB_ROOT}/
   PRD: {prd_path} (updated: {changes summary or "no changes"})
   Linear: {task ID or "Not linked"}

   Key Decisions:
   1. [Decision 1]
   2. [Decision 2]

   Implementation Sequence:
   1. [Phase 1]
   2. [Phase 2]

   Next Steps:
   - Review architecture with stakeholders
   - When approved, use /implementing-feature to begin implementation
   ```

**Session complete.**

---

## Human Gates

| Gate | Phase | Question | Pass | Fail |
|------|-------|----------|------|------|
| G1 | Phase 2 | "Ready to proceed with gap analysis?" | Continue | Provide missing inputs |
| G2 | Phase 3 | "Discrepancies resolved?" | Continue | Fix remaining |
| G3 | Phase 4 | "Enough codebase context?" | Continue | Explore more |
| G4 | Phase 5 | "Architecture meets requirements?" | Continue | Iterate |
| G5 | Phase 6 | "PRD and architecture aligned?" | Continue | Update |
| G6 | Phase 7 | "Linear task preference?" | Create/Link/Skip | N/A |

---

## Output Template

### File Naming

`{KB_ROOT}/architecture/YYYYMMDD-architecture-{title-slug}.md`

Example: `20260121-architecture-wallet-privacy-model.md`

### Frontmatter

```yaml
---
title: "{Feature Name}"
description: "{1-2 sentence summary (max 300 chars)}"
type: architecture
status: draft
version: "1.0.0"
created: {YYYY-MM-DD}
updated: {YYYY-MM-DD}
author: skill::designing-architecture
modified_by: skill::designing-architecture
linear: {TASK-ID or ~}
---
```

### Document Structure

The architecture document follows this structure (14 sections):

```markdown
# {Feature Name} - Architecture

## 1. Overview

### 1.1 Purpose
{Brief description of what this architecture covers}

### 1.2 Scope
{What is and isn't covered by this architecture}

### 1.3 Related Documents
- PRD: {path}
- Concept: {path or "N/A"}
- Research: {paths or "N/A"}

---

## 2. Context

### 2.1 Current State
{How the system works today}

### 2.2 Problem Statement
{From PRD - why we're building this}

### 2.3 Goals
{What success looks like}

### 2.4 Non-Goals
{What we're explicitly not solving}

---

## 3. Design Decisions

### 3.1 Decision: {Title}

**Status:** Accepted

**Context:** {Why this decision was needed}

**Options Considered:**
1. **Option A:** {description}
   - Pros: {list}
   - Cons: {list}
2. **Option B:** {description}
   - Pros: {list}
   - Cons: {list}

**Decision:** Option {X}

**Rationale:** {Why this option was chosen}

**Consequences:** {Trade-offs accepted}

---

{Repeat 3.1 pattern for each significant decision}

---

## 4. System Architecture

### 4.1 High-Level Architecture
{ASCII diagram or description of overall system structure}

### 4.2 Component Overview
{List of components and their responsibilities}

---

## 5. Component Design

### 5.1 {Component Name}

**Location:** `{file_path}`

**Responsibility:** {What this component does}

**Dependencies:**
- {Dependency 1}
- {Dependency 2}

**Public Interface:**
```{language}
{Interface definition}
```

**Internal Structure:**
{Key internal details}

**Error Handling:**
{How errors are handled}

---

{Repeat 5.1 pattern for each component}

---

## 6. Data Model

### 6.1 Entities

#### {Entity Name}
| Field | Type | Description |
|-------|------|-------------|
| {field} | {type} | {description} |

### 6.2 Relationships
{Entity relationships diagram or description}

### 6.3 Schema Changes
{New tables, altered tables, migrations needed}

---

## 7. API Design

### 7.1 Endpoints

#### {HTTP Method} {Path}

**Description:** {What this endpoint does}

**Request:**
```json
{request_schema}
```

**Response:**
```json
{response_schema}
```

**Errors:**
| Code | Description |
|------|-------------|
| {code} | {description} |

---

{Repeat 7.1 for each endpoint}

---

## 8. Flows

### 8.1 {Flow Name}

```
{ASCII diagram or step-by-step description}
```

**Steps:**
1. {Step 1}
2. {Step 2}

**Error Paths:**
- If {condition}: {action}

---

{Repeat 8.1 for each key flow}

---

## 9. Error Handling

### 9.1 Error Categories
| Category | Handling Strategy |
|----------|-------------------|
| {category} | {strategy} |

### 9.2 Recovery Procedures
{How the system recovers from failures}

---

## 10. Security Considerations

### 10.1 Authentication/Authorization
{How access is controlled}

### 10.2 Data Protection
{How sensitive data is protected}

### 10.3 Audit Logging
{What is logged and why}

---

## 11. Testing Strategy

### 11.1 Unit Tests
{What to unit test and approach}

### 11.2 Integration Tests
{Integration test scenarios}

### 11.3 Test Data
{Test data requirements}

---

## 12. Migration Strategy

### 12.1 Phases
{If applicable - phased rollout plan}

### 12.2 Rollback Plan
{How to rollback if issues arise}

### 12.3 Data Migration
{If applicable - how existing data is migrated}

---

## 13. Implementation Sequence

### Phase 1: {Name}
**Goal:** {What this phase accomplishes}
**Tasks:**
- [ ] {Task 1} - `{file_path}`
- [ ] {Task 2} - `{file_path}`

**Dependencies:** None / Requires Phase X

### Phase 2: {Name}
...

---

## 14. Risks and Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| {risk} | High/Medium/Low | High/Medium/Low | {mitigation} |

---

## Open Items

- [ ] {Open item if any}

---

## Appendix

### A. Glossary
| Term | Definition |
|------|------------|
| {term} | {definition} |

### B. References
- {Reference 1}
- {Reference 2}
```

---

## Rules

1. **No code changes** — This skill only produces documents
2. **PRD is mandatory** — Cannot proceed without a PRD
3. **Ask user for each discrepancy** — Use AskUserQuestion, don't auto-resolve
4. **Use kb-maintainer for document updates** — Don't edit PRD/Concept directly
5. **Deep exploration with code-explorer** — Use 2-3 agents in parallel for thorough understanding
6. **One question per message** — Keep interactions focused
7. **Human gates at key points** — Get explicit approval before major transitions
8. **Maintain traceability** — Use same title-slug as PRD for related documents
9. **Comprehensive output** — Architecture must cover all sections in template
10. **Update Linear task** — If Linear task provided, always update with document references
11. **Context-bound design** — Architecture design stays in skill, NOT delegated to code-architect
12. **V2 frontmatter** — Always use namespaced `author: skill::designing-architecture`

---

## Example Invocations

```
/designing-architecture
```
(Will prompt for input documents)

```
/designing-architecture based on Linear task PROD-35
```
(Will fetch task and extract document references)

```
/designing-architecture with PRD kb/requirements/20260120-requirements-3-role-ledger.md
```
(Will load PRD and ask about Concept)

```
/designing-architecture with PRD kb/requirements/user-auth.md and concept kb/concepts/user-auth-approach.md
```
(Will load both documents and proceed to gap analysis)
