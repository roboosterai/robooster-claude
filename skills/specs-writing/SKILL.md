---
name: specs-writing
description: Transform a polished concept document into a comprehensive, implementation-ready Feature Spec. Analyzes the concept thoroughly, designs the technical approach, decomposes into tasks, and verifies full coverage. The output is refined through iteration in vanilla Claude Code sessions.
user-invocable: true
---

# Specs Writing

Transform a concept document into an implementation-ready Feature Spec. The skill thoroughly analyzes the concept, designs the technical approach, decomposes work into ordered tasks, and verifies that every functional area is covered. The resulting document is comprehensive — not a scaffold — but the user iterates on it in follow-up sessions to refine decisions and polish detail.

## Workflow

Execute phases in order. Use `AskUserQuestion` for all user interaction.

---

### Phase 1: Initialize

**Goal:** Establish session date and project context

**Actions:**

1. **Session date:** !`date +%Y-%m-%d`

2. **Determine project context using AskUserQuestion:**

   **Question:** "Which project is this work for?"

   **Options:**

   | Option           | Description                                              |
   |------------------|----------------------------------------------------------|
   | **Platro**       | Platro payment platform — saves to `platro/platro-kb/`   |
   | **General/Root** | Cross-project or general work — saves to root `kb/`      |

3. **Set session variables based on selection:**

   | Project      | `{KB_ROOT}`         | `{GITHUB_REPO}`                            |
   |--------------|---------------------|--------------------------------------------|
   | Platro       | `platro/platro-kb`  | `https://github.com/roboosterai/platro-kb` |
   | General/Root | `kb`                | `~`                                        |

4. **Confirm to user:**

   > Starting specs writing session
   > - Date: {DATE}
   > - Project: {PROJECT}
   > - KB: {KB_ROOT}/

**Proceed when:** Date and project context established

---

### Phase 2: Analyze

**Goal:** Thoroughly read the concept document and explore the codebase. Extract every functional area, entity, flow, and constraint.

**Actions:**

1. **Locate concept document:**
   - If args contain a file path — use it
   - Otherwise — list recent concepts from `{KB_ROOT}/concepts/` and ask user to select

2. **Read the concept document end-to-end.** Extract and catalog:
   - **Functional areas** — distinct capabilities or behaviors described
   - **Entities / models** — data structures, domain objects
   - **Flows** — user journeys, system sequences, state transitions
   - **Constraints** — mentioned limitations, non-functional requirements
   - **Dependencies** — external systems, services, libraries referenced
   - **Open questions** — unresolved items from the concept
   - **Implementation patterns** — algorithms, pseudocode, step-by-step logic from concept
   - **Data structures** — exact field names, types, JSON/code examples
   - **Validation rules** — input constraints, error conditions, edge cases
   - **Calculation formulas** — fee calculations, balance derivations, business logic

3. **Read project CLAUDE.md** for conventions, architecture, and patterns.

4. **Explore the codebase** to understand what exists:
   ```
   Task(
     subagent_type: "robooster-claude:code-explorer",
     prompt: "Explore the codebase focusing on: [areas relevant to concept].

              Find and return structured findings:
              - Key Files: 5-10 most relevant files with file:line references
              - Patterns Found: existing patterns, naming conventions, similar features
              - Architecture Insights: layer structure, abstractions, how new feature would fit
              - Integration Points: extension mechanisms, how components communicate

              Also identify: test patterns, build/test commands from CLAUDE.md or package files.",
     description: "Deep codebase analysis for spec"
   )
   ```

