---
name: concept-writing
description: Lightweight concept scaffolding through structured discussion, research, and reasoning. Produces a first-iteration concept document designed for further refinement in vanilla Claude Code sessions.
user-invocable: true
---

# Concept Writing

Scaffold a concept document through structured discussion, optional research, and guided reasoning. The goal is a solid first iteration — not a finished document. The user refines it in subsequent Claude Code sessions.

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

   > Starting concept writing session
   > - Date: {DATE}
   > - Project: {PROJECT}
   > - KB: {KB_ROOT}/

**Proceed when:** Date and project context established

---

### Phase 2: Understand

**Goal:** Gather input, absorb context, and deeply understand the idea

**Actions:**

1. **Collect input materials:**
   - If args contain a file path (brainstorm, existing concept, notes) — read it
   - If args contain a topic description — use it as starting point
   - If no args — ask: "What would you like to conceptualize?"

2. **Read any referenced files:**
   - Brainstorm documents from `{KB_ROOT}/brainstorms/`
   - Research files from `{KB_ROOT}/research/`
   - Any other files the user points to

3. **Ask clarifying questions, one per message.** Core areas to cover:
   - What is the core idea? (1-2 sentences)
   - Why did this idea arise? What triggered it?
   - What problem does it solve?
   - What does success look like?

   Adapt questions to what's already known from input materials. Skip questions already answered.

4. **Summarize understanding:**

   > Here's what I understand:
   > - **Core idea:** [summary]
   > - **Trigger:** [why now]
   > - **Problem:** [what it solves]
   > - **Success:** [desired outcome]
   >
   > Is this accurate?

**Gate G1:** User confirms understanding is accurate. Do NOT proceed until confirmed.

---

### Phase 3: Research

**CONDITIONAL:** Only if additional context would strengthen the concept.

**Goal:** Gather external or codebase context to inform reasoning

**Actions:**

1. **Assess research need** based on discussion so far.

2. **Ask user using AskUserQuestion:**

   **Question:** "Would additional research help strengthen this concept?"

   **Options:**
   | Option | Description |
   |--------|-------------|
   | **External research** | Market, competitors, technologies, best practices (uses researching skill) |
   | **Codebase exploration** | Explore existing code patterns, architecture, extension points |
   | **Both** | External research + codebase exploration |
   | **No research needed** | Enough context, proceed to reasoning |

3. **For external research — invoke researching skill:**
   ```
   Skill(skill="researching", args="{topic} --project={PROJECT}")
   ```
   - Wait for completion
   - Read the generated research file
   - Note file path for references

4. **For codebase exploration — launch code-explorer agent:**
   ```
   Task(
     subagent_type: "code-explorer",
     prompt: "Explore [target area] focusing on: existing patterns,
              architecture, similar features, extension points.
              Return findings relevant to [concept topic].",
     description: "Explore codebase for concept"
   )
   ```

5. **Synthesize findings:**
   > **Key findings relevant to this concept:**
   > - [Finding 1]
   > - [Finding 2]
   >
   > **What's now clearer:** [list]
   > **What remains unclear:** [list]

**Gate G2:** "Is this research sufficient, or should I dig deeper?"
- If more research needed — loop back with specific focus
- Suggest max 2-3 research rounds before proceeding

---

### Phase 4: Reason

**Goal:** Form opinions, explore options, and converge on a clear concept with the user

This is the core phase. The skill synthesizes everything gathered so far and actively reasons about the topic — not just reflecting back what the user said.

**Actions:**

1. **Present initial reasoning:**
   - Synthesize discussion + research into a coherent narrative
   - Identify 2-3 approaches or options where choices exist
   - For each option: describe trade-offs clearly
   - Recommend what feels like the best fit and explain why

2. **Iterate with user:**
   - User may challenge, redirect, or refine
   - Respond with updated reasoning — not just acknowledgment
   - Introduce new angles or considerations as they emerge
   - Use diagrams (ASCII) when they clarify relationships or flows

