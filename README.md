# Robooster Claude Configuration

Shared Claude Code skills and agents for the Robooster team.

---

## For Plugin Consumers (Team Members)

### Prerequisites

- Claude Code installed
- `GITHUB_TOKEN` environment variable with `repo` scope

### Initial Setup

**Step 1: Add the marketplace**

```bash
/plugin marketplace add https://github.com/roboosterai/robooster-claude.git
```

This clones the marketplace repository to `~/.claude/plugins/marketplaces/robooster-marketplace/`.

**Step 2: Install the plugin**

```bash
/plugin install robooster-claude@robooster-marketplace
```

This downloads the plugin to `~/.claude/plugins/cache/robooster-marketplace/robooster-claude/{version}/`.

**Step 3: Restart Claude Code**

The plugin is now active. Verify with `/plugin` → Installed tab.

### Updating the Plugin

When notified of a new plugin version:

**Step 1: Update the marketplace catalog**

```bash
/plugin marketplace update robooster-marketplace
```

Or use the UI: `/plugin` → Marketplaces → Select marketplace → Update marketplace

**Step 2: Update the plugin**

```bash
/plugin update robooster-claude@robooster-marketplace
```

**Step 3: Restart Claude Code**

### Enable Auto-Updates (Optional)

Add to your `~/.zshrc` or `~/.bashrc`:

```bash
export FORCE_AUTOUPDATE_PLUGINS=true
```

Then `source ~/.zshrc` and restart Claude Code. This automatically updates plugins at startup.

### Troubleshooting

| Issue | Solution |
|-------|----------|
| Plugin not updating | Run marketplace update first, then plugin update |
| "Marketplace not found" | Re-add with `/plugin marketplace add ...` |
| Auth errors | Verify `GITHUB_TOKEN` has `repo` scope |
| Old version still active | Restart Claude Code after updating |

---

## For Plugin Contributors (Developers)

### Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│  Plugin Source Repo (roboosterai/robooster-claude)          │
│  - Contains actual plugin code                              │
│  - Version defined in .claude-plugin/plugin.json            │
│  - Tagged releases (v1.0.0, v1.1.0, etc.)                   │
└─────────────────────────────────────────────────────────────┘
                              │
                              │ marketplace.json points here
                              ▼
┌─────────────────────────────────────────────────────────────┐
│  Marketplace Repo (same repo in our case)                   │
│  - .claude-plugin/marketplace.json catalogs available       │
│    plugins and their source locations                       │
│  - Consumers clone this to discover plugins                 │
└─────────────────────────────────────────────────────────────┘
                              │
                              │ consumers clone/pull
                              ▼
┌─────────────────────────────────────────────────────────────┐
│  Consumer's Local Cache                                     │
│  ~/.claude/plugins/                                         │
│  ├── marketplaces/robooster-marketplace/  (git clone)       │
│  └── cache/robooster-marketplace/robooster-claude/1.1.6/    │
└─────────────────────────────────────────────────────────────┘
```

### Publishing a New Version

**Step 1: Make your changes**

Edit skills, agents, hooks, or other plugin files.

**Step 2: Update the version**

Edit `.claude-plugin/plugin.json`:

```json
{
  "name": "robooster-claude",
  "version": "1.2.0",  // ← Increment this
  ...
}
```

**Step 3: Update marketplace catalog**

Edit `.claude-plugin/marketplace.json`:

```json
{
  "plugins": [
    {
      "name": "robooster-claude",
      "version": "1.2.0",  // ← Match the new version
      ...
    }
  ]
}
```

**Step 4: Commit and tag**

```bash
git add .
git commit -m "Release v1.2.0: description of changes"
git tag v1.2.0
git push origin main --tags
```

**Step 5: Notify team**

Tell team members to update:

```bash
/plugin marketplace update robooster-marketplace
/plugin update robooster-claude@robooster-marketplace
# Then restart Claude Code
```

### Version Strategy

- **Patch** (1.1.x): Bug fixes, typos, minor tweaks
- **Minor** (1.x.0): New skills/agents, new features
- **Major** (x.0.0): Breaking changes, renamed skills, removed features

### Key Files

| File | Purpose |
|------|---------|
| `.claude-plugin/plugin.json` | Plugin metadata and version |
| `.claude-plugin/marketplace.json` | Catalog for plugin discovery |
| `skills/*/SKILL.md` | Skill definitions |
| `agents/*.md` | Agent definitions |
| `hooks/hooks.json` | Hook configurations |
| `.mcp.json` | MCP server configurations |

### Testing Changes Locally

Before publishing, test your changes:

```bash
# Uninstall the marketplace version temporarily
/plugin uninstall robooster-claude@robooster-marketplace

# Install from local path for testing
/plugin install /path/to/robooster-claude
```

After testing, reinstall from marketplace.

---

## Contents

### Skills

- brainstorming
- researching
- conceptualizing-idea
- specifying-concept
- designing-architecture
- implementing-feature
- robooster-claude-updating — commits and pushes plugin changes with auto version bump

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
