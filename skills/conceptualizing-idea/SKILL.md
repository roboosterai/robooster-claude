---
name: conceptualizing-idea
description: Transform brainstorming session results or raw ideas into structured concept documents. Sits at Stage 2 of the agentic workflow pipeline, between brainstorming and specifying-idea. Outputs clean, diagram-rich concept documents for both AI and human consumption.
user-invocable: true
---

# Conceptualizing Idea

Transform brainstorming session results or raw ideas into structured, standardized concept documents. The goal is a document that captures the essence of an idea — what it is, why it arose, what problem it solves, and product aspects — without going into requirements-level detail or deep architecture.

## Core Principles

- **Concept, not specification** — Capture the idea clearly, not formal requirements
- **Diagram-rich** — Use ASCII diagrams for flows and architecture
- **Human + AI readable** — Clean structure for both consumers
- **Codebase-aware** — Always explore existing code when concept relates to a project
- **Research-informed** — Offer external research when beneficial
- **One question per message** — Keep interactions focused
- **Human gates at key points** — User approves before major transitions

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

3. **Set session variables based on selection:**

   | Project      | `{KB_ROOT}`         | `{GITHUB_REPO}`                            |
   |--------------|---------------------|--------------------------------------------|
   | Platro       | `platro/platro-kb`  | `https://github.com/roboosterai/platro-kb` |
   | General/Root | `kb`                | `~`                                        |

4. **Confirm to user:**

   > Starting conceptualization session
   > - Date: {DATE}
   > - Project: {PROJECT}
   > - KB: {KB_ROOT}/

**Proceed when:** Date and project context established

---

### Phase 2: Input Collection

**Goal:** Gather input and determine context

**Actions:**

1. **Ask input type using AskUserQuestion:**

   **Question:** "What would you like to conceptualize?"

   **Options:**
   | Option | Description |
   |--------|-------------|
   | **Brainstorm session** | Convert an existing brainstorm document into a concept |
   | **Raw idea** | Structure a new idea from scratch |
   | **Refine existing concept** | Improve or expand an existing concept document |

2. **For brainstorm session:**
   - Ask for file path or list recent brainstorms from `{KB_ROOT}/brainstorms/`
   - Read and extract key insights

3. **For raw idea:**
   - Ask user to describe the idea
   - Gather initial context

4. **For existing concept:**
   - Ask for file path
   - Read current state

5. **Use project context from Phase 1:**
   - If project is Platro, prepare to explore Platro codebase
   - If project is General/Root, ask if there's an existing codebase to explore

**Proceed when:** Input gathered and codebase context determined

---

### Phase 3: Codebase Exploration

**CONDITIONAL:** Only if concept relates to existing project with codebase

**Goal:** Understand the existing codebase before conceptualizing

**Actions:**

1. **Identify target project/service**

2. **Read CLAUDE.md files:**
   - Read main project CLAUDE.md
   - Note conventions, patterns, architecture

3. **Launch code-explorer agent:**
   ```
   Task(
     subagent_type: "code-explorer",
     prompt: "Explore the codebase to understand [relevant area].
              Focus on: existing patterns, architecture,
              similar features, extension points.
              Return a summary of findings relevant to [concept topic].",
     description: "Explore codebase for concept"
   )
   ```

4. **Synthesize codebase context:**
   - Present key findings to user
   - Note constraints and opportunities

**Proceed when:** Codebase context understood or phase skipped

---

### Phase 4: Understand the Idea

**Goal:** Deeply understand what the user wants to conceptualize

**Actions:**

1. **Ask one question per message** — Break complex topics into focused questions

2. **Core questions to cover:**
   - "What is the core idea? Describe it in 1-2 sentences."
   - "Why did this idea arise? What triggered it?"
   - "What problem does this solve? Who experiences this problem?"
   - "What does success look like if this concept is implemented?"

3. **Summarize understanding:**
   > Based on our discussion, here's what I understand:
   > - Core idea: [summary]
   > - Trigger: [why now]
   > - Problem: [what it solves]
   > - Success: [desired outcome]
   >
   > Is this accurate?

**Human Gate G1:** "Is this understanding accurate?"
- Pass: Continue to Phase 5
- Fail: Clarify and re-summarize

---

### Phase 5: Research

**Goal:** Gather external or internal context needed to inform the concept

**Actions:**

1. **Assess research need** based on discussion:
   - Topic involves external entities → External research likely needed
   - Topic is novel/unexplored → Research may help
   - Topic is internal/well-understood → Research may not be needed

