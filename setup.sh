#!/usr/bin/env bash
# setup.sh — Template initialization script for example-mcp-server
#
# Run this once after creating a new repo from the GitHub template.
# It customizes the project name, description, and optionally strips
# example code so you start with a clean slate.
#
# Usage: ./setup.sh

set -euo pipefail

# ─── Colors ──────────────────────────────────────────────────────────────────

# Use tput if available, fall back to ANSI codes, fall back to no color
if command -v tput >/dev/null 2>&1 && tput setaf 1 >/dev/null 2>&1; then
  RED=$(tput setaf 1)
  GREEN=$(tput setaf 2)
  YELLOW=$(tput setaf 3)
  CYAN=$(tput setaf 6)
  BOLD=$(tput bold)
  RESET=$(tput sgr0)
else
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  YELLOW='\033[0;33m'
  CYAN='\033[0;36m'
  BOLD='\033[1m'
  RESET='\033[0m'
fi

# ─── Helpers ─────────────────────────────────────────────────────────────────

info() {
  printf "${CYAN}  %s${RESET}\n" "$*"
}

success() {
  printf "${GREEN}  %s${RESET}\n" "$*"
}

warn() {
  printf "${YELLOW}  %s${RESET}\n" "$*"
}

error() {
  printf "${RED}  ERROR: %s${RESET}\n" "$*" >&2
}

# Prompt with a default value shown in brackets.
# Usage: prompt_with_default "Question" "default value" result_var
prompt_with_default() {
  local question="$1"
  local default="$2"
  local var_name="$3"
  local input

  if [ -n "$default" ]; then
    printf "${BOLD}  %s${RESET} [%s]: " "$question" "$default"
  else
    printf "${BOLD}  %s${RESET}: " "$question"
  fi

  read -r input || true
  if [ -z "$input" ] && [ -n "$default" ]; then
    input="$default"
  fi
  printf -v "$var_name" '%s' "$input"
}

# ─── Trap Ctrl+C ─────────────────────────────────────────────────────────────

changes_started=false

cleanup() {
  printf "\n"
  if [ "$changes_started" = true ]; then
    warn "Setup interrupted. Some changes may have been made."
  else
    warn "Setup interrupted. No changes were made."
  fi
  exit 1
}

trap cleanup INT

# ─── Banner ───────────────────────────────────────────────────────────────────

printf "\n"
printf "${BOLD}${CYAN}  ╔══════════════════════════════════════════════════════╗${RESET}\n"
printf "${BOLD}${CYAN}  ║         App Template Setup                          ║${RESET}\n"
printf "${BOLD}${CYAN}  ╚══════════════════════════════════════════════════════╝${RESET}\n"
printf "\n"
info "This script customizes this template for your project."
info "It will update package.json, README.md, and optionally"
info "replace the example source code with a minimal skeleton."
printf "\n"
info "Press Ctrl+C at any time to cancel without making changes."
printf "\n"

# ─── Pre-flight checks ───────────────────────────────────────────────────────

if ! git rev-parse --git-dir >/dev/null 2>&1; then
  error "Not a git repository. Run this script from within a git repo."
  error "If you downloaded this template as a ZIP, initialize git first:"
  error "  git init && git remote add origin <your-repo-url>"
  exit 1
fi

# ─── Gather inputs ────────────────────────────────────────────────────────────

printf "${BOLD}  Project Details${RESET}\n"
printf "  ───────────────\n"

# Project name (required)
project_name=""
while [ -z "$project_name" ]; do
  prompt_with_default "Project name (npm package name)" "" project_name
  if [ -z "$project_name" ]; then
    error "Project name is required."
  fi
done

# Description (required)
# Write a description that sells your App — up to 1,000 chars, indexed by Google,
# front-load key capabilities for registry display (truncates at ~100-150 chars).
# Use action verbs and specific capabilities, not generic labels.
project_description=""
while [ -z "$project_description" ]; do
  prompt_with_default "Description" "" project_description
  if [ -z "$project_description" ]; then
    error "Description is required."
  fi
done

# Keep examples (optional, default: y)
keep_examples=""
prompt_with_default "Keep example code in src/index.ts?" "y" keep_examples
case "$keep_examples" in
  [Yy]|[Yy][Ee][Ss]|"") keep_examples="y" ;;
  [Nn]|[Nn][Oo])         keep_examples="n" ;;
  *)
    warn "Unrecognized input '$keep_examples' — defaulting to keep examples (y)."
    keep_examples="y"
    ;;
esac

printf "\n"

# Bot configuration for release workflow
printf "${BOLD}  Release Workflow Bot${RESET}\n"
printf "  ─────────────────────\n"
configure_bot=""
prompt_with_default "Do you want to configure a GitHub App bot for the release workflow?" "Y" configure_bot
case "$configure_bot" in
  [Nn]|[Nn][Oo]) configure_bot="n" ;;
  *)              configure_bot="y" ;;
esac

bot_name=""
if [ "$configure_bot" = "y" ]; then
  while [ -z "$bot_name" ]; do
    prompt_with_default "Bot name (e.g. my-bot)" "" bot_name
    if [ -z "$bot_name" ]; then
      error "Bot name is required."
    fi
  done
