---
name: clone-connector
description: Clone an existing Hyperswitch connector across backend, frontend, and deployment repos. Creates a fully working copy with systematic identifier renaming, registration, and configuration.
user-invocable: true
---

# Clone Connector

Clone an existing Hyperswitch payment connector to create a new connector that's a full working copy. The clone is identical in behavior — only names and identifiers change.

## Core Principles

- **Registry is the plan, codebase is ground truth** — Phase 0 validates the plan against reality before any changes
- **Scripts for mechanical work, Claude for structural edits** — Deterministic operations use shell scripts; context-aware edits use Claude's judgment
- **Phase-based execution with human gates** — 8 phases, 3 human gates, each phase independently runnable
- **Verify after every phase** — No phase proceeds without passing verification
- **Never run builds** — User runs cargo check and WASM builds manually at gate points

---

## Arguments

```
/clone-connector <source> <target> [--phase=N|N-M] [--backend=<path>] [--cc=<path>] [--deploy=<path>]
```

- `source` — Source connector module name (e.g., `indiapay`)
- `target` — Target connector module name (e.g., `indiapay_q`)
- `--phase=N` or `--phase=N-M` — Run specific phase(s) only (e.g., `--phase=2`, `--phase=2-4`)
- `--backend=`, `--cc=`, `--deploy=` — Explicit repo paths (auto-detected from CWD if in platro workspace)

If `source` or `target` not provided, ask via AskUserQuestion.

---

## Repo Path Detection

1. Check if CWD or CWD parent is `platro/` directory
2. If found, set:
   - `{BACKEND}` = `{PLATRO_ROOT}/platro-hs-backend`
   - `{CC}` = `{PLATRO_ROOT}/platro-hs-control-center`
   - `{DEPLOY}` = `{PLATRO_ROOT}/platro-base-deploy`
3. If not found, use explicit `--backend`, `--cc`, `--deploy` args
4. If still missing, ask via AskUserQuestion

---

## Naming Derivation

Given `source` and `target`, derive all identifier forms automatically:

| Form | Derivation | Example (indiapay → indiapay_q) |
|------|-----------|--------------------------------|
| `{src}` / `{tgt}` | As given | `indiapay` / `indiapay_q` |
| `{SrcPascal}` / `{TgtPascal}` | Capitalize first letter of each `_`-segment, join without `_` | `Indiapay` / `IndiapayQ` |
| `{SRC_UPPER}` / `{TGT_UPPER}` | Uppercase the module name | `INDIAPAY` / `INDIAPAY_Q` |
| `{SrcDisplay}` / `{TgtDisplay}` | **Ask user** — cannot be reliably derived | `IndiaPay` / `IndiaPay Q` |

**AskUserQuestion** for display names:

> Source display name: How is `{source}` displayed to users? (e.g., "IndiaPay", "Checkout", "Stripe")

> Target display name: How should `{target}` be displayed? (e.g., "IndiaPay Q", "Checkout V2")

---

## Scripts

Located at `${CLAUDE_PLUGIN_ROOT}/skills/clone-connector/scripts/`:

| Script | Purpose | Phase |
|--------|---------|-------|
| `clone-module.sh` | Copy connector module files + sed rename identifiers | 1 |
| `add-default-impls.sh` | Insert into 86+ macro lists in default_implementations files | 3 |
| `add-toml-base-urls.sh` | Insert base_url lines into 9 config TOML files | 3 |
| `verify-clone.sh` | Comprehensive cross-phase verification (32+ checks) | 8 |

Scripts are invoked with full paths:
```bash
${CLAUDE_PLUGIN_ROOT}/skills/clone-connector/scripts/<script>.sh <args>
```

---

## Workflow

Execute phases in order unless `--phase` restricts scope. Use `AskUserQuestion` for all user interaction.

---

### Phase 0: Prepare + Registry Validation

**Goal:** Discover source connector, validate registry against codebase, derive naming, get user approval.

**Actions:**

1. **Read the registry:** Read `{PLATRO_ROOT}/.claude/rules/connector-cloning.md`

2. **Discover source connector in codebase:** Run the discovery command from the registry across all three repos:
   ```bash
   # In each repo root (excluding target/, node_modules/, .git/):
   grep -rn '{src}' --include='*.rs' --include='*.toml' --include='*.res' --include='*.ts' --include='*.yaml' --include='*.svg' . | grep -v target/ | grep -v node_modules/ | grep -v .git/
   ```

3. **MANDATORY: Compare discovery vs registry.** For every file/pattern listed in the registry, verify the source connector actually appears there. Also check if discovery found files NOT in the registry.

   **If discrepancy found:**
   - Report exactly what's different (new files, missing files, changed patterns)
   - Conduct comprehensive analysis of what needs updating in registry and/or scripts
   - Present proposed changes via AskUserQuestion
   - If approved, update registry and/or scripts
   - Second gate: confirm registry is now aligned, get approval to start cloning

   **If no discrepancy:** Proceed to naming.

4. **Derive naming conventions** using the table above. Ask user for display names via AskUserQuestion.

