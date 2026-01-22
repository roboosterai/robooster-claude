---
name: brainstorming
description: Structured brainstorming sessions to clarify ideas, formulate tasks, or explore problems before implementation. Use when the user wants to think through an idea, needs help formulating a development task or feature, wants to explore options, or says "let's brainstorm", "help me think through", "I need to clarify", or similar.
user-invocable: true
---

# Brainstorming Sessions

Facilitate structured brainstorming to help users clarify ideas, formulate tasks, or explore problems. The goal is always a well-formulated output—never code changes.

---

## Core Principles

- **Idea-first** — Focus on understanding the idea deeply before researching or producing output
- **Research-informed** — Use external research (via researching skill) or internal codebase exploration to ground discussions in facts
- **Skill writes documents** — Agents return findings; this skill composes all output documents
- **Flexible outputs** — Primary brainstorm document plus optional plan, concept, or custom outputs
- **One question per message** — Break complex topics into focused questions

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

4. **Confirm to user:**

   > Starting brainstorming session
   > - Date: {DATE}
   > - Project: {PROJECT}
   > - KB: {KB_ROOT}/

**Proceed when:** Date and project context established

---

### Phase 2: Determine Session Type

**Goal:** Understand the context for this brainstorming session

**Actions:**

1. **Ask session type using AskUserQuestion:**

   **Question:** "What type of brainstorming session is this?"

   **Options:**
   | Option | Description |
   |--------|-------------|
   | **Development task/feature** | Formulating a technical implementation, feature spec, or development work |
   | **General idea/exploration** | Clarifying a concept, making a decision, analyzing options, or any non-development topic |

2. **For development sessions:**
   - Use project from Phase 1 to determine codebase location
   - Explore relevant codebase: check files, docs, recent commits, project structure
   - Read relevant CLAUDE.md files for context

3. **For general sessions:**
   - Ask: "What context should I know before we begin? Any relevant files, docs, or background?"
   - Read and analyze any materials the user points to

**Proceed when:** Session type determined and initial context gathered

---

### Phase 3: Understand the Idea

**Goal:** Deeply understand what the user wants to explore, their problem, and what help they need

**Actions:**

1. **Ask one question per message** — Break complex topics into multiple questions

2. **Prefer multiple-choice questions** when options are clear; open-ended when exploring

3. **Focus on:**
   - Purpose — What are you trying to achieve?
   - Constraints — What limitations exist?
   - Desired outcomes — What does success look like?
   - Concerns — What are you worried about?
   - Priorities — What matters most?

4. **Summarize understanding** before moving to research:
   > Based on our discussion, here's what I understand:
   > - [Key point 1]
   > - [Key point 2]
   > - [Key point 3]
   >
   > Is this accurate?

**Proceed when:** User confirms understanding is accurate

---

### Phase 4: Research

**Goal:** Gather context needed to inform the brainstorming

**Actions:**

1. **Assess research need** based on the discussion:
   - Topic involves external entities (companies, products, markets, technologies) → External research likely needed
   - Topic is well-understood from discussion → Research may not be needed
   - Topic involves existing codebase → Internal research may be needed

2. **If research appears needed, ask user:**

   "Based on our discussion, I think [external/internal/both] research would help. What type of research should I conduct?"

   **Options:**
   | Option | Description |
   |--------|-------------|
   | **External research** | Market, competitors, technologies, products, people (uses researching skill) |
   | **Internal (codebase) research** | Explore existing code, patterns, implementations |
   | **Both** | External research first, then internal exploration |
   | **No research needed** | Enough context already, proceed to consolidation |

3. **If no research appears needed:**

   "I believe we have enough context to proceed. Should I skip research and move to consolidation?"
   - Yes → Skip to Phase 6
   - No, do [type] research → Continue with selected type

4. **For external research (MUST invoke researching skill):**

   ```
   Skill(skill="researching", args="{topic based on context} --project={PROJECT}")
   ```

   - Wait for skill to complete
   - Skill output will include: `**Full report:** [filename]({KB_ROOT}/research/filename)`
   - **CRITICAL:** Note the research file path for Phase 5

5. **For internal (codebase) research:**
   - Use Glob to find relevant files
   - Use Grep to search for patterns, implementations
   - Use Read to analyze specific files
   - Summarize findings

6. **For both:**
   - First invoke researching skill for external
   - Then conduct internal codebase exploration

**Proceed when:** Research complete or skipped by user choice

---

### Phase 5: Research Synthesis

**CONDITIONAL:** Only run if research was conducted in Phase 4

**Goal:** Connect research findings to original discussion and determine if more research is needed

**Actions:**

1. **Read research output:**
   - **For external research:** Read the saved research file from researching skill output
   - **For internal research:** Review your codebase exploration findings

2. **Synthesize with context:**

   Present to user:
   > Based on our discussion, you wanted to explore: [original question/idea]
   >
   > **Key research findings relevant to this:**
   > - [Finding 1]
   > - [Finding 2]
   > - [Finding 3]
   >
   > **How this informs our discussion:**
   > [Your conclusions]