fi

printf "\n"

# CODEOWNERS setup
printf "${BOLD}  CODEOWNERS${RESET}\n"
printf "  ──────────\n"
codeowners_choice=""
prompt_with_default "Do you want to set up a CODEOWNERS file?" "N" codeowners_choice
case "$codeowners_choice" in
  [Yy]|[Yy][Ee][Ss]) codeowners_choice="y" ;;
  *)                  codeowners_choice="n" ;;
esac

codeowners_owner=""
if [ "$codeowners_choice" = "y" ]; then
  while [ -z "$codeowners_owner" ]; do
    prompt_with_default "GitHub username or team (e.g. @myorg/myteam or @username)" "" codeowners_owner
    if [ -z "$codeowners_owner" ]; then
      error "Owner is required."
    fi
  done
fi

printf "\n"

# ─── Confirm ──────────────────────────────────────────────────────────────────

printf "${BOLD}  Summary${RESET}\n"
printf "  ───────\n"
info "Name:        $project_name"
info "Description: $project_description"
if [ "$keep_examples" = "y" ]; then
  info "Examples:    Keep (src/index.ts unchanged)"
else
  info "Examples:    Replace with minimal skeleton"
fi
printf "\n"

confirm=""
prompt_with_default "Proceed?" "y" confirm
case "$confirm" in
  [Yy]|[Yy][Ee][Ss]|"") : ;;
  *)
    warn "Aborted by user. No changes made."
    exit 0
    ;;
esac

printf "\n"

# ─── Resolve script and repo root ────────────────────────────────────────────

script_path="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
repo_root="$(cd "$(dirname "$0")" && pwd)"

# ─── Update package.json ─────────────────────────────────────────────────────

changes_started=true
info "Updating package.json..."

package_json="$repo_root/package.json"

if command -v jq >/dev/null 2>&1; then
  # jq is available: precise JSON update
  tmp_file="$(mktemp)"
  jq \
    --arg name "$project_name" \
    --arg desc "$project_description" \
    '.name = $name | .description = $desc | .version = "0.1.0"' \
    "$package_json" > "$tmp_file"
  mv "$tmp_file" "$package_json"
else
  # jq not available: sed fallback (handles simple single-line values)
  warn "jq not found — using sed to update package.json."
  warn "Verify the result looks correct before committing."

  # Escape special characters for sed replacement
  escaped_name=$(printf '%s\n' "$project_name" | sed 's/[&/\]/\\&/g')
  escaped_desc=$(printf '%s\n' "$project_description" | sed 's/[&/\]/\\&/g')

  sed -i.bak1 "s|\"name\": \"[^\"]*\"|\"name\": \"$escaped_name\"|" "$package_json"
  sed -i.bak2 "s|\"description\": \"[^\"]*\"|\"description\": \"$escaped_desc\"|" "$package_json"
  sed -i.bak3 "s|\"version\": \"[^\"]*\"|\"version\": \"0.1.0\"|" "$package_json"
  rm -f "$package_json.bak1" "$package_json.bak2" "$package_json.bak3"
fi

success "package.json updated."

# ─── Update README.md ────────────────────────────────────────────────────────

info "Updating README.md..."

readme="$repo_root/README.md"

# Build the new README. We keep:
#   - The mctx logo and tagline (branding for the platform)
#   - The Quick Start section (still applies)
#   - The Deploy section (still applies)
#   - The Environment Variables section (still applies — users add their own)
#   - The Learn More section (framework docs are always relevant)
#
# We replace:
#   - The title (was "Example App")
#   - The subtitle/description line
#   - The "What This App Does" section (example-specific)
#   - The detailed tool/resource/prompt docs (example-specific)
#   - The "Prompt Ideas" section (example-specific)

# Write README with a quoted heredoc (no shell expansion) then substitute
# project_name and project_description using perl to avoid shell injection
# from backticks or $() in user-supplied values.
cat > "$readme" << 'README_EOF'
<img src="https://mctx.ai/brand/logo-purple.png" alt="mctx" width="120">

**Free MCP Hosting. Set Your Price. Get Paid.**

# __PROJECT_NAME__

__PROJECT_DESCRIPTION__

---

## Quick Start

```bash
npm install
npm run dev
```

The dev server runs esbuild in watch mode and hot-reloads via `mctx-dev` on every rebuild.

---

## Development

### Build
```bash
npm run build
```
Bundles `src/index.ts` → `dist/index.js` using esbuild (minified ESM output).

### Dev Server
```bash
npm run dev
```
Runs parallel watch mode:
- `dev:build` — esbuild watch (rebuilds on source changes)
- `dev:server` — mctx-dev hot-reloads server on rebuild

### Testing
```bash
# Run all tests
npm test

# Run tests in watch mode
npm test -- --watch
```

### Linting
```bash
npm run lint
```

### Formatting
```bash
# Format all files
npm run format

# Check formatting without modifying
npm run format:check
```

---

## Environment Variables