5. **Present extraction summary:**

   > ## Concept Analysis
   >
   > **Concept:** [{title}]({path})
   >
   > ### Functional Areas Extracted
   >
   > | # | Area | Description | Concept Section |
   > |---|------|-------------|-----------------|
   > | 1 | {area} | {what it covers} | {section name} |
   > | 2 | ... | ... | ... |
   >
   > ### Entities / Models
   > - {Entity}: {purpose}
   >
   > ### Key Flows
   > - {Flow}: {description}
   >
   > ### Constraints from Concept
   > - {Constraint}
   >
   > ### Codebase Findings
   >
   > **Key Files:**
   > | File | Line | Relevance |
   > |------|------|-----------|
   > | {file:line} | {lines} | {why relevant} |
   >
   > **Patterns Found:**
   > - {Pattern}: {description}
   >
   > **Architecture Insights:**
   > - {Insight}
   >
   > **Integration Points:**
   > - {Point}: {how to extend}
   >
   > ### Concept Open Questions (carried forward)
   > - {Question}
   >
   > ### Implementation Patterns
   > | Pattern | Steps | Used By |
   > |---------|-------|---------|
   > | {name} | {brief pseudocode} | {functional area} |
   >
   > ### Data Structures
   > | Structure | Fields | Example |
   > |-----------|--------|---------|
   > | {name} | {key fields with types} | {brief JSON} |
   >
   > ### Validation Rules
   > | Rule | Condition | Behavior |
   > |------|-----------|----------|
   > | {name} | {when X} | {reject/error} |

   No gate here — this is informational. The user sees what was extracted and can correct omissions inline before Phase 3.

**Proceed when:** Extraction presented to user

---

### Phase 3: Design

**Goal:** Propose the technical approach — how the concept maps to implementation in the existing codebase.

**Actions:**

1. **Synthesize concept + codebase findings** into a technical approach:
   - How do the concept's functional areas map to the existing architecture?
   - What new components/modules/files are needed?
   - What existing components need modification?
   - What key design decisions must be made?

2. **Present approach with trade-offs:**

   For each design decision where alternatives exist:
   - Describe the options
   - Recommend one with reasoning
   - Note trade-offs

3. **Include architecture diagram:**
   - ASCII diagram showing how new components fit into existing architecture
   - Show data flows between components

4. **Iterate with user:**
   - User may challenge, redirect, or refine design decisions
   - Respond with updated reasoning — not just acknowledgment
   - Introduce new angles or considerations as they emerge

5. **Converge on approach summary:**

   > ## Approach Summary
   >
   > **Architecture:**
   > ```
   > [ASCII diagram]
   > ```
   >
   > **Key Design Decisions:**
   > - {Decision 1}: {chosen approach} — {why}
   > - {Decision 2}: {chosen approach} — {why}
   >
   > **New components:** {list}
   > **Modified components:** {list}

**Gate G1:** "Is this technical approach right? Ready to decompose into tasks?"
- Pass: proceed to Phase 4
- Fail: continue iterating on design

---

### Phase 4: Decompose

**Goal:** Break the approved approach into ordered implementation tasks with acceptance criteria.

**Actions:**

1. **Propose task breakdown** based on the approved approach and extracted functional areas:

   Heuristics for task boundaries:
   - Each distinct user flow or functional area = potential task
   - Each entity/model that can exist independently = potential task boundary
   - Dependencies between flows determine ordering
   - A task should be implementable in one Claude Code session

   **Ordering constraint:**
   - Perform topological sort on tasks based on dependencies
   - Task N may ONLY depend on Tasks 1 through N-1
   - Tasks with no dependencies get lowest numbers
   - When multiple valid orderings exist, prefer grouping related work

   Implementation detail heuristics:
   - If concept has pseudocode for this task's logic → include or reference §8
   - If concept has data structure definitions → include types and example
   - If concept has validation examples → extract one concrete example per task
   - Goal: Each task implementable WITHOUT returning to concept document

2. **Present proposed tasks:**

   Before presenting, validate that no task depends on a higher-numbered task. If violated, renumber.

   > ## Proposed Tasks
   >
   > ### Task 1: {Name}
   > - **Goal:** {what this delivers end-to-end}
   > - **Functional areas covered:** {from Phase 2 extraction}
   > - **Acceptance criteria:**
   >   - [ ] {Criterion 1}
   >   - [ ] {Criterion 2}
   > - **Key files:** {expected new/modified files}
   > - **Dependencies:** None
   > - **Status:** Pending
   >
   > #### Implementation Notes
   > - **Data structures:** {structures this task creates/uses, or "See §8.1"}
   > - **Algorithm:** {brief pseudocode or "See §8.2.N"}
   > - **Validation:** {task-specific rules}
   > - **Example:** {input → expected output, if applicable}
   >
   > ---
   >
   > ### Task 2: {Name}
   > - **Goal:** ...
   > - **Functional areas covered:** ...
   > - **Dependencies:** Requires Task 1
   > - **Status:** Pending
   >
   > #### Implementation Notes
   > - **Data structures:** {...}
   > - **Algorithm:** {...}
   > - **Validation:** {...}
   > - **Example:** {...}
   >
   > ...