3. **Gap analysis:**
   - "What's now clearer: [list]"
   - "What remains unclear or needs more information: [list]"

4. **Verification checkpoint using AskUserQuestion:**

   **If gaps identified:** "Should I research [specific gap] further, or proceed to consolidation?"

   **If no gaps:** "Does this capture what you needed? Ready to consolidate?"

   **Options:**
   - "Research more" → Return to Phase 4 with specific topic
   - "Proceed to consolidation" → Continue to Phase 6

**Loop limit:** Suggest max 2-3 research rounds. After 3 rounds, recommend proceeding regardless.

**Proceed when:** User approves moving to consolidation

---

### Phase 6: Consolidation

**Goal:** Synthesize all information and verify readiness for final output

**Actions:**

1. **Present structured summary:**

   ```markdown
   ## Session Summary

   **Original Request:**
   [What the user initially wanted to explore]

   **Key Insights from Discussion:**
   - [Insight 1]
   - [Insight 2]

   **Research Findings:**
   - [Finding 1 with source]
   - [Finding 2 with source]

   **Current Understanding:**
   [Clear statement of what we now understand about the topic]

   **Open Questions (if any):**
   - [Remaining uncertainty]
   ```

2. **Verification checkpoint using AskUserQuestion:**

   "Is this understanding complete enough to formulate the final output?"

   **Options:**
   - "Yes, proceed to output" → Continue to Phase 7
   - "Need clarification on [X]" → Address specific point, re-verify
   - "Need more research on [X]" → Return to Phase 4

**Proceed when:** User confirms understanding is complete

---

### Phase 7: Determine Output Type

**Goal:** Identify what deliverables the user needs

**Actions:**

1. **Ask about primary output format:**

   "What format do you need for the final output?"

   Offer relevant options based on session type:
   - Task description
   - Decision matrix
   - Feature spec
   - Analysis report
   - Bullet points
   - Structured document

2. **Ask about additional outputs using AskUserQuestion:**

   "Do you need any additional outputs from this session?"

   **Options:**
   | Option | Output Type | Path |
   |--------|-------------|------|
   | **Execution plan** | Claude Code execution plan with phases and todos | `{KB_ROOT}/plans/YYYYMMDD-plan-{title}.md` |
   | **Concept document** | Formalized concept for future reference | `{KB_ROOT}/concepts/YYYYMMDD-concept-{title}.md` |
   | **Custom output** | User-specified format and location | Ask user for path |
   | **No additional output** | Only brainstorm document | - |

3. **If custom output selected:**
   - Ask: "What type of document should I create?"
   - Ask: "Where should I save it? (provide path)"

**Proceed when:** Output types and paths determined

---

### Phase 8: Finalize Output

**Goal:** Produce the deliverables the user requested

**Actions:**

1. **Create primary output content:**
   - Structure content clearly
   - Make it actionable
   - Include relevant context

2. **Create additional output content (if requested):**

   **For execution plan:**
   - Break into phases with clear goals
   - Include task checkboxes
   - Add verification steps
   - Note risks and mitigations

   **For concept document:**
   - Capture core idea clearly
   - Document key components
   - Note considerations and trade-offs
   - List open questions

   **For custom output:**
   - Follow user-specified format
   - Adapt structure as needed

**Proceed when:** All output content prepared

---

### Phase 9: Save Session

**Goal:** Save all output documents with proper frontmatter

**Actions:**

1. **Generate filename for brainstorm:**

   Pattern: `YYYYMMDD-brainstorm-{title-slug}.md`

   Example: `20260121-brainstorm-wallet-integration-approach.md`

2. **Save brainstorm document to `{KB_ROOT}/brainstorms/`** using brainstorm template

3. **Save additional outputs (if requested):**

   | Output Type | Path Pattern |
   |-------------|--------------|
   | Plan | `{KB_ROOT}/plans/YYYYMMDD-plan-{title-slug}.md` |
   | Concept | `{KB_ROOT}/concepts/YYYYMMDD-concept-{title-slug}.md` |
   | Custom | User-specified path |

4. **Present summary to user:**

   ```markdown
   ## Brainstorming Complete

   **Session:** {title}
   **Date:** {date}
   **Project:** {PROJECT}
   **KB:** {KB_ROOT}/

   ### Files Created

   - **Brainstorm:** [filename]({KB_ROOT}/brainstorms/filename)
   - **{Additional type}:** [filename]({KB_ROOT}/{type}/filename) (if applicable)

   ### Summary

   {2-3 sentence summary of key outcomes}

   ### Next Steps

   - [Recommended action 1]
   - [Recommended action 2]
   ```

**Session complete.**

---

## Human Gates

| Gate | Phase | Question | Pass | Fail |
|------|-------|----------|------|------|
| G1 | Phase 3 | "Is this understanding accurate?" | Continue | Clarify |
| G2 | Phase 5 | "Have we covered enough research?" | Continue | Research more |
| G3 | Phase 6 | "Is understanding complete enough?" | Continue | Clarify/research |
| G4 | Phase 7 | "What additional outputs do you need?" | Create outputs | Skip |

