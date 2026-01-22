# Robooster Claude Configuration

Shared Claude Code skills and agents for the Robooster team.

## Installation

Requires `GITHUB_TOKEN` environment variable with `repo` scope.

```bash
/plugin marketplace add https://github.com/roboosterai/robooster-claude.git
/plugin install robooster-claude@robooster-marketplace
```

## Updating

```bash
/plugin update robooster-claude@robooster-marketplace
```

## Contents

### Skills

- brainstorming
- researching
- conceptualizing-idea
- specifying-concept
- designing-architecture
- implementing-feature

### Agents

- web-researcher
- code-explorer
- xml-comments-writer
- test-verifier
- code-reviewer
- test-writer
- kb-maintainer
- task-manager

### Hooks

- **KB Auto-Sync** - Automatically commits and pushes KB files after edits
  - Triggers on: Write, Edit operations
  - Paths synced: `*/platro-kb/*`, `*/kb/*`
  - Strategy: commit → pull --rebase → push
  - Errors are non-blocking (won't interrupt your workflow)

#### Troubleshooting

| Issue               | Solution                                                |
| ------------------- | ------------------------------------------------------- |
| Sync not triggering | Verify plugin is enabled via `/hooks` menu              |
| Push fails          | Check SSH key or credential helper is configured        |
| Rebase conflict     | Manual resolution needed - run `git status` in KB repo  |
| jq not found        | Install jq: `brew install jq`                           |