5. **Verify target doesn't already exist:**
   ```bash
   grep -rl '{tgt}' {BACKEND}/crates/ --include='*.rs' | head -3
   ```
   If found, abort with error.

6. **Present summary and get approval:**

   > **Connector Clone Plan**
   > - Source: `{src}` → Target: `{tgt}`
   > - PascalCase: `{SrcPascal}` → `{TgtPascal}`
   > - Display: `{SrcDisplay}` → `{TgtDisplay}`
   > - UPPER: `{SRC_UPPER}` → `{TGT_UPPER}`
   > - Registry validation: PASSED (or: N discrepancies resolved)
   >
   > Ready to proceed?

**→ HUMAN GATE: User approves naming and plan**

---

### Phase 1: Backend Connector Module

**Goal:** Create cloned connector module files with renamed identifiers.

**Actions:**

1. Run the clone-module script:
   ```bash
   ${CLAUDE_PLUGIN_ROOT}/skills/clone-connector/scripts/clone-module.sh {BACKEND} {src} {tgt} {SrcPascal} {TgtPascal} "{SrcDisplay}" "{TgtDisplay}"
   ```

2. Script performs copy + sed rename + verification automatically.

3. If script exits non-zero, report errors and stop.

**Verification:** Script's built-in checks (zero stale refs, line counts match).

---

### Phase 2: Backend Registration

**Goal:** Register the new connector in all enum, dispatch, validation, and config files.

**Actions:** Follow registry sections 2a through 2l. For each sub-step:

1. Read the target file to find the exact location of the source connector entry
2. Use the Edit tool to insert the target entry immediately after the source
3. Verify with grep after each file

**Sub-steps (from registry):**

- **2a.** Connector enum (`common_enums/connector_enums.rs`) — variant + eligibility + auth support
- **2b.** PayoutConnectors (`api_models/enums.rs`) — **only if source is a payout connector** — variant + 3 conversion impls
- **2c.** RoutableConnectors (`euclid/enums.rs`) — variant + 2 conversion impls
- **2d.** Module declarations (`connectors.rs`) — `pub mod` + re-export
- **2e.** Router import (`router/connector.rs`) — use block
- **2f.** Feature matrix — match arm
- **2g.** Connector mapping — match arm
- **2h.** Connector transformers — match arm
- **2i.** Auth validation — match arm with AuthType
- **2j.** Config struct (`connector_configs/connector.rs`) — 2 fields + 2 match arms
- **2k.** Connector endpoints — struct field
- **2l.** Platro observability enum (`platro_observability/types.rs`) — variant + `as_str()` arm + `from_str()` arm. The new variant name is `{TgtDisplay}` with spaces removed (e.g., `"IndiaPay Q"` → `IndiaPayQ`). The module file (`{tgt}.rs`) uses this variant in the `const CONNECTOR: PlatroConnector = PlatroConnector::{TgtDisplayVariant};` declaration near line 67.

**Verification:**
```bash
grep -c '{TgtPascal}' crates/common_enums/src/connector_enums.rs   # expect 3
grep -c '{TgtPascal}' crates/api_models/src/enums.rs               # expect 4+
grep -c '{TgtPascal}' crates/euclid/src/enums.rs                   # expect 3+
grep '{tgt}' crates/hyperswitch_connectors/src/connectors.rs       # 2 lines
# ... verify each file
```

---

### Phase 3: Backend Defaults + TOMLs + Tests

**Goal:** Add to default implementations, TOML configs, and test infrastructure.

**Actions:**

1. **Default implementations** — run script:
   ```bash
   ${CLAUDE_PLUGIN_ROOT}/skills/clone-connector/scripts/add-default-impls.sh {BACKEND} {SrcPascal} {TgtPascal}
   ```

2. **TOML base URLs** — run script:
   ```bash
   ${CLAUDE_PLUGIN_ROOT}/skills/clone-connector/scripts/add-toml-base-urls.sh {BACKEND} {src} {tgt}
   ```

3. **Connector list in development.toml** — Edit tool: add `"{tgt}",` after `"{src}",`

4. **pm_filters** — Edit tool: copy `[pm_filters.{src}]` section as `[pm_filters.{tgt}]` in:
   - `config/development.toml`
   - `config/deployments/production.toml` (only if source has pm_filters there)

5. **Connector config TOMLs** — Edit tool: copy full `[{src}]` + `[{src}_payout]` sections as `[{tgt}]` + `[{tgt}_payout]` in:
   - `crates/connector_configs/toml/production.toml`
   - `crates/connector_configs/toml/development.toml`
   - `crates/connector_configs/toml/sandbox.toml`

6. **Test files** — Edit tool + copy:
   - Add `mod {tgt};` to `tests/connectors/main.rs`
   - Copy + rename test file `tests/connectors/{src}.rs` → `{tgt}.rs`
   - Add `pub {tgt}: Option<SignatureKey>,` to `connector_auth.rs`
   - Add `[{tgt}]` section to `sample_auth.toml`

**Verification:** Script outputs + grep counts for TOML sections and test entries.

---

### Phase 4: Backend Build

**Goal:** Confirm the backend compiles.

