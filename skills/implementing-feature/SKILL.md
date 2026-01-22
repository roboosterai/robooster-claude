---
name: implementing-feature
description: Implement features from Architecture documents with deep validation, test writing, and quality review. Stage 5 of agentic workflow pipeline.
user-invocable: true
---

# Implementing Feature

Implement features from Architecture documents and PRDs. This skill is Stage 5 of the agentic workflow: `brainstorming` → `conceptualizing-idea` → `specifying-concept` → `designing-architecture` → `implementing-feature`.

## Core Principles

- **Architecture-driven** — Architecture document is source of truth for implementation
- **Validate before building** — Verify architecture assumptions against codebase reality
- **Light alignment check** — Trust designing-architecture did its job; only flag serious discrepancies
- **Ask, don't assume** — When validation fails, ask user how to proceed
- **Comprehensive testing** — Every implementation includes test-writer and test-verifier
- **Human gates at key points** — Approval before implementation start and completion
- **One question per message** — Keep interactions focused

---

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

   **Smart inference:** If loading from an Architecture/PRD path, suggest project based on path:
   - `platro/platro-kb/architecture/...` → suggest Platro
   - `kb/architecture/...` → suggest Root

3. **Set session variables based on selection:**

   | Project      | `{KB_ROOT}`         | `{GITHUB_REPO}`                            |
   |--------------|---------------------|--------------------------------------------|
   | Platro       | `platro/platro-kb`  | `https://github.com/roboosterai/platro-kb` |
   | General/Root | `kb`                | `~`                                        |

4. **Confirm to user:**

   > Starting implementation session
   > - Date: {DATE}
   > - Project: {PROJECT}
   > - KB: {KB_ROOT}/

**Proceed when:** Date and project context established

→ Proceed to Phase 2

---

### Phase 2: Input Collection

**Goal:** Gather all input documents (Architecture required, PRD, Concept)

**Actions:**

1. **Ask user what inputs they have:**
   - "What documents do you have for this implementation?"

   Options:
   - Architecture file path
   - PRD file path (if not referenced in Architecture)
   - Linear task ID
   - Combination of above

2. **If Linear task provided:**
   - Fetch task details using task-manager agent
   - Extract references to Architecture/PRD from task description
   - Read referenced documents

3. **If Architecture missing:**
   - Redirect: "You need an architecture document first. Would you like to run `/designing-architecture` to create one?"
   - **DO NOT PROCEED without Architecture**

4. **Load Architecture:**
   - Read Architecture document
   - Extract PRD reference from "Related Documents" section
   - Load PRD

5. **Load PRD:**
   - Extract Concept reference (if exists)
   - Load Concept (optional)

6. **Display document summaries:**
   ```
   Documents Loaded:
   - Architecture: {title} - {scope summary}
   - PRD: {title} - {problem summary}
   - Concept: {title} (or "Not linked")
   - Linear Task: {identifier} - {title} (or "Not linked")
   ```

7. **Human Gate G1:**
   - "Documents loaded. Ready to proceed?"

**Proceed when:** User confirms ready to proceed

→ Proceed to Phase 3

---

### Phase 3: Document Review

**Goal:** Light sanity check that Architecture aligns with PRD

**Actions:**

1. **Quick comparison of Architecture decisions against PRD requirements:**
   - Verify Architecture covers all FRs
   - Check for obvious contradictions

2. **Only flag serious discrepancies:**
   - This is NOT a repeat of designing-architecture's Phase 3 gap analysis
   - Trust that designing-architecture did comprehensive analysis
   - Only flag issues that would break implementation

3. **If serious misalignment found:**
   - Ask user via AskUserQuestion:
     - "I found a discrepancy: [description]. How should we proceed?"

   Options:
   - **Fix via kb-maintainer** — Update documents to resolve discrepancy
   - **Proceed anyway** — Document deviation and continue
   - **Stop and redesign** — Go back to /designing-architecture

4. **If fixes needed via kb-maintainer:**

   ```
   Task(
     subagent_type: "kb-maintainer",
     prompt: "target_file: {KB_ROOT}/{document path}
              section: {section name}
              action_type: update
              content: {new/modified content}
              reason: Implementation alignment - {explanation}",
     description: "Update document for implementation alignment"
   )
   ```

