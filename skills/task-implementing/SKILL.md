---
name: task-implementing
description: Implement one spec task per session. Reads a Feature Spec, picks a task, implements it with tests and review, and produces a handoff document for the next session.
user-invocable: true
---

# Task Implementing

Implement one task from a Feature Spec per session. Each session picks one task, implements it, tests it, reviews it, and writes a handoff for the next session.

## Core Principles

- **One task per session** — Focus delivers quality
- **Spec is source of truth** — Feature Spec defines what to build
- **Handoff continuity** — Each session leaves context for the next
- **Human gates at key points** — 3 approval checkpoints
- **Ask, don't assume** — Use AskUserQuestion for all interaction
- **One question per message** — Keep interactions focused

---

## Workflow

Execute phases in order. Use `AskUserQuestion` for all user interaction.

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

3. **Set session variables based on selection:**

   | Project      | `{KB_ROOT}`         | `{GITHUB_REPO}`                            |
   |--------------|---------------------|--------------------------------------------|
   | Platro       | `platro/platro-kb`  | `https://github.com/roboosterai/platro-kb` |
   | General/Root | `kb`                | `~`                                        |

4. **Parse arguments:**
   - `--spec= @{path}` or `--spec={path}` — Feature Spec file path. Note the space before `@` — required for autocomplete to work. Strip leading `@` and `./` from path when parsing.
   - `--task={N}` — Task number to implement
   - `--review= @{path}` or `--review={path}` — Review findings file (optional). Same parsing rules.
   - `--muttests={all|new|none}` — Mutation testing scope (default: `new`)
     - `all`: Full codebase mutation testing
     - `new`: Scope to implementation files only (recommended)
     - `none`: Skip mutation testing entirely
   - If not provided, will prompt in Phase 2

5. **Confirm to user:**

   > Starting task implementation session
   > - Date: {DATE}
   > - Project: {PROJECT}
   > - KB: {KB_ROOT}/

**Proceed when:** Date and project context established

→ Proceed to Phase 2

---

### Phase 2: Understand

**Goal:** Read the Feature Spec, extract the target task, and build full context

**Actions:**

1. **Locate Feature Spec:**
   - If `--spec` arg provided — use it
   - Otherwise — list files from `{KB_ROOT}/specs/` and ask user to select

2. **Read the Feature Spec end-to-end.** Extract:
   - **All tasks** — names, goals, acceptance criteria, key files, dependencies
   - **Boundaries** — in scope, out of scope, protected elements, constraints
   - **Codebase Context** — project structure, conventions, build/test commands
   - **Testing Strategy** — per-task testing, test patterns
   - **Approach** — architecture, design decisions, components
   - **Implementation Reference (§8)** — data structures, algorithms, validation rules

3. **Extract testing requirements for target task:**
   - Locate the **Per-Task Testing** table in Section 6 (Testing Strategy)
   - Find the row for Task N
   - Extract:
     - **What to Test:** specific test coverage required
     - **Test Type:** Unit, Integration, or Integration (emulator)
   - Locate any **Test Patterns** in Section 6 that apply to this task type
   - Store these for Phase 5 test-writer prompt