2. **Ask user using AskUserQuestion:**

   **Question:** "Based on our discussion, would additional research help strengthen this concept?"

   **Options:**
   | Option | Description |
   |--------|-------------|
   | **External research** | Research market, competitors, technologies, best practices |
   | **Additional codebase exploration** | Explore more code patterns, similar implementations |
   | **Both** | External research first, then codebase exploration |
   | **No research needed** | Enough context already, proceed to product aspects |

3. **For external research (invoke researching skill):**
   ```
   Skill(skill="researching", args="{topic based on context} --project={PROJECT}")
   ```
   - Wait for skill to complete
   - Note research file path for synthesis

4. **For codebase exploration:**
   - Launch code-explorer agent with specific focus
   - Summarize findings

**Proceed when:** Research complete or skipped

---

### Phase 6: Research Synthesis

**CONDITIONAL:** Only if research was conducted in Phase 5

**Goal:** Connect research findings to the concept

**Actions:**

1. **Read research output:**
   - For external: Read saved research file
   - For internal: Review exploration findings

2. **Synthesize with concept:**
   > **Research findings relevant to this concept:**
   > - [Finding 1]
   > - [Finding 2]
   >
   > **How this informs the concept:**
   > [Conclusions]

3. **Gap analysis:**
   - What's now clearer
   - What remains unclear

4. **Human Gate G2:** "Does this research provide what we needed? Ready to define product aspects?"
   - Pass: Continue to Phase 7
   - Fail: Research more or clarify

---

### Phase 7: Product Aspects

**Goal:** Define user experience, scenarios, and key components

**Actions:**

1. **User experience exploration:**
   - "Who are the primary users of this concept?"
   - "Walk me through a typical scenario — what happens step by step?"
   - "Are there different user flows for different cases?"

2. **Create flow diagrams:**
   - ASCII diagrams for user flows
   - Sequence diagrams for interactions

3. **Identify key components:**
   - "What are the major parts/elements of this concept?"
   - For each component: purpose, responsibilities

4. **Present product summary:**
   ```
   ## User Experience Summary

   **Primary Users:** [users]

   **Main Flow:**
   [ASCII diagram]

   **Key Components:**
   - Component A: [purpose]
   - Component B: [purpose]
   ```

**Proceed when:** Product aspects captured

---

### Phase 8: Technical Considerations

**Goal:** Capture high-level technical ideas (NOT deep architecture)

**Actions:**

1. **High-level architecture discussion:**
   - "At a high level, how might this be implemented?"
   - "What existing systems/services would this interact with?"

2. **Create high-level architecture diagram:**
   - ASCII box diagram
   - Show major components and connections

3. **Identify constraints:**
   - Technical constraints
   - Dependencies
   - Risks

4. **Capture alternatives considered:**
   - "Were there other approaches considered?"
   - Document trade-offs

5. **Important:** Do NOT go deep into:
   - Detailed API designs
   - Database schemas
   - Implementation specifics

   Those belong in `designing-architecture` skill.

**Proceed when:** High-level technical view captured

---

### Phase 9: Consolidation

**Goal:** Synthesize all information and identify open questions

**Actions:**

1. **Present structured summary:**
   - Overview
   - Problem + Core idea
   - Key components
   - Technical approach (high-level)

2. **Identify open questions:**
   - Unresolved items
   - Decisions for next stage
   - Dependencies to clarify

3. **Human Gate G3:** "Is this concept ready to be documented? Any additions needed?"
   - Pass: Continue to Phase 10
   - Fail: Add more content

---

### Phase 10: Linear Integration

**Goal:** Handle task management before saving

**Actions:**

