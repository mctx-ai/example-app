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

### `whoami`

Returns the authenticated mctx user ID. Takes no arguments — the identity comes from `ctx.userId`, a stable identifier that mctx injects into every handler call.

```
whoami()
→ "Your mctx user ID is: user_abc123. This ID is stable across all your devices and sessions."
```

**`ctx.userId` is a mctx platform feature.** When a subscriber calls your server, mctx resolves their account server-side and injects it as the third argument to every handler — tools, resources, and prompts alike. Clients cannot forge or override it.

Use it to scope per-user data, personalize responses, or gate access to user-specific resources without asking users to identify themselves.

Demonstrates the `ctx` parameter and graceful degradation — when called outside mctx (local dev, HTTP test transport), the tool returns a helpful explanation rather than an error.

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

## Tool Annotations

MCP clients — including Claude Desktop, Cursor, and apps submitted to the MCP app store — use annotation hints to decide how to surface permission prompts and safety warnings. Setting them correctly affects the user experience your subscribers see when they invoke your tools.

### The Four Hints

| Hint | What it tells clients |
|---|---|
| `readOnlyHint` | This tool only reads data. No state changes occur. Clients may show a less prominent permission prompt. |
| `destructiveHint` | This tool may destroy or permanently alter data. Clients may show a stronger warning before allowing it to run. |
| `openWorldHint` | This tool reaches outside the server — network requests, external APIs, filesystem access. Clients may flag the external access. |
| `idempotentHint` | Running this tool repeatedly with the same arguments causes no additional side effects after the first call. Clients may safely retry. |

Hints are advisory — they inform the client UI, not the server. The server does not enforce them.

### Setting Annotations

Attach `.annotations` to your handler function using the same decorator pattern as `.description` and `.input`:

```typescript
const greet: ToolHandler = (args) => {
  const { name } = args as { name: string };
  return `Hello, ${name}!`;
};
greet.description = 'Greets a person by name';
greet.input = { name: T.string({ required: true }) };
greet.annotations = { readOnlyHint: true };  // pure read — no side effects
server.tool('greet', greet);
```

### Decision Checklist

Work through these questions for each tool you write:

1. Does the tool write, delete, or modify anything? If no → `readOnlyHint: true`
2. Is a write irreversible or data-destroying? If yes → `destructiveHint: true`
3. Does the tool call an external service, make a network request, or read from the filesystem? If yes → `openWorldHint: true`
4. Can the tool be safely retried with identical arguments? If yes → `idempotentHint: true`

### Common Profiles

| Pattern | Annotation |
|---|---|
| Read-only, data stays local | `{ readOnlyHint: true }` |
| Read-only, calls external API or service | `{ readOnlyHint: true, openWorldHint: true }` |
| Creates a resource (safe to retry) | `{ idempotentHint: true }` |
| Deletes or overwrites data | `{ destructiveHint: true }` |
| Sends an email, posts a message (cannot undo) | `{ destructiveHint: true, openWorldHint: true }` |

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

## Making Your Server Discoverable

Three fields in `package.json` and one file determine how developers find your server, what they see when they land on your mctx.ai page, and whether AI assistants recommend it.

### `description`

This is marketing copy for potential subscribers AND an SEO field indexed by Google. You have 1,000 characters — use them. Describe specific capabilities with action verbs: "Query financial data from SEC filings using plain language queries" not "A useful finance server."

The description also appears in the [MCP Community Registry](https://registry.modelcontextprotocol.io), but registry display truncates at roughly 100–150 characters. Front-load the most important information so it reads well in both contexts.

```json
{
  "description": "Query SEC filings, extract financial metrics, and compare company performance using plain language. Supports 10-K, 10-Q, and 8-K filings. Returns structured data with citations to source documents. Built for analysts, researchers, and AI assistants that need auditable financial data without API keys or rate limits."
}
```

### `homepage` (optional)

Appears as a clickable link on your public mctx.ai server page. Set it to a project website, documentation site, or your GitHub repo URL. If you link to a GitHub repo, make sure it's public — private repo URLs return 404 to visitors.

```json
{
  "homepage": "https://github.com/your-org/your-server"
}
```

### `README.md`

Your README becomes the public documentation on your mctx.ai server page. It also gets submitted to [Context7](https://context7.com) for AI assistant discovery — when developers ask an AI "find me a server that does X," Context7 searches README content to match.

Structure matters. Lead with what the server does, then tools, then use cases, then prerequisites. The first ~4,000 characters are what AI assistants use to understand and recommend your server, so put the best material up front.

See [docs.mctx.ai](https://docs.mctx.ai) for detailed guidance on writing READMEs that convert browsers into subscribers.

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

- **"Who am I?"** — Call `whoami` to see your stable mctx user ID and understand how ctx.userId works
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