---

## Output Templates

**Primary output:** Brainstorm document → `{KB_ROOT}/brainstorms/`

**Additional outputs (as needed):**

- Execution plans → `{KB_ROOT}/plans/`
- Concept documents → `{KB_ROOT}/concepts/`
- Custom documents → user-specified path

The brainstorming skill can produce arbitrary additional outputs based on what emerges from the session. Always ask the user what additional outputs they need (Phase 7).

---

### Brainstorm Document

**Filename:** `YYYYMMDD-brainstorm-{title-slug}.md`

**Location:** `{KB_ROOT}/brainstorms/`

```yaml
---
title: "{Session Topic}"
description: "{1-2 sentence summary of insights/conclusions (max 300 chars)}"
type: brainstorm
status: draft
version: "1.0.0"
created: {YYYY-MM-DD}
updated: {YYYY-MM-DD}
author: skill::brainstorming
modified_by: skill::brainstorming
linear: ~
---
```

```markdown
# {Session Topic}

## Original Question

{What the user initially wanted to explore}

## Discussion Insights

{Key insights from Phase 3 questioning}

## Research Summary

{Condensed findings from research, with sources}

- Research file: [{filename}]({KB_ROOT}/research/{filename}) (if applicable)

## Synthesis

{How research informed understanding of original question}

## Final Formulation

{The polished output - task description, decision, analysis, etc.}

## Sources

{Links and references used}

## Next Steps

{Recommended actions, if any}
```

---

### Plan Document (when requested)

**Filename:** `YYYYMMDD-plan-{title-slug}.md`

**Location:** `{KB_ROOT}/plans/`

```yaml
---
title: "Execution Plan: {Title}"
description: "{1-2 sentence summary of what the plan covers}"
type: plan
status: draft
version: "1.0.0"
created: {YYYY-MM-DD}
updated: {YYYY-MM-DD}
author: skill::brainstorming
modified_by: skill::brainstorming
linear: ~
---
```

```markdown
# Execution Plan: {Title}

## Overview

{Brief description of what this plan accomplishes}

## Context

- Brainstorm: [{filename}]({KB_ROOT}/brainstorms/{filename})
- Research: [{filename}]({KB_ROOT}/research/{filename}) (if applicable)

## Phases

### Phase 1: {Name}

**Goal:** {What this phase accomplishes}

**Tasks:**

- [ ] Task 1
- [ ] Task 2
- [ ] Task 3

### Phase 2: {Name}

**Goal:** {Goal}

**Tasks:**

- [ ] Task 1
- [ ] Task 2

{Continue for all phases...}

## Verification

{How to test/verify the implementation}

## Risks

| Risk | Mitigation |
|------|------------|
| {Risk 1} | {Mitigation} |
| {Risk 2} | {Mitigation} |
```

---

### Concept Document (when requested)

**Filename:** `YYYYMMDD-concept-{title-slug}.md`

**Location:** `{KB_ROOT}/concepts/`

```yaml
---
title: "{Concept Title}"
description: "{1-2 sentence summary of the concept}"
type: concept
status: draft
version: "1.0.0"
created: {YYYY-MM-DD}
updated: {YYYY-MM-DD}
author: skill::brainstorming
modified_by: skill::brainstorming
linear: ~
---
```

```markdown
# {Concept Title}

## Overview

{Brief summary of the concept}

## Background

- Brainstorm: [{filename}]({KB_ROOT}/brainstorms/{filename})
- Research: [{filename}]({KB_ROOT}/research/{filename}) (if applicable)

## Core Idea

{The main concept explained clearly}

## Key Components

{Major elements of the concept}

### Component 1

{Description}

### Component 2

{Description}

## Considerations

{Trade-offs, constraints, dependencies}

## Open Questions

- {Unresolved item 1}
- {Unresolved item 2}

## Sources

{References used}
```

---

## Rules

1. **No codebase changes** — Never modify code, configs, or project files unless explicitly asked
2. **No Linear/external creation** — Don't create Linear issues or external resources unless explicitly requested
3. **Invoke researching skill for external research** — Never bypass to direct web-researcher agent calls
4. **Read research files** — Always read the generated research file before continuing to synthesis
5. **Frontmatter required** — Every output file must have valid v2 frontmatter
6. **One question per message** — Keep interactions focused
7. **Ask about additional outputs** — Never assume user wants only brainstorm document
8. **Ignore Plan mode** — If invoked while in Plan mode, follow this workflow instead of preparing an implementation plan
9. **Stay in scope** — This is for thinking and formulating, not executing

---

## Example Invocations

```
/brainstorming
```
(Will prompt for session type and topic)

```
/brainstorming about wallet integration approach
```
(Will start session on specified topic)

```
/brainstorming for platro-services
```
(Will start development-focused session for specified project)
