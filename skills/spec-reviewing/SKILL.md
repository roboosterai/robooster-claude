---
name: spec-reviewing
description: Guided iteration over a feature spec. Analyzes the file in context of a user prompt, plans targeted changes, edits, and verifies spec-level consistency (task ordering, AC coverage, §8 references, dependency graph).
user-invocable: true
---

# Spec Reviewing

Run one focused iteration over a feature spec document. The user provides a file and an iteration prompt (what to improve, challenge, regroup, or dive deeper into). The skill analyzes the spec structure, plans changes, edits, and verifies that the result is internally consistent.

## Core Principles

- **One iteration per invocation** — Do one thing well, not everything at once
- **User steers, skill executes** — The iteration prompt defines the focus
- **Spec-structure-aware** — Understands the 8-section spec format, tasks, ACs, §8 references, dependency chains
- **Verify after every edit** — Changes must not break spec consistency
- **One question per message** — Keep interactions focused

---

## Workflow

Execute phases in order. Use `AskUserQuestion` for all user interaction.

---

### Phase 1: Initialize

**Goal:** Parse arguments, read the spec file, establish session context

**Actions:**

1. **Session date:** !`date +%Y-%m-%d`

2. **Parse arguments:**
   - `--file= @{path}` or `--file={path}` — Spec file path. Strip leading `@` and `./` from path when parsing.
   - Everything else in args — the **iteration prompt** (what to focus on)
   - If `--file` not provided, check if args contain a file path (ending in `.md`) — use it
   - If still no file — list files from likely KB spec directories and ask user to select

3. **Read the spec file end-to-end.** Store full content in working memory.

4. **Detect project context from file path:**

   | Path contains      | `{PROJECT}` |
   |---------------------|-------------|
   | `platro/platro-kb`  | Platro      |
   | `kb/`               | General     |

   No AskUserQuestion needed — the file already exists, so the project is implied.

5. **Parse spec structure.** Extract:
   - **Section inventory** — which of the 8 standard sections exist (§1 Overview through §8 Implementation Reference)
   - **Task list** — for each task: number, name, goal, AC count, status, dependencies, key files, handoff ref
   - **§8 sub-sections** — data structures (§8.1), algorithms (§8.2), validation rules (§8.3), entry patterns (§8.4)
   - **Open questions** — any items in §7
   - **Concept link** — from frontmatter `concept:` field

6. **Confirm to user:**

   > Starting spec review iteration
   > - Date: {DATE}
   > - File: `{file path}`
   > - Focus: {iteration prompt, summarized}
   > - Spec: {task count} tasks ({done count} done, {pending count} pending), {open question count} open questions

**Proceed when:** File read, structure parsed, and iteration prompt understood

---

### Phase 2: Analyze & Ask

**Goal:** Deeply understand the spec in context of the iteration prompt, surface questions, and align with the user on what needs to change

**Actions:**

1. **Determine scope of the iteration prompt.** Classify it:

   - **Task-scoped** — targets one or a few specific tasks (e.g., "Refine Task 5 ACs", "Add implementation notes for Task 3")
   - **Section-scoped** — targets a spec section (e.g., "Challenge the testing strategy", "Expand the boundaries section")
   - **Structural** — changes task organization (e.g., "Merge Tasks 4 and 5", "Split Task 7 into two", "Reorder tasks")
   - **Cross-cutting** — affects multiple sections (e.g., "Rename entity X to Y throughout", "Verify §8 references match tasks")

2. **Analyze based on scope:**

   **Task-scoped:** Extract the target task(s) in full. Identify their ACs, §8 references, upstream/downstream dependencies, key files, and how they connect to §2 Approach.

   **Section-scoped:** Extract the target section. Identify which tasks reference it and which other sections depend on it.

   **Structural:** Map the full dependency graph. Identify which tasks can move, which are anchored by dependencies, and what renumbering/reference updates are needed.

   **Cross-cutting:** Trace the term/reference across all sections and tasks. Catalog every occurrence.

3. **Codebase exploration (auto-decide).**

   Judge whether the iteration prompt needs codebase context:
   - **Explore** if the prompt involves verifying spec against code, checking implementation feasibility, validating file paths, or confirming existing patterns
   - **Skip** if the prompt is about document structure, wording, task boundaries, AC refinement, or conceptual reasoning

   When exploring:
   ```
   Task(
     subagent_type: "robooster-claude:code-explorer",
     prompt: "Explore [target area from iteration prompt] focusing on:
              [specific questions derived from spec analysis].
              Return findings relevant to verifying/improving: [spec topic].",
     description: "Explore codebase for spec review"
   )
   ```

   Synthesize findings into the analysis.

