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
printf "${BOLD}${CYAN}  ║         MCP Server Template Setup                   ║${RESET}\n"
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
# Write a description that sells your server — up to 1,000 chars, indexed by Google,
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
#   - The title (was "Example MCP Server")
#   - The subtitle/description line
#   - The "What This Server Does" section (example-specific)
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
3. Deploy — mctx reads `package.json` for server configuration

mctx handles TLS, scaling, and uptime. You keep the code. Set your price and get paid when other developers use your server.

---

## Release Process

This project uses an automated release workflow with a main/release dual-branch model. See [RELEASE.md](RELEASE.md) for setup instructions.

---

## Learn More

- [`@mctx-ai/mcp-server`](https://github.com/mctx-ai/mcp-server) — Framework documentation and API reference
- [docs.mctx.ai](https://docs.mctx.ai) — Platform guides for deploying and managing MCP servers
- [mctx.ai](https://mctx.ai) — Host your MCP server for free
- [MCP Specification](https://modelcontextprotocol.io) — The protocol spec this server implements
README_EOF

# Substitute placeholders with actual values using perl (safe: no shell evaluation)
perl -i -pe "s/__PROJECT_NAME__/\Q${project_name}\E/g; s/__PROJECT_DESCRIPTION__/\Q${project_description}\E/g" "$readme"

success "README.md updated."

# ─── Replace src/index.ts (if keep-examples=n) ───────────────────────────────

if [ "$keep_examples" = "n" ]; then
  info "Replacing src/index.ts with minimal skeleton..."

  mkdir -p "$repo_root/src"

  cat > "$repo_root/src/index.ts" << 'INDEX_EOF'
/**
 * MCP Server
 *
 * Built with @mctx-ai/mcp-server. Add your tools, resources, and prompts below.
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
} from '@mctx-ai/mcp-server';

// ─── Server ──────────────────────────────────────────────────────────────────

const server = createServer({
  instructions:
    // TODO: Describe what your MCP server offers and how to use it.
    // This text is shown to LLM clients so they know what capabilities are available.
    'An MCP server. Update this description to tell clients what this server can do.',
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
// See https://github.com/mctx-ai/mcp-server for full API documentation.

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
  RELEASE.md
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

# ─── Done ─────────────────────────────────────────────────────────────────────

printf "\n"
printf "${BOLD}${GREEN}  Setup complete!${RESET}\n"
printf "\n"
info "Your project is ready. Next steps:"
info "  1. Review and update src/index.ts with your tools"
info "  2. Update README.md with your server's capabilities"
info "  3. Run 'npm run dev' to start the development server"
info "  4. Deploy at https://mctx.ai when ready"
info "  5. Set up your release workflow — see RELEASE.md"
printf "\n"
