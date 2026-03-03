<img src="https://mctx.ai/brand/logo-purple.png" alt="mctx" width="120">

**Free MCP Hosting. Set Your Price. Get Paid.**

# Example MCP Server

A GitHub template for building MCP servers with [`@mctx-ai/mcp-server`](https://github.com/mctx-ai/mcp-server). Clone it, run one script, and you have a working server ready to develop and deploy.

---

## Quick Start

**1. Create your repo from this template**

Click **Use this template** on GitHub, then clone your new repo:

```bash
git clone https://github.com/your-username/your-repo.git
cd your-repo
```

**2. Run the setup script**

```bash
./setup.sh
```

**3. Start developing**

```bash
npm run dev
```

---

## What You Get

- **Build tooling** — esbuild bundler with watch mode and hot reload via `mctx-dev`
- **Test suite** — Vitest with JSON-RPC 2.0 helpers ready to use
- **Linting and formatting** — ESLint 9 with TypeScript plugin and Prettier
- **CI/CD pipeline** — GitHub Actions workflow for automated testing and deployment
- **Example MCP server** — Working implementation of every framework capability in `src/index.ts`

---

## Setup Script

`setup.sh` runs once after you create a repo from this template. It:

1. Prompts for your **project name** (used as the npm package name) and **description**
2. Asks whether to **keep the example code** in `src/index.ts` or replace it with a minimal skeleton
3. Updates `package.json` with your project name and description
4. Rewrites `README.md` with a clean starting point for your project
5. Runs `npm install` to install dependencies
6. Creates an initial git commit with all changes
7. **Deletes itself** — `setup.sh` is removed after it runs

If you keep the examples, `src/index.ts` is unchanged and you can study and modify it. If you start empty, you get a minimal skeleton with a single `hello` tool to build from.

---

## Development Commands

### Build

```bash
npm run build
```

Bundles `src/index.ts` to `dist/index.js` using esbuild (minified ESM output).

### Dev Server

```bash
npm run dev
```

Runs parallel watch mode:
- `dev:build` — esbuild watch (rebuilds on source changes)
- `dev:server` — mctx-dev hot-reloads server on rebuild

**Test environment variables during dev:**

```bash
GREETING="Howdy" npm run dev
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
npm test -- -t "greet"
```

### Linting

```bash
# Check for issues
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

**`GREETING`** — Customizes the greeting message in the `greet` tool.
- **Default:** `"Hello"`
- **Example:** `GREETING="Howdy"` produces `"Howdy, Alice!"`

Set environment variables in the [mctx.ai dashboard](https://mctx.ai) when deployed — changes trigger a seamless automatic redeploy.

---

## What This Template Demonstrates

The example server in `src/index.ts` covers every capability type the framework supports:

| Capability | Patterns Demonstrated |
|---|---|
| **Tools** | Sync string return (`greet`), object return (`calculate`), generator with progress (`analyze`), LLM sampling (`smart-answer`) |
| **Resources** | Static URI (`docs://readme`), dynamic URI template with parameter extraction (`user://{userId}`) |
| **Prompts** | Single-message string (`code-review`), multi-message `conversation()` (`debug`) |
| **Infrastructure** | Structured logging, environment variable configuration, error handling |

Every capability is in one file with comments explaining the pattern. Start there when building your own tools.

---

## Deploy

1. Visit [mctx.ai](https://mctx.ai) and connect your repository
2. Set any environment variables in the dashboard
3. Deploy — mctx reads `package.json` for server configuration

mctx handles TLS, scaling, and uptime. You keep the code. Set your price and get paid when other developers use your server.

---

## Learn More

- [`@mctx-ai/mcp-server`](https://github.com/mctx-ai/mcp-server) — Framework documentation and API reference
- [docs.mctx.ai](https://docs.mctx.ai) — Platform guides for deploying and managing MCP servers
- [mctx.ai](https://mctx.ai) — Host your MCP server for free
- [MCP Specification](https://modelcontextprotocol.io) — The protocol spec this server implements