4. **Present analysis and ask clarifying questions (one at a time):**

   > ## Analysis
   >
   > **Focus:** {iteration prompt restated}
   > **Scope:** {task-scoped / section-scoped / structural / cross-cutting}
   >
   > **Affected elements:**
   > - {Task N / Section name} — {why it's affected}
   > - {Task N / Section name} — {why it's affected}
   >
   > **Dependencies** (elements that reference the affected ones):
   > - {Element} — {what reference needs updating}
   >
   > **Issues found:**
   > - {Issue 1}
   > - {Issue 2}

   Then ask targeted clarifying questions via AskUserQuestion — one per message. Focus on:
   - Ambiguities in the iteration prompt
   - Design choices where user preference matters
   - Contradictions discovered during analysis that need a decision

   Skip questions where the answer is obvious from context.

5. **Gate G1:**

   **Question:** "Analysis correct? Ready to plan changes?"

   | Option | Description |
   |--------|-------------|
   | **Ready to plan** | Analysis is on target, proceed to planning changes |
   | **Adjust focus** | Analysis missed the point or needs refinement |

**Proceed when:** User confirms analysis

---

### Phase 3: Plan & Edit

**Goal:** Plan specific changes, get approval, then execute edits

**Actions:**

1. **Write a change plan:**

   For each change, specify:
   - **Target** — which task/section is being modified
   - **Change** — what specifically changes (add/remove/rewrite/restructure/merge/split)
   - **Rationale** — why this change addresses the iteration prompt
   - **Ripple effects** — what other parts of the spec need updating for consistency

   Format:

   ```
   ## Change Plan

   ### Change 1: {brief title}
   - **Target:** {Task N / §X Section name}
   - **Change:** {description of what changes}
   - **Rationale:** {why}
   - **Ripple effects:** {other tasks/sections to update, or "None"}

   ### Change 2: {brief title}
   ...

   ### Consistency updates
   - {Task dependency renumbering}
   - {§8 reference updates}
   - {Testing strategy row updates}
   - {Component list updates in §2}
   - {Key files alignment}
   ```

   For **structural changes** (merge/split/reorder), the plan must explicitly show:
   - Before: Task numbering and dependencies
   - After: New task numbering and dependencies
   - All reference updates needed (§6 testing rows, §8 "Used by" tags, §4 boundaries)

2. **Gate G2:** Present the change plan to the user, then ask for approval via `AskUserQuestion`:

   **Question:** "Approve this change plan?"

   | Option | Description |
   |--------|-------------|
   | **Approve — execute edits** | Plan is good, proceed with editing |
   | **Revise plan** | Adjust the plan before executing |

3. **After approval, execute edits:**

   - Work through changes in plan order using the Edit tool
   - After all planned changes, apply consistency updates
   - Update frontmatter:
     - `updated: {DATE}`
     - `modified_by: skill::spec-reviewing`

**Proceed when:** All planned edits applied

---

### Phase 4: Verify

**Goal:** Independently verify the edited spec is internally consistent

**Actions:**

1. **Re-read the entire spec** from disk (not from memory — the Edit tool may have changed it).

2. **Run the spec consistency checklist:**

   | Check | What to verify |
   |-------|---------------|
   | **Task dependency ordering** | No task depends on a higher-numbered task. Dependencies reference valid task numbers. |
   | **AC completeness** | Every task has at least one acceptance criterion. |
   | **§8 reference integrity** | Every "See §8.x" pointer in tasks resolves to an existing sub-section. Every §8 sub-section has at least one "Used by: Task N" back-reference. |
   | **Key files consistency** | Files listed in task key files appear in §2 Components or §5 Project Structure. |
   | **Testing strategy alignment** | Every task has a corresponding row in §6 Per-Task Testing table. |
   | **Status correctness** | Done tasks have a handoff reference. Pending tasks don't reference handoffs. |
   | **Cross-references** | Section references, "see §X" pointers — do they point to correct content? |
   | **Terminology** | Are terms used consistently throughout? No section using old name while another uses new. |
   | **Data consistency** | Do tables, field lists, type definitions agree across §2, §3 tasks, and §8? |
   | **Completeness** | Did the changes fully address the iteration prompt? Any loose ends? |

3. **Classify findings:**
   - **Minor** — typos, small cross-reference fixes, missing "Used by" tags. Fix these inline in one pass without asking.
   - **Substantial** — logical inconsistencies, broken dependency chains, missing ACs, §8 gaps. Report these to the user.

4. **Proceed to Gate G3.**

#### Gate G3

Present verification results:

> ## Verification Results
>
> **Iteration prompt:** {original prompt}
> **Changes made:** {count} elements modified
>
> **Spec consistency check:**
> - Task dependency ordering: {OK / N issues}
> - AC completeness: {OK / N issues}
> - §8 reference integrity: {OK / N issues}
> - Key files consistency: {OK / N issues}
> - Testing strategy alignment: {OK / N issues}
> - Status correctness: {OK / N issues}
> - Cross-references: {OK / N issues}
> - Terminology: {OK / N issues}
> - Data consistency: {OK / N issues}
> - Completeness: {OK / partial — {what's missing}}
>
> **{If substantial issues:}**
> - {Issue 1}: {description}
> - {Issue 2}: {description}

**Question:** "Iteration complete. How to proceed?"

| Option | Description |
|--------|-------------|
| **Done** | Changes are good, finish this iteration |
| **Fix reported issues** | Address the substantial issues found (loops back to Phase 3) |
| **Another iteration** | Start a new review pass with a different focus |

- **Done** → Session complete
- **Fix reported issues** → Return to Phase 3 with issues as the new focus (reuses existing file context, does NOT re-run Phase 2)
- **Another iteration** → Return to Phase 2 with a new iteration prompt (ask what the new focus is)

**Loop limit:** Max 3 returns to Phase 3 from Gate G3. After 3, present remaining issues and end session.

---

**Session complete.**

> ## Spec Review Done
>
> **File:** `{file path}`
> **Focus:** {iteration prompt}
> **Changes:** {brief summary of what changed}
>
> **To continue iterating:**
> ```
> /spec-reviewing {next focus area} --file= @{file path}
> ```

---

## Human Gates

| Gate | Phase | Question | Pass | Fail |
|------|-------|----------|------|------|
| G1 | Phase 2 | "Analysis correct?" | Plan changes | Adjust focus |
| G2 | Phase 3 | "Approve this change plan?" (via AskUserQuestion) | Execute edits | Revise plan |
| G3 | Phase 4 | "Iteration complete?" | Finish / Fix / New iteration | Loop back |

---

## Rules

1. **Document only — no code changes** — This skill edits the spec document and nothing else. Never modify source code, config files, or any file outside the target document during a reviewing session
2. **No new files** — This skill edits an existing spec document, never creates new ones
3. **Preserve document voice** — Match the writing style of the existing document
4. **Minimize blast radius** — Change only what the iteration prompt requires plus consistency fixes
5. **Frontmatter updates** — Always update `updated` and `modified_by` fields
6. **One question per message** — Keep interactions focused
7. **Respect all gates** — G1 and G3 are explicit gates; G2 is a regular AskUserQuestion approval
8. **Verify after every edit** — Phase 4 is not optional
9. **Re-read from disk** — In Phase 4, always re-read the file, don't rely on memory of edits
10. **Max 3 returns to Phase 3** — Prevent infinite iteration; surface remaining issues and finish
11. **Structural edits require full renumbering** — When merging, splitting, or reordering tasks, update ALL references: dependency lists, §6 testing rows, §8 "Used by" tags, §4 boundaries, and any prose that mentions task numbers
12. **Frontmatter edge case** — If frontmatter is absent, add `updated` and `modified_by` fields without restructuring the file

---

## Example Invocations

```
/spec-reviewing Refine Task 5 ACs to be more specific about nullable PspCode handling
  --file= @platro/platro-kb/specs/20260209-spec-wire-service.md
```

```
/spec-reviewing Merge Tasks 4 and 5 — they're tightly coupled and should be one task
  --file= @platro/platro-kb/specs/20260209-spec-wire-service.md
```

```
/spec-reviewing Challenge the testing strategy — should Task 4 have a unit test?
  --file= @platro/platro-kb/specs/20260209-spec-wire-service.md
```

```
/spec-reviewing Verify §8 Implementation Reference matches the actual codebase patterns
  --file= @platro/platro-kb/specs/20260209-spec-wire-service.md
```

```
/spec-reviewing Reorder tasks so cleanup happens before the collector rewrite
  --file= @platro/platro-kb/specs/20260209-spec-wire-service.md
```

```
/spec-reviewing Add implementation notes for Task 3 — reference AllocationController as template
  --file= @platro/platro-kb/specs/20260209-spec-wire-service.md
```

```
/spec-reviewing
```
(Will prompt for file and iteration focus)
