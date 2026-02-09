---
name: concept-reviewing
description: Guided iteration over a concept document. Analyzes the file in context of a user prompt, plans targeted changes, edits, and verifies whole-document consistency.
user-invocable: true
---

# Concept Reviewing

Run one focused iteration over a concept document. The user provides a file and an iteration prompt (what to improve, challenge, expand, or clean up). The skill analyzes the document, plans changes, edits, and verifies that the result is internally consistent.

## Core Principles

- **One iteration per invocation** — Do one thing well, not everything at once
- **User steers, skill executes** — The iteration prompt defines the focus
- **Verify after every edit** — Changes must not break document consistency
- **One question per message** — Keep interactions focused

---

## Workflow

Execute phases in order. Use `AskUserQuestion` for all user interaction.

---

### Phase 1: Initialize

**Goal:** Parse arguments, read the concept file, establish session context

**Actions:**

1. **Session date:** !`date +%Y-%m-%d`

2. **Parse arguments:**
   - `--file= @{path}` or `--file={path}` — Concept file path. Strip leading `@` and `./` from path when parsing.
   - Everything else in args — the **iteration prompt** (what to focus on)
   - If `--file` not provided, check if args contain a file path (ending in `.md`) — use it
   - If still no file — list files from likely KB concept directories and ask user to select

3. **Read the concept file end-to-end.** Store full content in working memory.

4. **Detect project context from file path:**

   | Path contains      | `{PROJECT}` |
   |---------------------|-------------|
   | `platro/platro-kb`  | Platro      |
   | `kb/`               | General     |

   No AskUserQuestion needed — the file already exists, so the project is implied.

5. **Confirm to user:**

   > Starting concept review iteration
   > - Date: {DATE}
   > - File: `{file path}`
   > - Focus: {iteration prompt, summarized}

**Proceed when:** File read and iteration prompt understood

---

### Phase 2: Analyze & Ask

**Goal:** Deeply understand the document in context of the iteration prompt, surface questions, and align with the user on what needs to change

**Actions:**

1. **Analyze the full document** against the iteration prompt. Identify:
   - **Affected sections** — which parts of the document are relevant to the prompt
   - **Current state** — what those sections say now and why they might need change
   - **Dependencies** — other sections that reference or depend on the affected ones
   - **Gaps or inconsistencies** — issues the iteration prompt exposes (or that you notice independently)

2. **Codebase exploration (auto-decide).**

   Judge whether the iteration prompt needs codebase context:
   - **Explore** if the prompt involves code verification, implementation feasibility, checking existing patterns, or references specific files/modules
   - **Skip** if the prompt is purely about document structure, wording, flow, or conceptual reasoning

   When exploring:
   ```
   Task(
     subagent_type: "robooster-claude:code-explorer",
     prompt: "Explore [target area from iteration prompt] focusing on:
              [specific questions derived from document analysis].
              Return findings relevant to verifying/improving: [concept topic].",
     description: "Explore codebase for concept review"
   )
   ```

   Synthesize findings into the analysis.