3. **Iterate with user:**
   - User may merge, split, reorder, or adjust tasks
   - Update acceptance criteria as discussed
   - Ensure every functional area from Phase 2 maps to at least one task

**Gate G2:** "Is this task breakdown right? Ready to verify coverage?"
- Pass: proceed to Phase 5
- Fail: continue adjusting tasks

---

### Phase 5: Verify

**Goal:** Verify that the spec comprehensively covers the concept. Flag gaps and inconsistencies.

**Actions:**

1. **Coverage matrix** — map every functional area from Phase 2 to tasks:

   > ## Coverage Matrix
   >
   > | Functional Area | Task | Status |
   > |-----------------|------|--------|
   > | {Area 1} | Task 1 | Covered |
   > | {Area 2} | Task 2, Task 3 | Covered |
   > | {Area 3} | — | **GAP** |

2. **Consistency check:**
   - Do any tasks contradict the approved approach from Phase 3?
   - Do any tasks have conflicting acceptance criteria?
   - Are dependencies circular or missing?

3. **Boundary check:**
   - Does anything in tasks go beyond what the concept describes?
   - Are there concept constraints not reflected in task criteria?

4. **Classify gaps:**
   - **Spec gap** — the concept covers it but the spec doesn't → needs fix
   - **Concept gap** — the concept doesn't cover it either → goes to Open Questions

5. **Present verification results:**

   > ## Verification Results
   >
   > **Coverage:** {N}/{M} functional areas covered
   >
   > **Gaps found:**
   > - {Gap}: {classification} — {recommendation}
   >
   > **Inconsistencies found:**
   > - {Issue}: {description}
   >
   > **Verdict:** {All clear / Needs revision}

**Gate G3:** "Are you satisfied with coverage and consistency?"
- Pass: proceed to Phase 6
- Fail: **loop back to Phase 3** (Design) to address gaps, then re-decompose and re-verify

**Loop limit:** Suggest max 3 loops. After 3, recommend saving current state and iterating in a follow-up session.

---

### Phase 6: Save

**Goal:** Compose the Feature Spec document and save it

**Actions:**

1. **Generate filename:**
   - Pattern: `YYYYMMDD-spec-{title-slug}.md`

2. **Compose the Feature Spec document** using the Output Template below:
   - Fill all 7 sections from the work done in Phases 2-5
   - **Overview** — from concept summary + approach
   - **Approach** — from Phase 3 (design decisions, architecture diagram, component changes)
   - **Tasks** — from Phase 4 (ordered tasks with acceptance criteria, key files, dependencies)
   - **Boundaries** — synthesized from concept constraints + codebase conventions + decisions made during design
   - **Codebase Context** — from Phase 2 exploration (project structure, conventions, build/test commands, CLAUDE.md excerpts)
   - **Testing Strategy** — from codebase test patterns + per-task test expectations
   - **Open Questions** — concept gaps identified in Phase 5. Must be empty before implementation starts.
   - Mark areas that need iteration with `<!-- ITERATE: [what to refine] -->`

3. **Save to `{KB_ROOT}/specs/`**

4. **Present summary:**

   ```markdown
   ## Feature Spec Created

   **Title:** {title}
   **File:** [{filename}]({KB_ROOT}/specs/{filename})
   **Project:** {PROJECT}
   **Concept:** [{concept filename}]({concept path})

   ### Coverage
   {N}/{M} functional areas covered. {gaps if any}

   ### Tasks
   1. {Task 1 name}
   2. {Task 2 name}
   ...

   ### Open Questions ({count})
   - {Question 1}

   ### Iteration prompts

   To refine this spec in a follow-up session, try:
   - "Read {filepath} and refine the Approach section for [topic]"
   - "Read {filepath} and add acceptance criteria for [area]"
   - "Read {filepath} and challenge the task boundaries"
   - "Read {filepath} and resolve Open Question: [question]"
   ```

**Session complete.**

---

## Human Gates

| Gate | Phase | Question | Pass | Fail |
|------|-------|----------|------|------|
| G1 | Phase 3 | "Is this technical approach right?" | Continue to Decompose | Iterate on design |
| G2 | Phase 4 | "Is this task breakdown right?" | Continue to Verify | Adjust tasks |
| G3 | Phase 5 | "Satisfied with coverage?" | Continue to Save | Loop back to Phase 3 |