5. **Human Gate G2:**
   - "Documents aligned. Ready to explore codebase?"

**Proceed when:** User confirms ready to explore

→ Proceed to Phase 4

---

### Phase 4: Codebase Exploration

**Goal:** Deep understanding via code-explorer agents

**Actions:**

1. **Launch 2-3 code-explorer agents in parallel** with different focuses:

   ```
   Task(
     subagent_type: "code-explorer",
     prompt: "Find features similar to [feature from Architecture] and trace
              through their implementation comprehensively. Focus on patterns,
              abstractions, and code organization. Return 5-10 key files to read.",
     description: "Explore similar features"
   )
   ```

   ```
   Task(
     subagent_type: "code-explorer",
     prompt: "Map the architecture and abstractions for [component area from
              Architecture]. Focus on extension points, interfaces, and conventions.
              Return 5-10 key files to read.",
     description: "Explore architecture patterns"
   )
   ```

   ```
   Task(
     subagent_type: "code-explorer",
     prompt: "Analyze integration points for [feature]. How do components
              communicate? What are the boundaries? Return 5-10 key files to read.",
     description: "Explore integration points"
   )
   ```

2. **Read key files identified by agents:**
   - Read all files returned by agents
   - Build deep understanding of patterns

3. **Identify services involved:**
   - From Architecture component file paths, identify which services will be modified
   - Common services: `platro-services`, `platro-hs-backend`, `platro-hs-control-center`, `platro-docs`

4. **Read CLAUDE.md for each service:**
   - Note service-specific conventions, patterns, and requirements
   - Flag if `platro-services` is involved (XML documentation phase needed)

5. **Summarize findings:**
   ```
   ## Codebase Exploration Summary

   ### Services Involved
   - {service 1}: {conventions noted}
   - {service 2}: {conventions noted}

   ### Key Patterns Found
   - {pattern 1}: {description}
   - {pattern 2}: {description}

   ### Integration Points
   - {integration point 1}
   - {integration point 2}

   ### XML Documentation Required: {Yes/No}
   ```

**Proceed when:** Codebase context understood

→ Proceed to Phase 5

---

### Phase 5: Architecture Validation

**Goal:** Verify architecture decisions against codebase reality

**Actions:**

1. **Check architecture assumptions:**
   - File paths correct/exist?
   - Suggested patterns match codebase conventions?
   - Extension points available as expected?
   - Any undocumented constraints invalidating decisions?

2. **For each discrepancy, ask user via AskUserQuestion:**
   - "Architecture assumed [X] but codebase shows [Y]. How should we proceed?"

   Options:
   - **(a) Update architecture via kb-maintainer and continue**
   - **(b) Proceed with documented deviation**
   - **(c) Stop and redirect to /designing-architecture**

3. **If updates needed via kb-maintainer:**

   ```
   Task(
     subagent_type: "kb-maintainer",
     prompt: "target_file: {KB_ROOT}/architecture/{architecture filename}
              section: {section name}
              action_type: update
              content: {corrected content}
              reason: Codebase validation - {explanation}",
     description: "Update architecture after validation"
   )
   ```

4. **Document any deviations:**
   - Note deviations for implementation report
   - Include reason and user approval

5. **Human Gate G3:**
   - "Architecture validated. Ready to continue?"

**Proceed when:** User confirms validation complete

→ Proceed to Phase 6

---

### Phase 6: Clarifying Questions

**CRITICAL:** DO NOT SKIP

**Goal:** Fill remaining gaps not covered by Architecture

**Actions:**

1. **Review codebase findings, Architecture, PRD**

2. **Identify underspecified aspects:**
   - Edge cases
   - Error handling details
   - Integration nuances
   - Performance expectations

3. **Present all questions to user in organized list:**
   ```
   ## Clarifying Questions

   ### Edge Cases
   1. What should happen when [X]?
   2. How should we handle [Y]?

   ### Error Handling
   3. What error message for [Z]?

   ### Integration
   4. Should [A] trigger [B]?
   ```