3. **Present analysis and ask clarifying questions (one at a time):**

   > ## Analysis
   >
   > **Focus:** {iteration prompt restated}
   >
   > **Affected sections:**
   > - {Section name} (lines {N-M}) — {why it's affected}
   > - {Section name} (lines {N-M}) — {why it's affected}
   >
   > **Dependencies** (sections that reference the affected ones):
   > - {Section name} — {what reference needs updating}
   >
   > **Issues found:**
   > - {Issue 1}
   > - {Issue 2}

   Then ask targeted clarifying questions via AskUserQuestion — one per message. Focus on:
   - Ambiguities in the iteration prompt
   - Design choices where user preference matters
   - Contradictions discovered during analysis that need a decision

   Skip questions where the answer is obvious from context.

4. **Gate G1:**

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
   - **Section** — which section is being modified
   - **Change** — what specifically changes (add/remove/rewrite/restructure)
   - **Rationale** — why this change addresses the iteration prompt
   - **Ripple effects** — what other sections need updating for consistency

   Format:

   ```
   ## Change Plan

   ### Change 1: {brief title}
   - **Section:** {section name}
   - **Change:** {description of what changes}
   - **Rationale:** {why}
   - **Ripple effects:** {other sections to update, or "None"}

   ### Change 2: {brief title}
   ...

   ### Consistency updates
   - {Cross-reference fix 1}
   - {Terminology alignment fix 1}
   - {etc.}
   ```

   Keep the plan concise. This is a document edit, not a codebase refactor.

2. **Gate G2:** Present the change plan to the user, then ask for approval via `AskUserQuestion`:

   **Question:** "Approve this change plan?"

   | Option | Description |
   |--------|-------------|
   | **Approve — execute edits** | Plan is good, proceed with editing |
   | **Revise plan** | Adjust the plan before executing |

3. **After approval, execute edits:**

   - Work through changes in plan order using the Edit tool
   - After all planned changes, apply consistency updates (cross-references, terminology)
   - Update frontmatter:
     - `updated: {DATE}`
     - `modified_by: skill::concept-reviewing`

**Proceed when:** All planned edits applied

---

### Phase 4: Verify

**Goal:** Independently verify the edited document is internally consistent

**Actions:**

1. **Re-read the entire document** from disk (not from memory — the Edit tool may have changed it).

2. **Run the consistency checklist:**

   | Check | What to verify |
   |-------|---------------|
   | **Cross-references** | Section references, "see §X" pointers, "(cross-ref ...)" notes — do they still point to correct content? |
   | **Terminology** | Are terms used consistently throughout? No section using old name while another uses new name? |
   | **Data consistency** | Do tables, counts, field lists agree across sections? If a field was added/removed, is it reflected everywhere? |
   | **Flow coherence** | Do diagrams/flows match the prose? Do "before/after" comparisons still hold? |
   | **Task outline alignment** | If the document has a task outline, does it still match the described changes? |
   | **Resolved questions** | Do resolved questions still match the current document content? |
   | **Completeness** | Did the changes fully address the iteration prompt? Any loose ends? |

3. **Classify findings:**
   - **Minor** — typos, small cross-reference fixes, missing updates to a term. Fix these inline in one pass without asking.
   - **Substantial** — logical inconsistencies, missing sections, design contradictions. Report these to the user.

4. **Proceed to Gate G3.**

#### Gate G3

Present verification results:

> ## Verification Results
>
> **Iteration prompt:** {original prompt}
> **Changes made:** {count} sections modified
>
> **Consistency check:**
> - Cross-references: {OK / N issues}
> - Terminology: {OK / N issues}
> - Data consistency: {OK / N issues}
> - Flow coherence: {OK / N issues}
> - Task outline: {OK / N issues / N/A}
> - Resolved questions: {OK / N issues / N/A}
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

> ## Concept Review Done
>
> **File:** `{file path}`
> **Focus:** {iteration prompt}
> **Changes:** {brief summary of what changed}
>
> **To continue iterating:**
> ```
> /concept-reviewing {next focus area} --file= @{file path}
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

1. **Document only — no code changes** — This skill edits the concept document and nothing else. Never modify source code, config files, or any file outside the target document during a reviewing session
2. **No new files** — This skill edits an existing concept document, never creates new ones
2. **Preserve document voice** — Match the writing style of the existing document
3. **Minimize blast radius** — Change only what the iteration prompt requires plus consistency fixes
4. **Frontmatter updates** — Always update `updated` and `modified_by` fields
5. **One question per message** — Keep interactions focused
6. **Respect both gates** — G1 and G3 are explicit gates; G2 is a regular AskUserQuestion approval
7. **Verify after every edit** — Phase 4 is not optional
8. **Re-read from disk** — In Phase 4, always re-read the file, don't rely on memory of edits
9. **Max 3 returns to Phase 3** — Prevent infinite iteration; surface remaining issues and finish
10. **Frontmatter edge case** — If frontmatter is absent, add `updated` and `modified_by` fields without restructuring the file

---

## Example Invocations

```
/concept-reviewing Resolve the open question about currency derivation
  --file= @platro/platro-kb/concepts/20260208-concept-allocation-service.md
```

```
/concept-reviewing Challenge the runtime modes architecture — is the 3-mode split justified?
  --file= @platro/platro-kb/concepts/20260208-concept-allocation-service.md
```

```
/concept-reviewing Clean up cross-references in the integration testing section
  --file= @platro/platro-kb/concepts/20260208-concept-allocation-service.md
```

```
/concept-reviewing Expand the CLI scripts section with error handling details
  --file= @platro/platro-kb/concepts/20260208-concept-allocation-service.md
```

```
/concept-reviewing
```
(Will prompt for file and iteration focus)