---

## Output Format

### Frontmatter

```yaml
---
title: "Feature Spec: {Title}"
description: "{1-2 sentence summary of what is being built and how (max 300 chars)}"
type: spec
status: draft
version: "1.0.0"
created: {YYYY-MM-DD}
updated: {YYYY-MM-DD}
author: skill::specs-writing
modified_by: skill::specs-writing
concept: "{path to concept document}"
linear: ~
---
```

### Document Template

```markdown
# Feature Spec: {Name}

## 1. Overview

Brief summary of what we're building and why.

- **Concept:** [{filename}]({path})

## 2. Approach

Technical approach and key design decisions.
How the concept maps to implementation in the existing codebase.

### Architecture

{ASCII diagram showing components and data flows}

### Design Decisions

| Decision | Chosen Approach | Rationale | Alternatives Considered |
|----------|----------------|-----------|------------------------|
| {Decision} | {Approach} | {Why} | {Others} |

### Components

**New:**
- {Component}: {purpose}

**Modified:**
- {Component}: {what changes}

## 3. Tasks

Implementation tasks, ordered by dependency.

### Task 1: {Name}

- **Goal:** What this task delivers end-to-end
- **Acceptance Criteria:**
  - [ ] Criterion 1
  - [ ] Criterion 2
- **Key files:** Expected new/modified files
- **Dependencies:** None / Requires Task N
- **Status:** Pending

---

### Task 2: {Name}
...

## 4. Boundaries

### In Scope
- {What this feature covers}

### Out of Scope
- {What this feature does NOT cover}

### Protected Elements (DO NOT CHANGE)
- {Files, APIs, behaviors that must not be modified}

### Constraints
- {Technical or business constraints}

## 5. Codebase Context

Project structure, conventions, and patterns to follow.

### Project Structure
{Relevant directory layout}

### Conventions
- {Convention from CLAUDE.md or codebase patterns}

### Build & Test Commands
- Build: {command}
- Test: {command}
- Lint: {command}

## 6. Testing Strategy

### Per-Task Testing
| Task | What to Test | Test Type |
|------|-------------|-----------|
| Task 1 | {what} | {unit/integration/e2e} |

### Test Patterns
{Existing test patterns in the codebase to follow}

## 7. Open Questions

Must be empty before implementation starts.

- [ ] {Question — classify as spec gap or concept gap}

## 8. Implementation Reference

Detailed implementation context extracted from concept. Tasks reference this section.

### 8.1 Data Structures

#### {StructureName}

| Field | Type | Description |
|-------|------|-------------|
| {field} | {type} | {purpose} |

**Example:**
```json
{example from concept}
```

### 8.2 Algorithms

#### 8.2.1 {Algorithm Name}

**Used by:** Task {N}

**Steps:**
1. {step}
2. {step}
3. {step}

**Edge cases:**
- {case}: {handling}

### 8.3 Validation Rules

| Rule | Condition | Behavior | Task |
|------|-----------|----------|------|
| {name} | {when X} | {reject/error} | Task {N} |

### 8.4 Entry Patterns (if applicable)

#### {Pattern Name}

| # | Account | Type | Amount | Source |
|---|---------|------|--------|--------|
| 1 | {account} | {Debit/Credit} | {amount} | {source} |

**Balance check:** {formula}
```

---

## Rules

1. **Comprehensive, not scaffold** — Cover every functional area from the concept. Do not skip topics.
2. **No code changes** — This skill only produces documents
3. **Verify before saving** — Always run the coverage matrix. Never skip Phase 5.
4. **Loop on failure** — If verification finds gaps, loop back to Phase 3, not Phase 2. The concept hasn't changed.
5. **Classify gaps** — Distinguish "spec gap" (fixable) from "concept gap" (Open Question)
6. **Frontmatter required** — Every output file must have valid frontmatter
7. **One question per message** — Keep interactions focused
8. **Respect all three gates** — Do not skip human approval checkpoints
9. **Deep codebase exploration is mandatory** — Always use code-explorer in Phase 2. A spec without thorough codebase analysis is incomplete.
10. **Open Questions must be empty** — Before implementation starts, not before saving. Flag them, save, iterate later.