4. **Select target task:**
   - If `--task` arg provided — use it
   - Otherwise — present task list and ask user to select:

   **Question:** "Which task do you want to implement?"

   **Options:** (from spec's task list, showing name + goal)

5. **If target task > 1, read previous handoff:**
   - Read the previous task's section in the spec file. If it contains a `**Handoff:**` link, read that file.
   - Extract: what was built, decisions made, deviations, notes for this task

6. **If `--review` arg provided, read review findings file:**
   - Extract findings with priorities
   - These become additional acceptance criteria for this session

7. **Read project CLAUDE.md** for the services involved

8. **Explore codebase if needed:**

   If key files from the task don't exist yet or codebase context is thin:

   ```
   Task(
     subagent_type: "robooster-claude:code-explorer",
     prompt: "Explore the codebase focusing on: [areas from task key files and spec codebase context].
              Find: existing patterns, similar features, extension points, relevant file structure.
              Return detailed findings.",
     description: "Explore codebase for task"
   )
   ```

9. **Ask clarifying questions** via AskUserQuestion if gaps exist between the spec and what you need to implement

10. **Present task summary:**

    > ## Task {N}: {Name}
    >
    > **Goal:** {goal}
    >
    > **Acceptance Criteria:**
    > - {criterion 1}
    > - {criterion 2}
    >
    > **Implementation Context:**
    > - Data structures: {from spec §8.1}
    > - Algorithm: {from spec §8.2, brief}
    > - Validation: {rules that apply}
    >
    > **Testing Requirements (from Section 6):**
    > - What to Test: {from Per-Task Testing table}
    > - Test Type: {Unit/Integration/Integration (emulator)}
    > - Test Pattern: {pattern name if applicable, or "Standard"}
    >
    > **Key Files:** {files}
    > **Dependencies:** {dependencies}
    > **Previous Handoff:** {summary or "First task"}
    > **Review Fixes:** {findings to address or "None"}
    >
    > **Boundaries:**
    > - In scope: {relevant boundaries}
    > - Out of scope: {relevant boundaries}
    > - Protected: {protected elements}

11. **Gate G1:**

    **Question:** "Understanding confirmed? Ready to plan?"

    | Option | Description |
    |--------|-------------|
    | **Ready to plan** | Understanding is correct, proceed to planning |
    | **Clarify gaps** | Something is missing or wrong, need to discuss |

**Proceed when:** User confirms understanding

→ Proceed to Phase 3

---

### Phase 3: Plan

**Goal:** Create a file-by-file implementation plan using Plan Mode

**Actions:**

1. **Enter Plan Mode programmatically:**

   Call `EnterPlanMode` to switch into planning mode. Do NOT ask the user to press Shift+Tab.

2. **In Plan Mode:**
   - Read key files listed in the target task and referenced in the spec's Codebase Context
   - Generate implementation plan:
     - File-by-file changes with order of operations
     - Map each change to acceptance criteria
     - Note build/test commands from spec's Codebase Context
     - If fixing review findings, map each finding to specific file changes

3. **Gate G2:** Call `ExitPlanMode` to present the plan for user approval

4. **After plan approval, create Tasks from the plan:**

   For each logical step in the implementation plan, create a Task:

   ```
   TaskCreate({
     subject: "{Imperative action, e.g., 'Add FeeEntry model to domain layer'}",
     description: "{Detailed description including:
       - Files to create/modify
       - What changes to make
       - Dependencies on other steps
       - Relevant context from spec}",
     activeForm: "{Present continuous, e.g., 'Adding FeeEntry model...'}"
   })
   ```

   **Guidelines for task decomposition:**
   - Group related file changes into one task (e.g., model + its tests = 1 task)
   - Each task should be completable in 5-15 minutes
   - Use `addBlockedBy` for sequential dependencies
   - Include file paths and brief change descriptions in the subject
   - Include the acceptance criteria this step satisfies in the description

   **Example**: If the plan has 5 file-level changes, create 3-5 Tasks grouping related changes.

**Proceed when:** User approves plan and Tasks are created

→ Proceed to Phase 4

---

### Phase 4: Implement

**Goal:** Build the task following the approved plan

**Actions:**

1. **Work through Tasks in order:**
   - Call `TaskList` to see all pending tasks
   - For each task:
     - Call `TaskUpdate` to set status to `in_progress`
     - Read the task description for implementation details
     - Implement the changes described
     - Call `TaskUpdate` to set status to `completed`
   - This ensures progress survives context compacting

2. **Run build command** from spec's Codebase Context:
   ```bash
   {build command from spec}
   ```
   Fix any build errors before proceeding.

3. **Run test command** from spec's Codebase Context:
   ```bash
   {test command from spec}
   ```
   Fix any test failures before proceeding.

**Proceed when:** Implementation complete, build passes, existing tests pass

→ Proceed to Phase 5

---

### Phase 5: Test, Verify & Review

**Goal:** Write tests, verify their quality, review code — iterating the full cycle until clean

**This phase runs as an iteration loop (max 3 rounds).**

```
┌─→ test-writer → test-verifier → AC verify → 3× code-reviewer ─┐
│                                                      │
│   findings need fixes?                               │
│     yes → fix inline → increment counter ───────────→┘
│     no  → Gate G3: "Quality acceptable?"             │
│                                                      │
│   counter >= 3 → present remaining → Gate G3         │
└──────────────────────────────────────────────────────┘
```

**Actions per iteration:**

#### Step 1: Test Writing (test-writer agent)

Launch test-writer agent:

```
Task(
  subagent_type: "robooster-claude:test-writer",
  prompt: "Write tests for the implementation.

           ## Feature Context
           Task: {task name and goal from spec}

           ## Required Test Coverage (from Spec Section 6)
           **Test Type:** {Unit/Integration/Integration (emulator)}
           **What to Test:** {exact text from Per-Task Testing table}

           ## Acceptance Criteria to Cover
           {acceptance criteria from spec}

           ## Test Pattern to Follow
           {if spec has a test pattern for this task type, include it verbatim}
           {otherwise: "Follow existing test patterns in the codebase"}

           ## Implementation Details
           - Data structures: {from spec §8}
           - Algorithm steps: {pseudocode from spec §8}
           - Validation rules: {rules with expected error cases}

           ## Files to Test
           {list of files created/modified in Phase 4}

           ## Build/Test Commands
           {from spec Codebase Context}

           Write {test_type} tests covering the specific areas listed above.",
  description: "Write {test_type} tests for task"
)
```

On iteration 2+: update prompt to include "Update existing tests and add tests for changes made in the previous review cycle."

#### Step 2: Test Verification (test-verifier agent)

Launch test-verifier agent:

```
Task(
  subagent_type: "robooster-claude:test-verifier",
  prompt: "Verify test quality for the implementation.

           Test Files:
           {list of test files}

           Implementation Files:
           {list of implementation files}

           Mutation Scope: {muttests value: all/new/none}

           Targets:
           - Mutation score: >80% (if mutation testing enabled)
           - Branch coverage: >70%
           - Red flag detection

           Run mutation testing and coverage analysis.",
  description: "Verify test quality"
)
```

#### Step 3: Acceptance Criteria Verification (ac-verifier agent)

Launch ac-verifier agent for evidence-based verification:

```
Task(
  subagent_type: "robooster-claude:ac-verifier",
  prompt: "Verify implementation against acceptance criteria.

           Task: {N} — {task name}
           Goal: {task goal}

           Acceptance Criteria:
           {exact AC list from spec}

           Key Files:
           {key files from spec}

           Implementation Reference:
           {from spec §8 - data structures, algorithms, validation rules}

           Build/Test Commands:
           {from spec Codebase Context}

           Verify each AC independently. Trust only codebase and AC.
           Run tests if needed to verify behavior criteria.",
  description: "Verify acceptance criteria"
)
```

**Display ac-verifier results to user:**

After ac-verifier completes, always show the full verification output:

> ## Acceptance Criteria Verification
>
> {Copy the Verification Summary table from ac-verifier output}
>
> ### Detailed Results
>
> | # | Acceptance Criterion | Status | Evidence |
> |---|---------------------|--------|----------|
> | {Copy all rows from ac-verifier Detailed Results table} |
>
> {If any PARTIAL or FAIL, include the "Not Met Criteria" section with full details}
>
> {If tests were run, include "Behavior Verification" section with commands and output}

This ensures the user sees exactly what was verified and how.

**Interpret results:**

- **PASS:** All ACs verified with evidence → Proceed to Step 4
- **PARTIAL or FAIL:** Fix issues from ac-verifier output, re-run verification

**AC verification iteration (max 2 rounds):**

1. If not PASS, fix the specific issues identified
2. Re-run ac-verifier (only ac-verifier, not full cycle)
3. If still not PASS after 2 iterations:
   - Document unmet ACs with reasons
   - Present to user at Gate G3 for decision

#### Step 4: Code Review (3 parallel code-reviewer agents)

Launch 3 code-reviewer agents in parallel:

```
Task(
  subagent_type: "robooster-claude:code-reviewer",
  prompt: "Review these files for simplicity, DRY, and elegance.
           Focus on: unnecessary complexity, code duplication,
           readability issues, overly clever code.

           Files:
           {list of all created/modified files}",
  description: "Review for simplicity"
)
```

```
Task(
  subagent_type: "robooster-claude:code-reviewer",
  prompt: "Review these files for bugs and functional correctness.
           Focus on: logic errors, edge cases, null handling,
           error paths, race conditions.

           Files:
           {list of all created/modified files}",
  description: "Review for bugs"
)
```

```
Task(
  subagent_type: "robooster-claude:code-reviewer",
  prompt: "Review these files for project conventions and abstractions.
           Focus on: naming conventions, architecture patterns,
           proper use of existing abstractions, consistency.

           Files:
           {list of all created/modified files}",
  description: "Review for conventions"
)
```

#### Step 5: Evaluate & Iterate

1. Consolidate all findings from test-verifier, ac-verifier, and code-reviewers
2. **If findings need fixes AND iteration < 3:**
   - Fix issues inline (no re-planning needed — review fixes are typically small)
   - Run build and test commands to verify fixes don't break anything
   - Increment iteration counter
   - **If ac-verifier was not PASS:** Re-run ac-verifier only (not full cycle) to confirm fixes
   - Loop back to Step 1 (re-run full cycle: tests may need updating after fixes)
3. **If no findings OR iteration >= 3:**
   - Present results summary to user

#### Step 6: XML Documentation (conditional — C# projects only)

**Only execute if `platro-services` is involved** (detected from spec's Codebase Context or key files).

1. Run documentation linter:
   ```bash
   cd platro/platro-services && make docs-lint-log 2>&1
   ```

2. Parse lint output — extract file paths with errors, filtering to files in scope

3. Spawn parallel xml-comments-writer agents in batches of 10-15 files:

   ```
   Task(
     subagent_type: "robooster-claude:xml-comments-writer",
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

   **Launch ALL batch agents in parallel.**

4. Re-run lint to verify:
   ```bash
   cd platro/platro-services && make docs-lint 2>&1 | head -50
   ```

5. Iteration loop (max 3 rounds):
   - If errors remain AND iteration < 3 → re-batch affected files, spawn new agents
   - If errors remain AND iteration >= 3 → present to user and proceed

#### Gate G3

**Question:** "Quality acceptable? Ready to finalize?"

| Option | Description |
|--------|-------------|
| **Quality acceptable** | Proceed to handoff |
| **Fix remaining issues** | Address specific findings before proceeding |

Present summary with results:

> ## Quality Summary (Iteration {N}/3)
>
> **Tests:**
> - Mutation score: {score}%
> - Branch coverage: {coverage}%
> - Red flags: {count or "None"}
>
> **Code Review:**
> - Findings addressed: {count}
> - Findings remaining: {count} (list if any)
>
> **Acceptance Criteria:** {PASS/PARTIAL/FAIL}
> - Verified: {N}/{total}
> - Not met: {list from ac-verifier output, or "None"}
>
> **XML Documentation:** {Clean / N errors remaining / N/A}

**Proceed when:** User approves quality

→ Proceed to Phase 6

---

### Phase 6: Handoff & Save

**Goal:** Write handoff document and present summary

**Actions:**

1. **Generate handoff filename:**
   - Pattern: `YYYYMMDD-handoff-{title-slug}-task-{N}.md`
   - Title slug: lowercase, hyphenated, derived from feature name
   - `{N}` is the task number from the spec

2. **Compose handoff document:**

   ```yaml
   ---
   title: "Handoff: Task {N} — {Task Name}"
   description: "{1-2 sentence summary (max 300 chars)}"
   type: handoff
   status: draft
   version: "1.0.0"
   created: {YYYY-MM-DD}
   updated: {YYYY-MM-DD}
   author: skill::task-implementing
   modified_by: skill::task-implementing
   linear: ~
   ---
   ```

   ```markdown
   # Handoff: Task {N} — {Task Name}

   ## Feature Spec
   [{spec filename}]({spec path})

   ## Completed
   - {What was built}

   ## Acceptance Criteria Status

   | # | Criterion | Status | Evidence |
   |---|-----------|--------|----------|
   | 1 | {criterion 1} | PASS | `{file:line}` — {brief evidence} |
   | 2 | {criterion 2} | PASS | `{file:line}` — {brief evidence} |
   | 3 | {criterion not met} | FAIL | {what's missing} |

   *Verified by ac-verifier agent with code-level evidence.*

   ## Files Changed
   - {file}: {what changed}

   ## Decisions Made During Implementation
   - {Decision}: {rationale}

   ## Deviations from Spec
   - {Deviation}: {why} (or "None")

   ## Quality Results
   - Mutation score: {score}%
   - Branch coverage: {coverage}%
   - Review iterations: {count}
   - Remaining findings: {list or "None"}

   Note: The `Acceptance Criteria Status` table must reflect the ac-verifier output from Phase 5 Step 3. Copy the Detailed Results table from ac-verifier. Do not mark criteria as PASS unless verified with evidence.

   ## For Next Task
   - {What the next session needs to know}
   - {Gotchas discovered}
   ```

3. **Save to `{KB_ROOT}/handoffs/`:**
   ```bash
   mkdir -p {KB_ROOT}/handoffs
   ```
   Write the file.

4. **Update spec file (TWO edits required):**

   **Edit A — Check AC boxes:** Find the acceptance criteria list in the task section and edit each line:
   ```diff
   - - [ ] Criterion text here
   + - [x] Criterion text here
   ```
   Only check boxes (`[x]`) for criteria with **PASS** status in ac-verifier output. Leave `[ ]` for PARTIAL or FAIL criteria.

   **Edit B — Add status fields:** After the task's `**Dependencies:**` line, append:
   ```markdown
   - **Status:** Done
   - **Handoff:** [{handoff filename}]({handoff path})
   ```

   **Both edits are mandatory.** Do not skip Edit A.

5. **Present summary:**

   > ## Task Implementation Complete
   >
   > **Task:** {N} — {Task Name}
   > **Spec:** [{spec filename}]({spec path})
   > **Handoff:** [{handoff filename}]({handoff path})
   > **Project:** {PROJECT}
   >
   > ### What Was Built
   > - {summary}
   >
   > ### Files Changed
   > - {file}: {changes}
   >
   > ### Quality Results
   > - Mutation score: {score}%
   > - Branch coverage: {coverage}%
   > - Review iterations: {count}
   >
   > ### Suggested Commit Message
   > ```
   > {suggested commit message}
   > ```
   >
   > ### Next Task
   > To continue: `/task-implementing --spec={spec path} --task={N+1}`

**Session complete.**

---

## Human Gates

| Gate | Phase | Question | Pass | Fail |
|------|-------|----------|------|------|
| G1 | Phase 2 | "Understanding confirmed?" | Continue | Clarify gaps |
| G2 | Phase 3 | "Plan approved?" | Continue | Iterate plan |
| G3 | Phase 5 | "Quality acceptable?" | Continue | Fix remaining |

---

## Rules

1. **One task per session** — Do not attempt multiple spec tasks
2. **Spec is source of truth** — Follow the Feature Spec; do not redesign
3. **Read handoff for continuity** — If task > 1, always read previous handoff
4. **Human gates are mandatory** — Do not skip approval checkpoints
5. **One question per message** — Keep interactions focused
6. **Max 3 quality iterations** — Full cycle (test → verify → review) repeats max 3 times
7. **V2 frontmatter** — Use `author: skill::task-implementing`
8. **Document deviations** — Any deviations from spec must appear in handoff
9. **XML docs only for C#** — Conditional on platro-services involvement
10. **Always write handoff** — Every session ends with a handoff document
11. **Tasks for implementation steps, not acceptance criteria** — Create Tasks from the implementation plan (file-by-file changes). Do NOT create Tasks from acceptance criteria (they get prematurely marked complete and don't map 1:1 to implementation steps). Track acceptance criteria in the handoff document.
12. **Programmatic plan mode** — Call `EnterPlanMode` directly; never ask user to press Shift+Tab
13. **Create Tasks after plan approval** — Phase 3 must create Tasks from the approved implementation plan before proceeding to Phase 4. This ensures implementation steps survive context compacting.

---

## Example Invocations

```
/task-implementing
```
(Will prompt for spec and task)

```
/task-implementing --spec= @./platro/platro-kb/specs/20260127-spec-reconciliation-engine.md --task=1
```
(Use `@` with space before it for file autocomplete)

```
/task-implementing --spec=kb/specs/20260127-spec-webhook-system.md --task=3
```
(Path without `@` also works)

```
/task-implementing --spec=... --task=6 --muttests=none
```
(Skip mutation testing for rapid iteration)

```
/task-implementing --spec=... --task=6 --muttests=all
```
(Full mutation testing for final verification)