4. **Wait for answers before proceeding**

5. **If user says "whatever you think is best":**
   - Provide your recommendation
   - Get explicit confirmation

**Proceed when:** All questions answered

→ Proceed to Phase 7

---

### Phase 7: Implementation Planning

**Goal:** Review architecture, confirm implementation sequence

**Actions:**

1. **Review Architecture for implementation readiness:**
   - Component designs: File paths and interfaces
   - Data model: Schema changes
   - API design: Endpoints and contracts
   - Flows: Code paths
   - Error handling: Coverage

2. **Identify implementation gaps:**
   - Not architecture gaps (those were handled in Phase 5)
   - Implementation details not fully specified
   - Sequence dependencies

3. **For each gap, propose resolution:**
   - "For [gap], I propose [approach] because [reason]"
   - Get user approval on resolutions

4. **Present implementation sequence from Architecture Section 13:**
   ```
   ## Implementation Sequence

   ### Phase 1: {name from Architecture}
   - Creates: {file paths}
   - Modifies: {file paths}
   - Dependencies: {what must exist first}

   ### Phase 2: {name from Architecture}
   - Creates: {file paths}
   - Modifies: {file paths}
   - Dependencies: Phase 1

   ...
   ```

5. **Map phases to specific files with dependencies**

6. **Human Gate G4:**
   - "Implementation plan approved. Ready to begin?"

**DO NOT START IMPLEMENTATION WITHOUT APPROVAL**

**Proceed when:** User approves implementation plan

→ Proceed to Phase 8

---

### Phase 8: Implementation

**Goal:** Build the feature

**Actions:**

1. **Read all relevant files** identified in previous phases

2. **Implement following Architecture document:**
   - Follow the implementation sequence
   - Respect component designs
   - Match data model specifications
   - Implement API contracts as specified

3. **Follow codebase conventions strictly:**
   - Use patterns identified in Phase 4
   - Respect service-specific conventions from CLAUDE.md
   - Match existing code style

4. **Write clean, well-documented code:**
   - Clear naming
   - Appropriate comments for complex logic
   - Proper error handling

5. **Update todos as progress is made:**
   - Mark implementation sub-tasks complete
   - Add any newly discovered sub-tasks

**Proceed when:** Implementation complete

→ Proceed to Phase 9

---

### Phase 9: Test Writing

**Goal:** Generate comprehensive tests via test-writer

**Actions:**

1. **Launch test-writer agent with context:**

   ```
   Task(
     subagent_type: "test-writer",
     prompt: "Write comprehensive tests for [feature].

              Feature Description (from PRD):
              {PRD requirements summary}

              Implemented Files:
              {list of files from Phase 8}

              Testing Strategy (from Architecture Section 11):
              {testing strategy}

              Existing Test Patterns:
              {patterns identified in Phase 4}

              Write: unit tests, integration tests, edge case coverage, error path testing.",
     description: "Generate tests for implementation"
   )
   ```

2. **Agent generates:**
   - Unit tests for all new functions/methods
   - Integration tests for component interactions
   - Edge case coverage (null, empty, boundaries, errors)
   - Error path testing

3. **Human Gate G5:**
   - Present generated tests to user for review
   - "Tests generated. Ready for verification?"

4. **Address feedback before proceeding**

**Proceed when:** User approves tests

→ Proceed to Phase 10

---

### Phase 10: Test Verification

**Goal:** Ensure tests are meaningful via test-verifier

**Actions:**

1. **Run all tests to ensure they pass**

2. **Launch test-verifier agent:**

   ```
   Task(
     subagent_type: "test-verifier",
     prompt: "Verify test quality for [feature].

              Test Files:
              {list of test files}

              Implementation Files:
              {list of implementation files}

              Targets:
              - Mutation score: >80%
              - Branch coverage: >70%
              - Red flag detection

              Run mutation testing and coverage analysis.",
     description: "Verify test quality"
   )
   ```

3. **Present verification report:**
   ```
   ## Test Verification Results

   - Mutation score: {score}%
   - Branch coverage: {coverage}%
   - Red flags: {count or "None"}

   ### Issues Found
   - {issue 1}
   - {issue 2}

   ### Recommendations
   - {recommendation 1}
   - {recommendation 2}
   ```