Add your environment variables here. Set them in the [mctx.ai dashboard](https://mctx.ai) when deployed — changes trigger a seamless automatic redeploy.

| Variable | Default | Description |
|---|---|---|
| _(none yet)_ | — | Add yours here |

---

## Deploy

1. Visit [mctx.ai](https://mctx.ai) and connect your repository
2. Set any environment variables in the dashboard
3. Deploy — mctx reads `package.json` for App configuration

mctx handles TLS, scaling, and uptime. You keep the code. Set your price and get paid when other developers use your App.

---

## Release Process

This project uses an automated release workflow with a main/release dual-branch model. See [RELEASE.md](RELEASE.md) for setup instructions.

---

## Learn More

- [`@mctx-ai/app`](https://github.com/mctx-ai/app) — Framework documentation and API reference
- [docs.mctx.ai](https://docs.mctx.ai) — Platform guides for deploying and managing your Apps
- [mctx.ai](https://mctx.ai) — Host your App for free
- [MCP Specification](https://modelcontextprotocol.io) — The protocol spec this App implements
README_EOF

# Substitute placeholders with actual values using perl (safe: no shell evaluation)
perl -i -pe "s/__PROJECT_NAME__/\Q${project_name}\E/g; s/__PROJECT_DESCRIPTION__/\Q${project_description}\E/g" "$readme"

success "README.md updated."

# ─── Write CLAUDE.md ─────────────────────────────────────────────────────────

info "Writing CLAUDE.md..."

cat > "$repo_root/CLAUDE.md" << 'CLAUDEMD_EOF'
# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

---

## What This Is

An **App** built with `@mctx-ai/mcp-server` framework. Exposes tools, resources, and prompts to AI clients over JSON-RPC 2.0.

**Purpose:** Provide capabilities that AI clients (Claude, Cursor, etc.) can invoke when connected to this App on the mctx platform.

---

## Post-Setup Checklist

Complete these steps after initializing the repository from the template.

### GitHub Secrets

Add the following secrets to the repository (Settings → Secrets and variables → Actions):

| Secret | Description |
|--------|-------------|
| `BOT_APP_ID` | GitHub App ID used by the release bot to push to protected branches |
| `BOT_PRIVATE_KEY` | Private key (PEM) for the GitHub App |

See `RELEASE.md` for full bot setup instructions, including how to create the GitHub App and configure branch protection. A PAT-based alternative is documented there as well.

### Branch Protection

Configure branch protection for `main` before merging any pull requests. The release pipeline requires push access via the bot app — see `RELEASE.md` for the required protection rule settings.

---

## Architecture

### High-Level Structure

```
src/index.ts        → App implementation (tools, resources, prompts)
  ├─ Tools          → Functions LLM clients can invoke
  ├─ Resources      → Data exposed via URIs
  ├─ Prompts        → Reusable message templates
  └─ Export         → Fetch handler for JSON-RPC 2.0 over HTTP

src/index.test.ts   → Tests for all capabilities
dist/index.js       → Bundled output (generated by esbuild)
```

### Framework Pattern

**Registration:** All capabilities (tools, resources, prompts) follow a decorator pattern:
1. Define handler function with specific signature
2. Attach metadata (`.description`, `.input`, `.mimeType`)
3. Register with server via `server.tool()`, `server.resource()`, or `server.prompt()`

**Handler signatures:**
- **ToolHandler:** `(args, ask?) => string | object | Promise<string | object>` — attach `.description`, `.input`, `.annotations`
- **GeneratorToolHandler:** `function* (args) { yield progress; return result; }` — attach `.description`, `.input`, `.annotations`
- **ResourceHandler:** `(params) => string` — attach `.description`, `.mimeType`
- **PromptHandler:** `(args) => string | conversation(...)` — attach `.description`, `.input`

**LLM Sampling (`ask`):** The optional `ask` parameter in ToolHandler lets your tool request the connected LLM client to generate text. Use it when a tool needs AI reasoning as part of its execution — e.g., summarizing fetched content, classifying input, or generating a response based on retrieved data. The `ask` function sends a prompt to the client and returns the LLM's response as a string.

**Schema system:** The `T` namespace provides type-safe schema builders (`.string()`, `.number()`, `.boolean()`, etc.) with validation constraints.

### Tool Annotations

MCP clients use annotation hints to decide how to present permission prompts and safety warnings to end users. Set them on any `ToolHandler` or `GeneratorToolHandler` via the `.annotations` property after defining the handler function.

**The four hints:**

| Hint | Type | Default | Meaning |
|---|---|---|---|
| `readOnlyHint` | `boolean` | `false` | Tool only reads data — no state changes. Clients may suppress or soften the permission prompt. |
| `destructiveHint` | `boolean` | `true` | Tool may destroy or permanently alter data. Clients may show a stronger warning. |
| `openWorldHint` | `boolean` | `true` | Tool reaches outside the server (network requests, filesystem, external APIs). Clients may flag external access. |
| `idempotentHint` | `boolean` | `false` | Calling the tool multiple times with the same arguments produces no additional side effects after the first call. Clients may safely retry. |

Defaults are pessimistic — if you don't set them, clients assume worst case (destructive, non-idempotent, open-world). Always set annotations explicitly.

`destructiveHint` and `idempotentHint` are only semantically meaningful when `readOnlyHint` is `false`. For read-only tools, omit them or expect clients to ignore them.

Hints are advisory — they inform the client UI but do not enforce behavior in the server.

**Decorator pattern:**

```typescript
const myTool: ToolHandler = (args) => { /* ... */ };
myTool.description = 'Does something useful';
myTool.input = { query: T.string({ required: true }) };
myTool.annotations = { readOnlyHint: true };  // ← attach after other metadata
server.tool('my-tool', myTool);
```

**Generator tool example** (yields progress, returns final result):

```typescript
const processData: GeneratorToolHandler = function* (args) {
  const { items } = args as { items: string[] };
  for (let i = 0; i < items.length; i++) {
    yield { progress: i + 1, total: items.length };
  }
  return `Processed ${items.length} items`;
};
processData.description = 'Processes a list of items with progress reporting';
processData.input = { items: T.array(T.string(), { required: true }) };
server.tool('process-data', processData);
```

**Sampling tool example** (calls the connected LLM via `ask`):

```typescript
const summarize: ToolHandler = async (args, ask) => {
  const { text } = args as { text: string };
  const summary = await ask!(`Summarize this in one sentence: ${text}`);
  return summary;
};
summarize.description = 'Summarizes text using the connected LLM';
summarize.input = { text: T.string({ required: true }) };
server.tool('summarize', summarize);
```

**Decision checklist — choose the right profile:**

1. Does the tool write, delete, or modify anything? If no → set `readOnlyHint: true`.
2. Is a write irreversible or data-destroying? If yes → set `destructiveHint: true`.
3. Does the tool call an external service, make a network request, or read from the filesystem? If yes → set `openWorldHint: true`.
4. Can the tool be safely retried with identical arguments? If yes → set `idempotentHint: true`.

### Entry Point

`createServer()` initializes an App instance. The returned `server.fetch` property is a Web Standard Fetch API handler compatible with:
- Cloudflare Workers
- Deno Deploy
- Node.js with adapters
- mctx hosting platform

The handler processes JSON-RPC 2.0 requests over HTTP.

### Channel Events (One-Way Push Notifications)

Channel events let your server push one-way notifications into the connected Claude Code session without requiring the client to poll. They are delivered in real-time on the mctx platform, and no-op silently in local development and HTTP transport.

**Handler signature:** All handlers (tools, resources, prompts) receive a `ctx` object as the final parameter:

```typescript
// ToolHandler
(args, ask?, ctx?) => string | object | Promise<string | object>

// ResourceHandler
(params, ctx?) => string

// PromptHandler
(args, ctx?) => string | conversation(...)
```

**The ctx object includes:**
- **`ctx.userId`** — The authenticated mctx user identifier (opaque string, stable across sessions)
- **`ctx.emit(message, options)`** — Push a channel event into the connected session
  - **`message`** — Human-readable text describing the event
  - **`options.eventType`** — A label categorizing the event (e.g., `'task-started'`, `'alert'`, `'progress'`)
  - **`options.meta`** — An object with custom metadata (keys must match `/^[a-zA-Z0-9_]+$/`; hyphens are silently dropped by Claude Code)

**Important behaviors:**

- **No blocking:** `ctx.emit()` is fire-and-forget. It runs via `ctx.waitUntil()` and does not block the tool response. Your handler returns immediately; the event dispatches asynchronously.
- **No-op in local dev:** When MCTX environment variables are absent (local development, HTTP transport, or non-authenticated requests), `ctx.emit()` silently no-ops. Your handler continues normally without errors.
- **Side-effect pattern:** Typically, `ctx.emit()` is a side-effect fired from within other tools. Dedicated event-pushing tools are less common but are a valid pattern.

**Example: Emit as a side-effect**

```typescript
const processItem: ToolHandler = (args, _ask, ctx) => {
  const { id } = args as { id: string };

  // emit is fire-and-forget — runs async, does not block the response
  if (ctx) {
    ctx.emit(`Processed item ${id}`, {
      eventType: 'item-processed',
      meta: { item_id: id },
    });
  }

  return { processed: true, id };
};
processItem.annotations = {
  readOnlyHint: false,      // side-effect via emit()
  destructiveHint: false,
  openWorldHint: true,      // emit() calls mctx events API (external endpoint)
  idempotentHint: true,
};
```

**Meta key constraint:** Keys in the `meta` object must match the regex `/^[a-zA-Z0-9_]+$/`. Hyphens and other special characters are silently dropped by Claude Code's event handler. Keep meta keys simple and alphanumeric.

**When to use channel events:**
- Progress notifications independent of tool returns (e.g., "Task started", "Checkpoint reached")
- Asynchronous alerts or status updates
- User-facing feedback from long-running operations
- Analytics or audit events logged as side-effects

**When NOT to use channel events:**
- If the information belongs in the tool's return value (use structured returns instead)
- If clients need to act on the information synchronously (use `ask` for LLM sampling instead)
- If delivery guarantee is critical (channel events are best-effort; use a durable message queue if atomicity is required)

---

## Two-Audience Model

Content in this repository serves two distinct audiences. Understanding which audience each artifact targets determines how to write it.

### instructions — Audience: AI clients

The `instructions` field passed to `createServer()` (or set in `package.json`) is sent to AI clients such as Claude and Cursor when they connect to this App. Its purpose is to help the AI decide what this App covers and when to call its tools. Setting instructions in code via `createServer()` takes precedence over the `instructions` field in `package.json`.

Write instructions for a machine that needs clear routing signals:
- Name every tool and describe what each one does
- Name every resource URI pattern
- Be explicit about capabilities and constraints
- Concise is better than comprehensive — the AI will learn tool details from the schema

### README.md — Audience: Human subscribers

`README.md` is displayed on the App's public mctx page as the subscriber-facing product page. People evaluating whether to subscribe to this App, or current subscribers looking for usage guidance, read this file.

Write the README for humans who want to understand what the App offers and how to use it:
- Lead with the value proposition
- Explain use cases in plain language
- Include examples that show real-world benefit

### description in package.json — App info and registry

The `description` field appears on the App's mctx info page and in the MCP Community Registry. It is the one-liner that represents this App in listings and search results. Write it to be informative and scannable at a glance.

---

## package.json Fields

mctx reads specific fields from `package.json` to configure and identify your App. Know what each field controls.

**Required fields:**

| Field | Purpose |
|-------|---------|
| `name` | App display name shown in the mctx dashboard and sent to AI clients as the App identifier |
| `version` | Triggers a new mctx deployment when it changes on a push |
| `description` | Shown on the App info page and MCP Community Registry |
| `main` | Path to the built JS file mctx serves (`dist/index.js`) |

**Important type field:**

| Field | Value | Purpose |
|-------|-------|---------|
| `type` | `"module"` | Required for ESM — the framework uses ES module syntax |

**Optional fields:**

| Field | Purpose |
|-------|---------|
| `instructions` | AI client guidance — alternative to setting it in code via `createServer()` (see [Two-Audience Model](#two-audience-model) for precedence rule). |

---

## Common Development Commands

### Build
```bash
npm run build
```
Bundles `src/index.ts` → `dist/index.js` using esbuild (minified ESM output).

### Development
```bash
npm run dev
```
Runs parallel watch mode:
- `dev:build` — esbuild watch (rebuilds on source changes)
- `dev:server` — mctx-dev hot-reloads server on rebuild

**Test environment variables during dev:**
```bash
MY_VAR="value" npm run dev
```

### Testing
```bash
# Run all tests
npm test

# Run tests in watch mode
npm test -- --watch

# Run specific test file
npm test src/index.test.ts

# Run tests matching pattern
npm test -- -t "tool name"
```

Tests use Vitest (no separate config file — runs via `vitest run` in package.json). Each test creates a `Request` object, calls `server.fetch()`, and validates the JSON-RPC response.

### Linting
```bash
# Check for issues
npm run lint

# Lint specific file
npx eslint src/index.ts
```

Uses ESLint 9 with TypeScript plugin and Prettier integration (via `eslint-config-prettier`).

### Formatting
```bash
# Format all files
npm run format

# Check formatting without modifying
npm run format:check
```

Prettier configuration: `singleQuote: true`, `printWidth: 100` (in `.prettierrc`).

---

## Environment Variables

Apps read configuration from environment variables at runtime. Define variables in `src/index.ts` using `process.env`:

```typescript
const myValue = process.env.MY_VARIABLE || 'default-value';
```

**In local development:** Pass variables inline with `npm run dev`:
```bash
MY_VARIABLE="custom" npm run dev
```

**In production:** Set variables in the mctx dashboard under App settings. mctx injects them into the runtime environment at deploy time.

Document every variable your App reads in this section so operators know what to configure.

---

## Testing Patterns

### JSON-RPC Helper Functions

**`createRequest(method, params)`** — Creates a `Request` object with proper JSON-RPC 2.0 structure:
```typescript
{
  jsonrpc: '2.0',
  id: 1,
  method: 'tools/call',
  params: { name: 'my-tool', arguments: { query: 'example' } }
}
```

**`getResponse(response)`** — Parses JSON-RPC response from `Response` object.

### Test Structure

Tests organized by capability type:
- **Tools** — Invoke via `tools/call`, validate `result.content[0].text`
- **Resources** — Read via `resources/read`, validate `result.contents[0].text` and `mimeType`
- **Prompts** — Get via `prompts/get`, validate `result.messages[]` array structure
- **Server Capabilities** — List via `tools/list`, `resources/list`, `prompts/list`

Error handling tests verify `result.isError === true` and error message content.

---

## Deployment Model

**mctx does not run build commands.** It serves whatever `dist/index.js` exists on the `release` branch — it never executes `npm run build` or any equivalent at deploy time.

**`dist/` is gitignored on `main`.** Developers never commit build output. The release pipeline (see [Release Pipeline](#release-pipeline)) builds `dist/index.js` from source and commits it to the `release` branch automatically. This keeps `main` clean — only source code lives there.

**Deployment trigger:** mctx deploys from the `release` branch. It watches for version changes in `package.json` on that branch. When the `version` field changes on a push to `release`, mctx starts a new deployment automatically. A push with no version bump does not trigger deployment, even if `dist/index.js` changed.

**Constraints:** Do not edit the `release` branch directly — it is fully managed by CI. Do not commit `dist/index.js` on `main` — the `.gitignore` excludes it. Do not expect mctx to run `npm install`, `npm run build`, or any other build step at deploy time.

---

## Release Pipeline

**Dual-branch model:** `main` (development) → `release` (production). The `release` branch is fully managed by CI — never edit it directly. All changes flow through `main` via pull request.

Pushing to `main` triggers `release.yml` — the **only path** where `dist/index.js` gets committed. It:
1. Builds `dist/index.js` from source
2. Computes a combined SHA-256 hash across `dist/index.js`, `package.json`, and `README.md`, then compares to `.release-hash` on `release` — exits early if unchanged (no runtime changes)
3. Determines version bump from commit message using conventional commits (see below)
4. Pushes build, updated `package.json`, `README.md`, and `.release-hash` to `release`
5. Creates a GitHub Release tagged at the new version
6. Bumps `package.json` version on `main` with a `[skip ci]` commit

### Conventional Commits

Version bumps are determined automatically from the commit message on `main`:

| Commit prefix | Version bump | Example |
|---------------|-------------|---------|
| `feat!:` or `fix!:` | **Major** | `feat!: redesign tool API` |
| `feat:` | **Minor** | `feat: add new resource` |
| Everything else | **Patch** | `fix: handle edge case`, `chore: update deps` |

**This repo uses squash merging.** PR title becomes the commit subject, PR description becomes the commit body. Therefore, **PR titles must follow conventional commit format** — enforced by the `pr-title.yml` workflow.

### Manual Version Bumps

The `admin/version` script allows manual version bumps (admin-only — requires branch protection bypass):

```bash
./admin/version              # Show current version
./admin/version patch        # 1.2.3 → 1.2.4
./admin/version minor        # 1.2.3 → 1.3.0
./admin/version major        # 1.2.3 → 2.0.0
./admin/version 2.0.0        # Set explicit version
./admin/version patch --push  # Bump and push both branches
```

The script updates `package.json`, runs `npm install` to sync `package-lock.json`, and commits both independently on `main` and `release` to avoid merge conflicts. Must be run from `main` with a clean working tree. See `RELEASE.md` for full setup details (GitHub App, branch protection, PAT alternative).

---

## CI Checks on Pull Requests

PRs to `main` run several automated checks:

- **test.yml** — `npm ci` + `npm test` (Node 22)
- **check-dist.yml** — Rebuilds `dist/` from source to verify the build succeeds. Since `dist/` is gitignored on `main`, this check validates that source changes produce a clean build — not that a committed `dist/index.js` matches. The actual `dist/index.js` commit happens on the `release` branch via the release pipeline.
- **pr-title.yml** — Validates PR title follows conventional commit format
- **pr-comment.yml** — Posts a comment explaining squash merge behavior and version bump rules

---

## GitHub Actions Security

**ALL GitHub Actions MUST be SHA-pinned. NO EXCEPTIONS.**

Reference actions by full commit SHA, never by tag or branch name. Tags are mutable and can be force-pushed to point to malicious code — SHA pinning prevents supply chain attacks and guarantees reproducibility.

### Examples

❌ **WRONG - Tag references:**
```yaml
uses: actions/checkout@v4
uses: actions/setup-node@v4
```

✅ **CORRECT - SHA-pinned with version comment:**
```yaml
uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683 # v4.2.2
uses: actions/setup-node@39370e3970a6d050c480ffad4ff0ed4d3fdee5af # v4.1.0
```

Always include a trailing `# <version-tag>` comment — SHA alone is opaque. Format: `uses: owner/repo@<full-sha> # <version-tag>`

### Finding SHAs

Use `git ls-remote` with `^{}` dereference to get the commit SHA (not the tag object SHA, which is what annotated tags return without dereference):

```bash
# Dereference annotated tag to commit SHA
git ls-remote https://github.com/actions/checkout.git refs/tags/v4.2.2^{}
# Returns: 11bd71901bbe5b1630ceea73d27597364c9af683  refs/tags/v4.2.2^{}
```

### Enforcement

All workflow files in `.github/workflows/` must comply. PRs with tag-based action references will be rejected.
CLAUDEMD_EOF

success "CLAUDE.md written."

# ─── Replace src/index.ts (if keep-examples=n) ───────────────────────────────

if [ "$keep_examples" = "n" ]; then
  info "Replacing src/index.ts with minimal skeleton..."

  mkdir -p "$repo_root/src"

  cat > "$repo_root/src/index.ts" << 'INDEX_EOF'
/**
 * App
 *
 * Built with @mctx-ai/app. Add your tools, resources, and prompts below.
 *
 * Framework patterns:
 *   - Tools      → functions LLM clients can invoke
 *   - Resources  → data exposed via URIs
 *   - Prompts    → reusable message templates
 *
 * Docs: https://github.com/mctx-ai/mcp-server
 */

import {
  createServer,
  T,
  log,
  type ToolHandler,
} from '@mctx-ai/app';

// ─── Server ──────────────────────────────────────────────────────────────────

const server = createServer({
  instructions:
    // TODO: Describe what your App offers and how to use it.
    // This text is shown to LLM clients so they know what capabilities are available.
    'An App. Update this description to tell clients what this App can do.',
});

// ─── Tools ───────────────────────────────────────────────────────────────────
//
// Tools are functions that LLM clients can invoke.
// Each tool needs: a handler function, a description, and an input schema.
//
// Handler signature: (args, ask?) => string | object | Promise<string | object>
//
// TODO: Replace this example tool with your own.

const hello: ToolHandler = (args) => {
  const { name } = args as { name: string };

  log.info(`Saying hello to ${name}`);

  return `Hello, ${name}!`;
};
hello.description = 'Says hello to a person by name';
hello.input = {
  name: T.string({
    required: true,
    description: 'Name to greet',
    minLength: 1,
    maxLength: 100,
  }),
};
server.tool('hello', hello);

// TODO: Add more tools, resources, and prompts here.
// See https://github.com/mctx-ai/app for full API documentation.

// ─── Export ──────────────────────────────────────────────────────────────────
//
// The fetch handler processes JSON-RPC 2.0 requests over HTTP.
// Compatible with Cloudflare Workers and mctx hosting.

export default { fetch: server.fetch };
INDEX_EOF

  success "src/index.ts replaced with minimal skeleton."

  info "Replacing src/index.test.ts with minimal test skeleton..."

  cat > "$repo_root/src/index.test.ts" << 'TEST_EOF'
import { describe, test, expect } from 'vitest';
import server from './index.js';

// Helper to create JSON-RPC 2.0 request
function createRequest(method: string, params: Record<string, unknown> = {}) {
  return new Request('http://localhost', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      jsonrpc: '2.0',
      id: 1,
      method,
      params,
    }),
  });
}

// Helper to parse JSON-RPC response
async function getResponse(response: Response) {
  const data = await response.json();
  return data;
}

// ─── Tools Tests ────────────────────────────────────────────────────

describe('Tool: hello', () => {
  test('should greet a person by name', async () => {
    const req = createRequest('tools/call', {
      name: 'hello',
      arguments: { name: 'Alice' },
    });
    const res = await server.fetch(req);
    const data = await getResponse(res);

    expect(data.result.content[0].text).toBe('Hello, Alice!');
  });

  test('should handle different names', async () => {
    const req = createRequest('tools/call', {
      name: 'hello',
      arguments: { name: 'Bob' },
    });
    const res = await server.fetch(req);
    const data = await getResponse(res);

    expect(data.result.content[0].text).toBe('Hello, Bob!');
  });
});

// ─── Server Capabilities Tests ─────────────────────────────────────

describe('Server capabilities', () => {
  test('should list the hello tool', async () => {
    const req = createRequest('tools/list');
    const res = await server.fetch(req);
    const data = await getResponse(res);

    const toolNames = data.result.tools.map((t: { name: string }) => t.name);
    expect(toolNames).toContain('hello');
  });
});
TEST_EOF

  success "src/index.test.ts replaced with minimal test skeleton."
fi

# ─── Remove mctx-specific GitHub Actions workflows ───────────────────────────

info "Removing mctx-specific GitHub Actions workflows..."
rm -f \
  "$repo_root/.github/workflows/pr-comment.yml" \
  "$repo_root/.github/workflows/pr-title.yml" \
  "$repo_root/.github/workflows/dependabot-auto-merge.yml"
success "mctx-specific workflows removed."

# ─── Configure release workflow bot ──────────────────────────────────────────

release_yml="$repo_root/.github/workflows/release.yml"

if [ "$configure_bot" = "n" ]; then
  # Replace secret names with generic ones and use a placeholder bot name
  sed -i.bak "s/MCTX_BOT_APP_ID/BOT_APP_ID/g; s/MCTX_BOT_PRIVATE_KEY/BOT_PRIVATE_KEY/g; s/mctx-bot\[bot\]/your-bot[bot]/g" "$release_yml"
  rm -f "$release_yml.bak"
  warn "Skipped bot configuration. Update 'your-bot[bot]' in .github/workflows/release.yml and set BOT_APP_ID / BOT_PRIVATE_KEY secrets before using the release workflow."
else
  escaped_bot_name=$(printf '%s\n' "$bot_name" | sed 's/[&/\]/\\&/g')
  sed -i.bak "s/MCTX_BOT_APP_ID/BOT_APP_ID/g; s/MCTX_BOT_PRIVATE_KEY/BOT_PRIVATE_KEY/g; s/mctx-bot\[bot\]/${escaped_bot_name}[bot]/g" "$release_yml"
  rm -f "$release_yml.bak"
  success "release.yml configured with bot '${bot_name}[bot]' and generic secret names (BOT_APP_ID / BOT_PRIVATE_KEY)."
fi

# ─── CODEOWNERS handling ──────────────────────────────────────────────────────

if [ "$codeowners_choice" = "y" ]; then
  printf '* %s\n' "$codeowners_owner" > "$repo_root/CODEOWNERS"
  success "CODEOWNERS created with owner: $codeowners_owner"
else
  rm -f "$repo_root/CODEOWNERS"
  success "CODEOWNERS removed."
fi

# ─── Strip homepage from package.json ────────────────────────────────────────

info "Removing homepage field from package.json..."

if command -v jq >/dev/null 2>&1; then
  # jq is available: precise JSON update
  tmp_file="$(mktemp)"
  jq 'del(.homepage)' "$package_json" > "$tmp_file"
  mv "$tmp_file" "$package_json"
else
  # jq not available: sed fallback
  warn "jq not found — using sed to remove homepage from package.json."
  warn "Verify the result looks correct before committing."
  sed -i.bak3 '/"homepage":/d' "$package_json"
  rm -f "$package_json.bak3"
fi

success "homepage field removed from package.json."

# ─── npm install ──────────────────────────────────────────────────────────────

info "Running npm install..."
npm install --prefix "$repo_root" --loglevel=error
success "Dependencies installed."

# ─── Initial git commit ───────────────────────────────────────────────────────

info "Staging changes and creating initial commit..."

# Remove this script before committing
rm -f "$script_path"

# Stage modified and new files this script touched
git -C "$repo_root" add \
  package.json \
  package-lock.json \
  README.md \
  CLAUDE.md
if [ -f "$repo_root/RELEASE.md" ]; then
  git -C "$repo_root" add RELEASE.md
fi
if [ "$keep_examples" = "n" ]; then
  git -C "$repo_root" add src/index.ts src/index.test.ts
fi

# Stage deletions: removed workflows and this setup script.
# --ignore-unmatch handles files that may not exist in all template forks.
git -C "$repo_root" rm --cached --ignore-unmatch \
  .github/workflows/pr-comment.yml \
  .github/workflows/pr-title.yml \
  .github/workflows/dependabot-auto-merge.yml \
  setup.sh \
  >/dev/null 2>&1 || true

# Stage the updated release workflow
git -C "$repo_root" add .github/workflows/release.yml

# Stage CODEOWNERS: either the new file (user opted in) or its deletion (user opted out).
if [ -f "$repo_root/CODEOWNERS" ]; then
  git -C "$repo_root" add CODEOWNERS
else
  git -C "$repo_root" rm --cached --ignore-unmatch CODEOWNERS >/dev/null 2>&1 || true
fi

git -C "$repo_root" commit -m "Initial project setup from template"

success "Initial commit created."

# ─── Create release branch ────────────────────────────────────────────────────

info "Creating release branch..."

release_branch_pushed=false
original_branch=$(git -C "$repo_root" rev-parse --abbrev-ref HEAD)

if git -C "$repo_root" show-ref --verify --quiet refs/heads/release; then
  warn "Local release branch already exists — skipping creation."
else
  git -C "$repo_root" checkout -b release

  if git -C "$repo_root" ls-remote --exit-code origin release >/dev/null 2>&1; then
    warn "Remote release branch already exists on origin."
    warn "If this is from a previous setup run, you may need to delete it first:"
    warn "  git push origin --delete release"
  else
    if git -C "$repo_root" push -u origin release; then
      release_branch_pushed=true
      success "release branch created and pushed to origin."
    else
      warn "Could not push release branch to origin (no remote, no auth, or remote not configured)."
      warn "Create it manually when ready:"
      warn "  git checkout release"
      warn "  git push -u origin release"
      warn "  git checkout $original_branch"
    fi
  fi

  git -C "$repo_root" checkout "$original_branch"
fi

# ─── Done ─────────────────────────────────────────────────────────────────────

printf "\n"
printf "${BOLD}${GREEN}  Setup complete!${RESET}\n"
printf "\n"
printf "${BOLD}  What's automated vs. what you still need to do:${RESET}\n"
printf "  ────────────────────────────────────────────────\n"
printf "\n"

printf "${BOLD}  Automated (done for you):${RESET}\n"
info "  - package.json configured with name, description, and version 0.1.0"
info "  - README.md initialized for your project"
info "  - CLAUDE.md written with framework guidance"
info "  - release.yml configured with your bot name and secret names"
if [ "$release_branch_pushed" = true ]; then
  info "  - release branch created and pushed"
else
  info "  - release branch created locally (push pending — see manual steps below)"
fi
printf "\n"

printf "${BOLD}  Manual steps required:${RESET}\n"
printf "\n"
if [ "$release_branch_pushed" = false ]; then
  warn "  1. Push the release branch:"
  warn "       git checkout release"
  warn "       git push -u origin release"
  warn "       git checkout main"
  printf "\n"
fi
info "  GitHub Secrets — add to Settings > Secrets and variables > Actions:"
info "    BOT_APP_ID     — GitHub App ID for the release bot"
info "    BOT_PRIVATE_KEY — Private key (PEM) for the GitHub App"
printf "\n"
info "  Branch protection — configure for both main and release:"
info "    - Require pull request reviews before merging"
info "    - Add your bot as a bypass actor so CI can push to release"
info "    - See RELEASE.md for exact settings"
printf "\n"
info "  See RELEASE.md for full release pipeline setup instructions"
info "  (GitHub App creation, branch protection rules, PAT alternative)."
printf "\n"

printf "${BOLD}  Start developing:${RESET}\n"
info "  npm run dev                   — start the dev server"
info "  npm test                      — run the test suite"
info "  Visit https://mctx.ai         — connect your repo and deploy"
printf "\n"