> The backend changes are complete. Please run cargo check:
> ```bash
> cargo check -p hyperswitch_connectors --features v1
> ```
> Or for a full check: `cargo check`
>
> Report back when the build passes (or fails).

**→ HUMAN GATE: User runs cargo check and confirms result**

If build fails, diagnose errors and fix before proceeding.

---

### Phase 5: Frontend

**Goal:** Register connector in Control Center UI.

**Actions:**

1. **ConnectorTypes.res** — Edit tool: add `| {TGT_UPPER}` after `| {SRC_UPPER}` in both `processorTypes` and `payoutProcessorTypes` enums

2. **ConnectorUtils.res** — Edit tool: 13 locations per registry section 5b (arrays, string mappings, display names, info objects)

3. **SVG icon** — Create `public/hyperswitch/assets/Gateway/{TGT_UPPER}.svg` (copy from source SVG, change display text)

**Verification:**
```bash
grep -c '{TGT_UPPER}' src/screens/Connectors/ConnectorTypes.res   # expect 2
grep -c '{TGT_UPPER}\|{tgt}' src/screens/Connectors/ConnectorUtils.res  # expect 13+
ls public/hyperswitch/assets/Gateway/{TGT_UPPER}.svg
```

---

### Phase 6: WASM + Frontend Build

**Goal:** Rebuild WASM connector configs and confirm frontend works.

> Frontend changes are complete. Please rebuild the WASM module:
> ```bash
> cd {BACKEND} && just euclid-wasm-override
> ```
> This builds the connector config WASM and copies it to the Control Center.
>
> Report back when the build passes.

**→ HUMAN GATE: User runs WASM build and confirms result**

---

### Phase 7: Deployment

**Goal:** Configure the new connector in platro-base-deploy for all environments.

**Actions:**

1. **7a. Templates** — Edit tool:
   - `server.template.toml`: add `{tgt}.base_url`
   - `emulator.template.toml`: add `[{tgt}.merchants]` Jinja2 block
   - `vars.secret.template.yaml`: add `{tgt}: merchants: {}` section

2. **7b. Merchant defaults** (`merchant-defaults.ts`) — Edit tool:
   - Add 4 connector entries (`{tgt}_payments_emulator`, `{tgt}_payments_real`, `{tgt}_payouts_emulator`, `{tgt}_payouts_real`)
   - Add 2 routing algorithms to the routing arrays (`rule_test_payments_{tgt_suffix}` + `rule_test_payouts_{tgt_suffix}`, both `active: false`)

3. **7c. Verify infrastructure** — Check that `config.ts` has `RoutingConfig[]` arrays with `active?: boolean` and `routing.ts` supports multiple algorithms. If not in place, implement per registry 7c instructions.

4. **7d. Per-environment configs** — Edit tool for each env (`local`, `dev`, `stage`, `prod`) + `setup.example.public.yaml`:
   - Add `connectors.{tgt}.polling` section
   - For each merchant: add 4 connector entries (2 payment + 2 payout)
   - For each merchant: add 2 routing algorithms (payment + payout, `active: false`)
   - **Preserve non-standard routing values** (copy exactly from source algorithm per merchant)

5. **7e. Per-environment secrets** — Edit tool:
   - Add `{tgt}: merchants: {...}` to each `vars.secret.yaml` (copy credentials from source)
   - Check `emulator.secrets.toml` if it exists

**Verification:**
```bash
python3 -c "import yaml; yaml.safe_load(open('{env}/server/setup.public.yaml')); print('VALID')"
# Run for each env
```

**→ HUMAN GATE: User reviews deployment configs and approves**

---

### Phase 8: Final Verification

**Goal:** Run comprehensive cross-repo verification.

**Actions:**

1. Run the verify script:
   ```bash
   ${CLAUDE_PLUGIN_ROOT}/skills/clone-connector/scripts/verify-clone.sh {BACKEND} {src} {tgt} {SrcPascal} {TgtPascal} {CC} {TGT_UPPER} {TgtDisplayVariant}
   ```

2. Report results. All checks must pass.

3. Present final summary:

   > **Connector Clone Complete**
   > - Source: `{src}` → Target: `{tgt}`
   > - Backend: {N} files modified, {M} files created
   > - Frontend: {N} files modified, 1 SVG created
   > - Deployment: {N} files modified
   > - Verification: {PASS}/{TOTAL} checks passed
   >
   > Next steps:
   > - Run `just local-server setup-init` to provision connectors locally
   > - Commit changes across all three repos
   > - Deploy to dev/stage/prod as needed

---

## Error Recovery

If any phase fails verification:

1. Report which specific checks failed with details
2. Ask user via AskUserQuestion: "Attempt to fix?" or "Abort?"
3. If fix: diagnose and correct, re-verify
4. If abort: report what was completed and what remains
5. Never auto-retry destructive operations (file writes, sed replacements)

## Files NOT Modified by This Skill

- `docs/*.md` — Documentation files (not required for functionality)
- `shared/setup/src/resources/routing.ts` — Generic infrastructure (verify 7c only)
- `shared/setup/src/types/config.ts` — Generic type definitions (verify 7c only)
- Build artifacts, compiled WASM, generated configs — user rebuilds at gate points