4. **Human Gate G6 (soft block if verification fails):**
   - Warn user with specific issues
   - "Tests verified. Proceed with any overrides?"
   - Allow proceeding with explicit user approval
   - Document any override in implementation report

**Proceed when:** User approves verification results

→ Proceed to Phase 11

---

### Phase 11: XML Documentation

**CONDITIONAL:** Only if `platro-services` is involved

**Goal:** Ensure XML documentation compliance via parallel xml-comments-writer agents

**Actions:**

1. **Run documentation linter and capture output:**
   ```bash
   cd platro/platro-services && make docs-lint-log 2>&1
   ```

2. **Parse lint output for file paths with errors:**
   - Extract unique file paths from error lines
   - Count errors per file
   - Skip files outside scope (tests, migrations, obj)

3. **Batch files using hybrid strategy:**
   - Group files by directory first
   - Split large directories into batches of 10-15 files
   - Keep small directories together if under limit
   - Example: `src/Ledger/` has 20 files → split into 2 batches

4. **Spawn parallel xml-comments-writer agents:**

   For each batch:

   ```
   Task(
     subagent_type: "xml-comments-writer",
     prompt: "Add XML documentation to these C# files in platro-services:

              Files:
              - {file1.cs}
              - {file2.cs}
              - ...

              Instructions:
              1. Read each file
              2. Add XML docs to all undocumented public/protected members
              3. Use explicit tags only — NO <inheritdoc/>
              4. Follow patterns from kb/guides/xml-documentation.md
              5. Verify with: cd platro/platro-services && make docs-lint

              Report files documented and final lint status.",
     description: "Document batch: {directory/batch-name}"
   )
   ```

   **CRITICAL:** Launch ALL batch agents in parallel (single message with multiple Task calls)

5. **Wait for all agents and aggregate reports:**
   - Collect results from all parallel agents
   - Summarize: files documented, remaining errors

6. **Re-run lint to verify:**
   ```bash
   cd platro/platro-services && make docs-lint 2>&1 | head -50
   ```

7. **Iteration loop (max 3 rounds):**
   - If errors remain AND iteration < 3:
     - Parse remaining errors
     - Re-batch affected files
     - Spawn new parallel agents
     - Increment iteration counter
   - If errors remain AND iteration >= 3:
     - Proceed to Human Gate

8. **Human Gate (if errors persist after 3 iterations):**
   - Present remaining errors to user
   - "XML documentation has {N} errors after 3 rounds. How to proceed?"

   Options:
   - **Fix manually** — I'll fix remaining errors directly
   - **Proceed anyway** — Continue with lint errors (document deviation)
   - **Stop** — Halt implementation for investigation

**DO NOT PROCEED until `make docs-lint` reports zero errors OR user approves override**

**Reference:** Full guide at `kb/guides/xml-documentation.md`

**Proceed when:** Zero lint errors, OR user approves override after max iterations

→ Proceed to Phase 12

---

### Phase 12: Quality Review

**Goal:** Ensure code quality via code-reviewer

**Actions:**

1. **Launch 3 code-reviewer agents in parallel:**

   ```
   Task(
     subagent_type: "code-reviewer",
     prompt: "Review [files] for simplicity, DRY, and elegance.
              Focus on: unnecessary complexity, code duplication,
              readability issues, overly clever code.",
     description: "Review for simplicity"
   )
   ```

   ```
   Task(
     subagent_type: "code-reviewer",
     prompt: "Review [files] for bugs and functional correctness.
              Focus on: logic errors, edge cases, null handling,
              error paths, race conditions.",
     description: "Review for bugs"
   )
   ```

   ```
   Task(
     subagent_type: "code-reviewer",
     prompt: "Review [files] for project conventions and abstractions.
              Focus on: naming conventions, architecture patterns,
              proper use of existing abstractions, consistency.",
     description: "Review for conventions"
   )
   ```

2. **Consolidate findings:**
   - Identify highest severity issues
   - Group by category