1. **Ask about Linear task using AskUserQuestion:**

   **Question:** "Would you like to create or link a Linear task for this concept?"

   **Options:**
   | Option | Description |
   |--------|-------------|
   | **Create new task** | Create a new Linear task and link it to this concept |
   | **Link to existing task** | Associate with an existing Linear task (I'll ask for the ID) |
   | **No task needed** | This concept doesn't need a Linear task right now |

2. **If "Create new task":**
   ```
   Task(
     subagent_type: "task-manager",
     prompt: "Create a Linear task for concept: [title].
              Description: [brief summary]
              Set status to backlog.",
     description: "Create Linear task for concept"
   )
   ```
   - Extract task ID from result

3. **If "Link to existing":**
   - Ask for Linear task ID
   - Validate format (e.g., PROJ-123)

4. **Update concept document:**
   - Set `linear:` field in frontmatter to task ID or `~`

**Proceed when:** Linear decision made

---

### Phase 11: Finalize & Save

**Goal:** Save concept document with proper frontmatter

**Actions:**

1. **Generate filename:**
   - Pattern: `YYYYMMDD-concept-{title-slug}.md`
   - Example: `20260121-concept-wallet-privacy-model.md`

2. **Compose concept document** using Output Template below

3. **Save to `{KB_ROOT}/concepts/`**

4. **Present summary:**
   ```markdown
   ## Concept Created

   **Title:** {title}
   **File:** [filename]({KB_ROOT}/concepts/filename)
   **Project:** {PROJECT}
   **KB:** {KB_ROOT}/
   **Linear:** {task ID or "Not linked"}

   ### Summary

   {2-3 sentence summary}

   ### Next Steps

   - Review the concept document
   - When ready to formalize into requirements, use `/specifying-idea`
   - Or keep as standalone reference if not progressing to implementation
   ```

**Session complete.**

---

## Human Gates

| Gate | Phase | Question | Pass | Fail |
|------|-------|----------|------|------|
| G1 | Phase 4 | "Is this understanding accurate?" | Continue | Clarify |
| G2 | Phase 6 | "Does research provide what we needed?" | Continue | Research more |
| G3 | Phase 9 | "Is concept ready to document?" | Continue | Add more |
| G4 | Phase 10 | "Linear task preference?" | Create/Link/Skip | N/A |

---

## Output Template

### Filename Pattern

`YYYYMMDD-concept-{title-slug}.md`

### Frontmatter

```yaml
---
title: "{Concept Title}"
description: "{1-2 sentence summary for RAG retrieval (max 300 chars)}"
type: concept
status: draft
version: "1.0.0"
created: {YYYY-MM-DD}
updated: {YYYY-MM-DD}
author: skill::conceptualizing-idea
modified_by: skill::conceptualizing-idea
linear: {TASK-ID or ~}
---
```

### Document Structure

```markdown
# {Concept Title}

## Overview

{2-3 sentence summary of the concept}

---

## Background

### Why This Idea Arose

{Context, triggers, motivation}

### Current State

{What exists today, if applicable}

---

## Problem Statement

{Clear articulation of the problem this concept solves}

**Who experiences this:** {users/stakeholders}

**Pain points:**
- {Pain point 1}
- {Pain point 2}

---

## Core Idea

{The main concept explained clearly — the "what"}

### Key Insight

{The central insight or approach that makes this concept valuable}

---

## User Experience

### Primary Users

{Who will use/benefit from this}

### Scenario: {Scenario Name}

{Description of a typical scenario}

```
{ASCII flow diagram}
```

### Additional Scenarios

{If applicable}

---

## Key Components

### {Component 1}

**Purpose:** {What it does}

**Responsibilities:**
- {Responsibility 1}
- {Responsibility 2}

### {Component 2}

{Same structure}

---

## Technical Considerations

### High-Level Architecture

```
{ASCII architecture diagram}
```

### Dependencies

- {Dependency 1}
- {Dependency 2}

### Constraints

- {Constraint 1}
- {Constraint 2}

---

## Alternatives Considered

### {Alternative 1}

**Description:** {What it was}

**Why not chosen:** {Reason}

---

## Open Questions

- [ ] {Question 1}
- [ ] {Question 2}

---

## References

- Brainstorm: [{filename}]({KB_ROOT}/brainstorms/{filename}) (if applicable)
- Research: [{filename}]({KB_ROOT}/research/{filename}) (if applicable)
- Related concepts: (if applicable)

---

*This concept is at Stage 2 of the agentic workflow. To progress to formal requirements, use `/specifying-idea`.*
```

---

## Rules

1. **No code changes** — This skill only produces documents
2. **No requirements-level detail** — That's for specifying-idea
3. **No deep architecture** — That's for designing-architecture
4. **Always explore codebase** — If concept is for existing project
5. **Ask about research** — Let user decide if external research helps
6. **Invoke researching skill** — For external research (never bypass to agents)
7. **Always ask about Linear** — Before saving the document
8. **Frontmatter required** — Every output file must have valid v2 frontmatter
9. **One question per message** — Keep interactions focused
10. **Use diagrams** — ASCII diagrams for flows and architecture
11. **Stay in scope** — This is for capturing/structuring ideas, not executing

---

## Example Invocations

```
/conceptualizing-idea
```
(Will prompt for input type)

```
/conceptualizing-idea from brainstorm kb/brainstorms/20260121-brainstorm-wallet-privacy.md
```
(Will load specified brainstorm)

```
/conceptualizing-idea for platro-services
```
(Will start with codebase exploration for specified project)
