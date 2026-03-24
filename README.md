<img src="https://mctx.ai/brand/logo-purple.png" alt="mctx" width="120">

# Example App

The comprehensive reference implementation for [`@mctx-ai/mcp-server`](https://github.com/mctx-ai/mcp-server). Every framework capability in one well-commented file — clone it, study it, fork it as a template for your own App.

---

## What This Example Demonstrates

`src/index.ts` covers every pattern the framework supports:

**Tool Patterns**
- **Sync string return** — `greet`: receives args, returns a formatted string; demonstrates environment variable configuration via `GREETING`
- **Object return** — `calculate`: returns a structured result object (auto-serialized to JSON); demonstrates input validation and error throwing
- **Generator with progress** — `analyze`: yields progress notifications via `createProgress()`; demonstrates `GeneratorToolHandler`
- **LLM sampling** — `smart-answer`: delegates to the client's LLM via the `ask` parameter; demonstrates graceful fallback when sampling is unavailable
- **User identity via ctx** — `whoami`: reads `ctx.userId`, the stable mctx subscriber ID injected server-side by the platform; demonstrates graceful degradation outside mctx

**Resource Patterns**
- **Static URI** — `docs://readme`: exact URI, no parameters, returns plain text
- **Dynamic URI template** — `user://{userId}`: extracts `userId` from the URI path, returns a JSON profile

**Prompt Patterns**
- **Single-message** — `code-review`: returns a plain string that becomes one user message
- **Multi-message conversation** — `debug`: uses `conversation()` to build structured user/assistant dialogue

**Infrastructure**
- **Tool annotation hints** — every tool sets `readOnlyHint`, `destructiveHint`, `openWorldHint`, and `idempotentHint` with inline rationale explaining each choice
- **Structured logging** — `log.info`, `log.debug`, `log.warning`, `log.error`, and `log.notice` throughout
- **Environment variable configuration** — reads `process.env.GREETING` lazily inside the handler (not at module scope)
- **Comprehensive test coverage** — `src/index.test.ts` tests every tool, resource, and prompt via JSON-RPC 2.0 requests

**Channel Events (Real-Time Push)**

Ideal for real-time notifications, build status updates, background task completion alerts, and other events that don't require a response. See [Usage in Conversation](#usage-in-conversation) for example phrases.

- **One-way push pattern** — `ctx.emit()` lets tools push real-time notifications into Claude Code sessions without the client polling. Handlers receive `(args, ask, ctx)` where `ctx.emit` sends events; the call is fire-and-forget and delivery to Claude Code happens asynchronously via `ctx.waitUntil()` without blocking the tool response
- **`notify` tool** — dedicated demo of the channel pattern: receives a message string, emits it as a `notification` event with `source: example_server` meta, and returns a confirmation string to the caller
- **`greet` tool enhancement** — fires a `greeting` event as a side-effect every time someone is greeted, showing how emit integrates naturally into existing tools

> **Requirements:** Channel events require the mctx thin client plugin and Claude Code with channel support. The environment variables `MCTX_EVENTS_ENDPOINT`, `MCTX_SERVER_ID`, and `MCTX_EVENTS_SECRET` are auto-injected by mctx at runtime — developers do not set these manually. In local dev, these vars are absent and `ctx.emit()` gracefully no-ops.

---

## Usage in Conversation

Once connected to an MCP client, try phrases like these:

**Greetings and identity**
- "Greet Alice" — calls `greet` with `name: "Alice"`
- "Who am I?" — calls `whoami` to return your stable mctx user ID
- "Greet the whole team" — calls `greet` in a loop for each name

**Math and analysis**
- "What is 6 times 7?" — calls `calculate` with `operation: "multiply"`
- "Divide 10 by 0" — triggers the division-by-zero error path
- "Analyze quantum computing" — calls `analyze` and streams three progress phases

**Q&A and LLM sampling**
- "What is the capital of France?" — calls `smart-answer`, which delegates to the client's LLM via `ask`
- "Ask anything" — routes arbitrary questions through `smart-answer`

**Resources**
- "Read the server docs" — reads `docs://readme`
- "Look up user 42" — reads `user://42`

**Prompts**
- "Review my code" — invokes the `code-review` prompt with a code snippet
- "Help me debug this stack trace" — invokes the `debug` prompt with an error and optional context

**Channel Events**
- "Send me a notification saying 'Build complete'" — calls `notify`, which pushes the message as a real-time channel event into your Claude Code session
- "Greet Alice" — calls `greet` and also fires a `greeting` channel event as a side-effect

---

## Example Responses

```
greet(name: "Alice")
→ "Hello, Alice!"

whoami()
→ "Your mctx user ID is: user_abc123. This ID is stable across all your devices and sessions."

calculate(operation: "multiply", a: 6, b: 7)
→ { "operation": "multiply", "a": 6, "b": 7, "result": 42 }

analyze(topic: "quantum computing")
→ [progress: 1/3] → [progress: 2/3] → [progress: 3/3]
→ "Analysis of "quantum computing" complete. Found 42 insights across 7 categories."

smart-answer(question: "What is the capital of France?")
→ "Question: What is the capital of France?\n\nAnswer: Paris."

notify(message: "Build complete")
→ "Notification sent: \"Build complete\""
→ [channel event pushed to Claude Code session: type=notification, source=example_server]
  (the channel event appears as a real-time notification in the Claude Code session)

Read URI: docs://readme
→ "Welcome to the example App built with @mctx-ai/mcp-server..."

Read URI: user://42
→ { "id": "42", "name": "User 42", "joined": "2024-01-01", "plan": "pro" }

code-review(code: "const x = eval(input)", language: "javascript")
→ "Please review this javascript for bugs, security issues, and improvements:..."

debug(error: "TypeError: Cannot read properties of undefined")
→ [user] "I'm seeing this error: TypeError: Cannot read..."
→ [assistant] "I will analyze the error and provide step-by-step debugging guidance."
```

---

## Getting Started

### Using as a Template

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

`setup.sh` prompts for a project name and description, asks whether to keep the example code or start from a minimal skeleton, updates `package.json`, rewrites `README.md` with a clean starting point, installs dependencies, creates an initial git commit, and deletes itself.

**3. Start developing**

```bash
npm run dev
```

If you kept the examples, `src/index.ts` is unchanged — study the patterns and modify from there. If you started empty, you get a minimal skeleton with a single `hello` tool to build from.

### Development Commands

**Build**

```bash
npm run build
```

Bundles `src/index.ts` to `dist/index.js` using esbuild (minified ESM output).

**Dev server**

```bash
npm run dev
# Test environment variables during dev:
GREETING="Howdy" npm run dev
```

Runs parallel watch mode: esbuild rebuilds on source changes, mctx-dev hot-reloads the server on rebuild.

**Testing**

```bash
npm test                          # Run all tests
npm test -- --watch               # Watch mode
npm test src/index.test.ts        # Specific file
npm test -- -t "greet"            # Pattern match
```

**Linting and formatting**

```bash
npm run lint
npm run format
npm run format:check
```

### Environment Variables

**`GREETING`** — Customizes the greeting in the `greet` tool (default: `"Hello"`). Set `GREETING="Howdy"` to get `"Howdy, Alice!"`.

**Channel event variables (auto-injected by mctx — do not set manually)**

`MCTX_EVENTS_ENDPOINT`, `MCTX_SERVER_ID`, and `MCTX_EVENTS_SECRET` are injected by the mctx platform at runtime. `ctx.emit()` automatically detects and uses these variables with no developer configuration needed — the framework wires them up internally and passes a ready-to-use `ctx` to every handler. In local dev, these vars are absent and `ctx.emit()` gracefully no-ops, so your tools work the same locally as on mctx (without actually pushing channel events).

---

## Project Structure

```
src/index.ts        → Server implementation — all capabilities in one file
  ├─ Tools          → greet, whoami, calculate, analyze, smart-answer, notify
  ├─ Resources      → docs://readme (static), user://{userId} (dynamic)
  ├─ Prompts        → code-review (single-message), debug (multi-message)
  └─ Export         → fetch handler for JSON-RPC 2.0 over HTTP

src/index.test.ts   → Tests for every tool, resource, and prompt
dist/index.js       → Bundled output (generated by esbuild, not committed on main)
```

---

## Deployment Model

**mctx does not run build commands.** It serves `dist/index.js` from the `release` branch — no `npm run build` at deploy time.

**`dist/` is gitignored on `main`.** The release pipeline (`.github/workflows/release.yml`) builds `dist/index.js` from source and commits it to `release` automatically. Source-only on `main`; built output on `release`.

**Deployment trigger:** mctx watches for `version` changes in `package.json` on the `release` branch. A version bump triggers a new deployment. A push with no version bump does not trigger deployment.

**Conventional commits determine the version bump:**

| Commit prefix | Bump |
|---|---|
| `feat!:` or `fix!:` | Major |
| `feat:` | Minor |
| Everything else | Patch |

This repo uses squash merging — PR title becomes the commit subject, so **PR titles must follow conventional commit format**.

Do not edit the `release` branch directly. Do not commit `dist/index.js` on `main`.

---

## Making Your App Discoverable

Three `package.json` fields and `README.md` determine how developers find your App.

- **`description`** — Appears in the MCP Community Registry (truncates at ~100–150 chars) and on your mctx.ai page. Front-load the most important information.
- **`homepage`** — Clickable link on your public mctx.ai page. Point it at your GitHub repo or docs site.
- **`README.md`** — Becomes the documentation on your mctx.ai page and is indexed by Context7 for AI assistant discovery. Lead with what the App does; the first ~4,000 characters are what AI assistants use to understand and recommend it.

---

## Learn More

- [`@mctx-ai/mcp-server`](https://github.com/mctx-ai/mcp-server) — Framework documentation and API reference
- [docs.mctx.ai](https://docs.mctx.ai) — Platform guides for deploying and managing your Apps
- [mctx.ai](https://mctx.ai) — Host your App for free
- [MCP Specification](https://modelcontextprotocol.io) — The protocol spec this App implements