3. **If platro-services involved:**
   - Re-run `make docs-lint` to verify XML documentation still clean

4. **Human Gate G7:**
   - Present findings to user
   - "Quality review complete. How to address findings?"

   Options:
   - **Fix now** — Address issues before proceeding
   - **Fix later** — Create follow-up tasks
   - **Proceed as-is** — Accept current state

5. **Address issues based on user decision**

**Proceed when:** User decides how to handle findings

→ Proceed to Phase 13

---

### Phase 13: Linear Integration

**Goal:** Create or link Linear task via task-manager

**Actions:**

1. **Ask about Linear task via AskUserQuestion:**
   - "Would you like to create or link a Linear task?"

   Options:
   - **Create new task** — Create a new Linear task for this implementation
   - **Link to existing task** — Associate with an existing Linear task
   - **No task needed** — Skip Linear integration

2. **If "Create new task":**

   ```
   Task(
     subagent_type: "task-manager",
     prompt: "Create Linear task for implementation: {title}.
              Description: {summary of what was implemented}.
              KB context: {kb_identifier}={KB_ROOT}, github_repo={GITHUB_REPO}
              Documents:
              - Implementation: {KB_ROOT}/implementations/{filename}
              - Architecture: {KB_ROOT}/architecture/{arch_filename}
              Set status to 'to-review'.",
     description: "Create Linear task for implementation"
   )
   ```

   - Extract task ID from result
   - Update implementation document frontmatter

3. **If "Link to existing":**
   - Ask for Linear task ID
   - Validate format (e.g., PLT-123)

   ```
   Task(
     subagent_type: "task-manager",
     prompt: "Update task {ID}:
              KB context: {kb_identifier}={KB_ROOT}, github_repo={GITHUB_REPO}
              Attach implementation doc: {KB_ROOT}/implementations/{filename}
              Change status to 'to-review'.",
     description: "Update Linear task"
   )
   ```

4. **If "No task needed":**
   - Set `linear: ~` in frontmatter

**Proceed when:** Linear decision made

→ Proceed to Phase 14

---

### Phase 14: Finalize & Save

**Goal:** Save implementation document and summarize

**Actions:**

1. **Generate filename:**
   - Format: `YYYYMMDD-implementation-{title-slug}.md`
   - Title slug: lowercase, hyphenated (e.g., "3-Role Ledger" → "3-role-ledger")
   - Example: `20260121-implementation-3-role-ledger.md`

2. **Compose implementation document** using Output Template below

3. **Save to `{KB_ROOT}/implementations/`:**
   ```bash
   mkdir -p {KB_ROOT}/implementations
   ```
   - Write the file

4. **If Linear task:**
   - Update task with implementation document link (if not done in Phase 13)

5. **Present summary:**
   ```
   ## Implementation Complete!

   **File:** {KB_ROOT}/implementations/{filename}
   **Project:** {PROJECT}
   **KB:** {KB_ROOT}/
   **Linear:** {task ID or "Not linked"}

   ### What Was Built
   {Brief description}

   ### Key Decisions
   - {decision 1}
   - {decision 2}

   ### Files Modified
   - {file 1}: {changes}
   - {file 2}: {changes}

   ### Testing Results
   - Mutation score: {score}%
   - Branch coverage: {coverage}%

   ### Next Steps
   1. Review the implementation document
   2. Create PR for code review
   3. When ready, proceed to /reviewing-implementation
   ```

**Session complete.**

---

## Human Gates

| Gate | Phase | Question | Pass | Fail |
|------|-------|----------|------|------|
| G1 | Phase 2 | "Documents loaded. Ready to proceed?" | Continue | Provide missing inputs |
| G2 | Phase 3 | "Documents aligned. Ready to explore codebase?" | Continue | Fix discrepancies |
| G3 | Phase 5 | "Architecture validated. Ready to continue?" | Continue | Update/stop |
| G4 | Phase 7 | "Implementation plan approved. Ready to begin?" | Continue | Iterate |
| G5 | Phase 9 | "Tests generated. Ready for verification?" | Continue | Iterate |
| G6 | Phase 10 | "Tests verified. Proceed with any overrides?" | Continue | Fix tests |
| G7 | Phase 12 | "Quality review complete. How to address findings?" | Fix/defer/proceed | N/A |
| G8 | Phase 13 | "Linear task preference?" | Create/Link/Skip | N/A |

