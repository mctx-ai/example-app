<img src="https://mctx.ai/brand/logo-purple.png" alt="mctx" width="120">

**Free MCP Hosting. Set Your Price. Get Paid.**

# Example MCP Server

A complete reference implementation built with [`@mctx-ai/mcp-server`](https://github.com/mctx-ai/mcp-server). Every framework capability in one file — clone it, study it, make it yours.

---

## What This Server Does

Demonstrates all four MCP capability types in a single, well-commented file (`src/index.ts`):

| Capability | What's Covered |
|---|---|
| **Tools** | Sync string return, object return, generator with progress, LLM sampling |
| **Resources** | Static URI, dynamic URI template with parameter extraction |
| **Prompts** | Single-message string, multi-message `conversation()` |
| **Infrastructure** | Structured logging, environment variables, error handling — [configurable from the mctx.ai dashboard](https://mctx.ai) when deployed |

---

## Tools

### `greet`

Greets a person by name. Uses the `GREETING` environment variable (default: `"Hello"`).

| Parameter | Type | Required | Description |
|---|---|---|---|
| `name` | string | yes | Name to greet (1–100 characters) |

```
greet(name: "Alice")
→ "Hello, Alice!"
```

Set `GREETING=Howdy` to get `"Howdy, Alice!"` instead.

> In production, configure environment variables from the [mctx.ai dashboard](https://mctx.ai) — changes trigger a seamless automatic redeploy.

---

### `calculate`

Performs basic arithmetic and returns a structured result object.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `operation` | string | yes | One of: `add`, `subtract`, `multiply`, `divide` |
| `a` | number | yes | First operand |
| `b` | number | yes | Second operand |

```
calculate(operation: "multiply", a: 6, b: 7)
→ { "operation": "multiply", "a": 6, "b": 7, "result": 42 }
```

Throws a descriptive error on division by zero.

---

### `analyze`

Analyzes a topic and streams progress notifications as it works through three phases.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `topic` | string | yes | Topic to analyze (3–200 characters) |

```
analyze(topic: "quantum computing")
→ [progress: 1/3] → [progress: 2/3] → [progress: 3/3]
→ "Analysis of "quantum computing" complete. Found 42 insights across 7 categories."
```

Demonstrates `GeneratorToolHandler` with `createProgress()`.

---

### `smart-answer`

Answers questions by delegating to the client's LLM via the sampling API. Falls back gracefully when sampling is unavailable (HTTP transport).

| Parameter | Type | Required | Description |
|---|---|---|---|
| `question` | string | yes | Question to answer (minimum 5 characters) |

```
smart-answer(question: "What is the capital of France?")
→ "Question: What is the capital of France?\n\nAnswer: Paris."
```

Demonstrates the `ask` parameter and bidirectional transport pattern.

This pattern — letting the MCP client supply the LLM — means your server stays stateless and cheap to host. The client brings the model; mctx brings the infrastructure.

---

## Resources

### `docs://readme`

Static resource. Returns plain-text server documentation.

```
Read URI: docs://readme
→ "Welcome to the example MCP server built with @mctx-ai/mcp-server..."
```

---

### `user://{userId}`

Dynamic resource. Returns a JSON user profile for the given ID.

```
Read URI: user://42
→ { "id": "42", "name": "User 42", "joined": "2024-01-01", "plan": "pro" }
```

Demonstrates URI templates with automatic parameter extraction.

---

## Prompts

### `code-review`

Generates a code review request as a single user message.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `code` | string | yes | Code to review |
| `language` | string | no | Programming language label |

```
code-review(code: "const x = eval(input)", language: "javascript")
→ "Please review this javascript for bugs, security issues, and improvements:..."
```

---

### `debug`

Builds a structured multi-turn conversation to guide debugging.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `error` | string | yes | Error message or description |
| `context` | string | no | Stack trace or additional logs (max 5,000 characters) |

```
debug(error: "TypeError: Cannot read properties of undefined")
→ [user] "I'm seeing this error: TypeError: Cannot read..."
→ [assistant] "I will analyze the error and provide step-by-step debugging guidance."
```

Demonstrates `conversation()` for multi-role dialogue.

---

## Use This Template

This repo is a GitHub template. Click **Use this template** on GitHub, then:

**1. Clone your new repo**

```bash
git clone https://github.com/your-username/your-repo.git
cd your-repo
```

**2. Run the setup script**

```bash
./setup.sh
```

`setup.sh` runs once and prompts you for a project name and description, asks whether to keep the example code or start from a minimal skeleton, updates `package.json`, rewrites `README.md` with a clean starting point, installs dependencies, creates an initial git commit, and deletes itself.

**3. Start developing**

```bash
npm run dev
```

If you kept the examples, `src/index.ts` is unchanged — study the patterns and modify from there. If you started empty, you get a minimal skeleton with a single `hello` tool to build from.

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

## Prompt Ideas

Use these with any MCP client connected to this server:

- **"Greet the whole team"** — Call `greet` in a loop with each team member's name
- **"Check my math"** — Use `calculate` to verify arithmetic in a document or spreadsheet
- **"Deep-dive on a topic"** — Call `analyze` and watch real-time progress stream in
- **"Ask anything"** — Use `smart-answer` to route questions through the client's LLM
- **"Review my PR diff"** — Pass a code snippet to `code-review` with the language set
- **"Help me fix this stack trace"** — Feed an error and logs into `debug` for guided triage
- **"Look up a user"** — Read `user://{id}` to fetch a profile by ID

---

## Learn More

- [`@mctx-ai/mcp-server`](https://github.com/mctx-ai/mcp-server) — Framework documentation and API reference
- [docs.mctx.ai](https://docs.mctx.ai) — Platform guides for deploying and managing MCP servers
- [mctx.ai](https://mctx.ai) — Host your MCP server for free
- [MCP Specification](https://modelcontextprotocol.io) — The protocol spec this server implements