3. **Converge on structured summary:**

   When the concept feels clear, present:

   ```
   ## Concept Summary

   **Title:** [working title]
   **Problem:** [1-2 sentences]
   **Core Idea:** [1-2 sentences]

   **Key Components:**
   - [Component 1]: [purpose]
   - [Component 2]: [purpose]

   **Open Questions:**
   - [Question 1]
   - [Question 2]
   ```

**Gate G3:** "Is this ready to write up as a concept document?"
- Pass: proceed to Phase 5
- Fail: continue iterating

---

### Phase 5: Write & Save

**Goal:** Scaffold the concept document and save it

**Actions:**

1. **Generate filename:**
   - Pattern: `YYYYMMDD-concept-{title-slug}.md`

2. **Compose the document:**
   - Use the frontmatter format (see below)
   - Write explanatory prose, not just bullet points
   - Include diagrams where they clarify ideas
   - The document structure is flexible — use sections that fit the concept
   - Mark areas that need expansion with `<!-- ITERATE: [what to expand] -->`

3. **Save to `{KB_ROOT}/concepts/`**

4. **Present summary:**

   ```markdown
   ## Concept Scaffolded

   **Title:** {title}
   **File:** [{filename}]({KB_ROOT}/concepts/{filename})
   **Project:** {PROJECT}

   ### Areas to iterate on

   - {Area 1 marked for expansion}
   - {Area 2 marked for expansion}

   ### Iteration prompts

   To refine this concept in a follow-up session, try:
   - "Read {filepath} and expand the [section] section"
   - "Read {filepath} and add a diagram for [topic]"
   - "Read {filepath} and challenge the [decision]"
   ```

**Session complete.**

---

## Human Gates

| Gate | Phase | Question | Pass | Fail |
|------|-------|----------|------|------|
| G1 | Phase 2 | "Is this understanding accurate?" | Continue | Clarify |
| G2 | Phase 3 | "Is research sufficient?" | Continue | Research more |
| G3 | Phase 4 | "Ready to write up?" | Continue | Keep iterating |

---

## Output Format

### Frontmatter

```yaml
---
title: "{Concept Title}"
description: "{1-2 sentence summary of the concept (max 300 chars)}"
type: concept
status: draft
version: "1.0.0"
created: {YYYY-MM-DD}
updated: {YYYY-MM-DD}
author: skill::concept-writing
modified_by: skill::concept-writing
linear: ~
---
```

### Document Structure

The document structure is **flexible**. Use sections that fit the concept. Every concept document must include these three sections:

1. **Overview** — 2-3 sentence summary
2. **Problem Statement** — What problem this solves and for whom
3. **Core Idea** — The main concept explained clearly

Beyond these, add sections as the concept demands. Common sections include:

- **Background** — Context, triggers, current state
- **Key Components** — Major parts of the concept with purpose and responsibilities
- **User Experience** — Scenarios, flows, diagrams
- **Technical Considerations** — High-level architecture, dependencies, constraints
- **Alternatives Considered** — Other approaches and why they weren't chosen
- **Open Questions** — Unresolved items for iteration

**Guidelines:**
- Write explanatory prose — explain *why*, not just *what*
- Use ASCII diagrams for flows, architecture, and relationships
- Use Mermaid diagrams for complex sequences or state machines
- Mark incomplete areas with `<!-- ITERATE: [description] -->` comments
- Link to research files and brainstorm documents in a References section

---

## Rules

1. **Scaffold, not finish** — Produce a strong first draft with iteration markers
2. **No code changes** — This skill only produces documents
3. **No requirements-level detail** — That belongs in later stages
4. **Invoke researching skill for external research** — Never bypass to direct agent calls
5. **Frontmatter required** — Every output file must have valid frontmatter
6. **One question per message** — Keep interactions focused
7. **Respect all three gates** — Do not skip human approval checkpoints
8. **Flexible structure** — Adapt document sections to fit the concept, don't force rigid templates