---

## Output Template

### File Naming

`{KB_ROOT}/implementations/YYYYMMDD-implementation-{title-slug}.md`

Example: `20260121-implementation-3-role-ledger.md`

### Frontmatter

```yaml
---
title: "Implementation: {Feature Name}"
description: "{1-2 sentence summary of what was implemented (max 300 chars)}"
type: implementation
status: draft
version: "1.0.0"
created: {YYYY-MM-DD}
updated: {YYYY-MM-DD}
author: skill::implementing-feature
modified_by: skill::implementing-feature
linear: {TASK-ID or ~}
---
```

### Document Structure

```markdown
# Implementation: {Feature Name}

## Overview

### What Was Built

{Brief description of the implemented feature}

### Date

{YYYY-MM-DD}

### Source Documents

- Architecture: [{filename}]({KB_ROOT}/architecture/{filename})
- PRD: [{filename}]({KB_ROOT}/requirements/{filename})
- Concept: [{filename}]({KB_ROOT}/concepts/{filename}) (if applicable)
- Linear: {TASK-ID or "Not linked"}

---

## Approach

### Architecture Approach

{Summary of architecture approach and why it was chosen}

### Implementation Decisions

{Decisions made during implementation distinct from architecture}

| Decision | Rationale |
|----------|-----------|
| {decision} | {why} |

### Deviations from Architecture

{Any deviations and reasons, or "None"}

---

## Changes Made

### Files Created

| File | Purpose |
|------|---------|
| {path} | {description} |

### Files Modified

| File | Changes |
|------|---------|
| {path} | {description} |

### Services Affected

- {service 1}: {changes summary}
- {service 2}: {changes summary}

---

## Testing

### Test Coverage

- Unit tests: {count} tests covering {areas}
- Integration tests: {count} tests covering {areas}

### Verification Results

- Mutation score: {score}%
- Branch coverage: {coverage}%
- Red flags: {count or "None"}

### Test Overrides

{If any verification issues were overridden, document here}

---

## Quality Review

### Findings Addressed

{Issues fixed during quality review}

### Findings Deferred

{Issues deferred for future, if any}

---

## Future Considerations

### Known Limitations

{Any limitations of the current implementation}

### Follow-up Work

{Suggested follow-up tasks}

---

## References

- Architecture: [{filename}]({KB_ROOT}/architecture/{filename})
- PRD: [{filename}]({KB_ROOT}/requirements/{filename})
- Concept: [{filename}]({KB_ROOT}/concepts/{filename})
- Research: [{filename}]({KB_ROOT}/research/{filename}) (if applicable)
```

---

## Rules

1. **Architecture is mandatory** — Cannot proceed without architecture document
2. **Light alignment check** — Trust designing-architecture; only flag serious discrepancies
3. **Ask user for validation failures** — When architecture doesn't match codebase, ask how to proceed
4. **Use kb-maintainer for document updates** — Don't edit documents directly
5. **Use code-explorer for codebase understanding** — 2-3 parallel agents
6. **Comprehensive testing** — Always run test-writer and test-verifier
7. **Human gates before implementation** — Get explicit approval
8. **Document deviations** — Any deviations from architecture must be documented
9. **Update Linear task** — If Linear provided, update with document links
10. **V2 frontmatter** — Use `author: skill::implementing-feature`
11. **No architecture redesign in this skill** — If architecture needs major changes, redirect to /designing-architecture
12. **One question per message** — Keep interactions focused

---

## Example Invocations

```
/implementing-feature
```
(Will prompt for input documents)

```
/implementing-feature based on Linear task PROD-35
```
(Will fetch task and extract document references)

```
/implementing-feature with architecture kb/architecture/20260120-architecture-3-role-ledger.md
```
(Will load architecture and extract PRD/Concept references)

```
/implementing-feature with architecture kb/architecture/user-auth.md and PRD kb/requirements/user-auth.md
```
(Will load both documents directly)
