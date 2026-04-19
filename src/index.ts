/**
 * Example MCP Server
 *
 * A complete reference implementation built with @mctx-ai/mcp.
 * Read top-to-bottom to learn every framework capability:
 *
 *   1. Server setup and configuration
 *   2. Tools — sync handlers, object returns, progress tracking, and LLM sampling
 *   3. Resources — static URIs and dynamic URI templates
 *   4. Prompts — single-message strings and multi-message conversations
 *   5. Export — the fetch handler that ties it all together
 */

import {
  createServer,
  T,
  conversation,
  log,
  type ToolHandler,
  type ResourceHandler,
  type PromptHandler,
} from '@mctx-ai/mcp';

// ─── Server ──────────────────────────────────────────────────────────
//
// createServer() initializes an MCP server. The `instructions` field
// tells LLM clients what this MCP server offers and how to use it.

const server = createServer({
  instructions:
    'An example MCP server showcasing all framework features. ' +
    "Use 'greet' for a hello (customizable via GREETING env var), " +
    "'whoami' to retrieve the authenticated mctx user ID (mctx.userId), " +
    "'calculate' for math, 'analyze' for progress-tracked analysis, " +
    "and 'smart-answer' for LLM-assisted Q&A. " +
    "Resources include docs://readme and user://{userId}. Prompts include 'code-review' and 'debug'.",
});

// ─── Tools ───────────────────────────────────────────────────────────
//
// Tools are functions that LLM clients can invoke. Each tool gets a handler
// function, a description, and an input schema built with the T type system.
//
// The framework supports these handler patterns:
//   - Sync handler calling res.send() with a string
//   - Sync handler calling res.send() with an object (auto-serialized to JSON)
//   - Async handler calling res.progress() then res.send() for progress tracking
//   - Async handler using res.ask for LLM sampling

/**
 * Simplest tool pattern: receive req, call res.send() with a string.
 *
 * Demonstrates environment variable usage via GREETING env var.
 * Set GREETING in the mctx dashboard to customize the greeting message.
 * Reads process.env lazily inside the handler (not at module scope) because
 * env vars may not be available at import time in some runtimes.
 */
const greet: ToolHandler = (mctx, req, res) => {
  const { name } = req as { name: string };
  const greeting = process.env.GREETING || 'Hello';
  const trimmedName = name.trim();

  log.info(`Greeting ${trimmedName} with: ${greeting}`);

  res.send(`${greeting}, ${trimmedName}!`);
};
greet.description =
  'Greets a person by name with a personalized message using the GREETING environment variable (default: "Hello")';
greet.input = {
  name: T.string({
    required: true,
    description: 'Name to greet',
    minLength: 1,
    maxLength: 100,
  }),
};
// readOnlyHint: true  — returns a greeting string; no state is modified
// destructiveHint: false — cannot modify or delete anything
// openWorldHint: false — entirely self-contained; no I/O of any kind
// idempotentHint: true  — same name + same GREETING always produces the same output
greet.annotations = {
  readOnlyHint: true,
  destructiveHint: false,
  openWorldHint: false,
  idempotentHint: true,
};
server.tool('greet', greet);

/**
 * mctx.userId — the authenticated mctx user identity
 *
 * mctx passes a context object as the FIRST argument to every handler:
 *   ToolHandler:          (mctx, req, res) => void
 *   ResourceHandler:      (mctx, req, res) => void
 *   PromptHandler:        (mctx, req, res) => void
 *
 * mctx.userId is a stable, opaque string that identifies the user
 * who is calling this MCP server. Key properties:
 *
 *   - Stable across sessions — the same user gets the same ID every time,
 *     from every device and client, for as long as their mctx account exists.
 *
 *   - Opaque — treat it as an arbitrary string; do not parse it for structure.
 *     mctx makes no guarantees about its format other than uniqueness.
 *
 *   - Platform-injected — it is NOT passed by the MCP client. mctx resolves
 *     the authenticated user and injects it server-side before your
 *     handler runs. Clients cannot forge or override it.
 *
 * Use mctx.userId to:
 *   - Scope stored data per user (per-user KV keys, database rows, etc.)
 *   - Gate access to user-specific resources
 *   - Personalize responses without asking the user to identify themselves
 *
 * When running outside mctx (local dev, HTTP tests, non-authenticated requests)
 * mctx.userId may be absent. Always guard against this.
 */
export const whoami: ToolHandler = (mctx, _req, res) => {
  // mctx is the first positional argument on every handler.
  // We only need userId here, so we destructure narrowly.
  const { userId } = mctx;

  if (!userId) {
    // This happens in HTTP transport, local dev, or any context where mctx
    // has not injected an authenticated user. Return a helpful explanation
    // rather than an error so the tool degrades gracefully.
    log.warning(
      'whoami called without mctx.userId — not running inside mctx or no authenticated user',
    );
    res.send(
      'No mctx user ID is available. This tool returns your stable user ID when called through the mctx platform with an authenticated session.',
    );
    return;
  }

  log.info({ userId, message: 'whoami called by authenticated mctx user' });

  res.send(`Your mctx user ID is: ${userId}. This ID is stable across all your devices and sessions.`);
};
whoami.description =
  'Returns the authenticated mctx user ID (mctx.userId) — a stable, platform-injected identifier unique to your mctx account';
// No .input — this tool takes no arguments. The user identity comes from mctx, not from req.
// readOnlyHint: true  — reads mctx.userId only; touches no external state
// destructiveHint: false — returns information; cannot modify or delete anything
// openWorldHint: false — mctx.userId is injected by mctx before the handler runs; no network call
// idempotentHint: true  — same user + same mctx always produces the same output
whoami.annotations = {
  readOnlyHint: true,
  destructiveHint: false,
  openWorldHint: false,
  idempotentHint: true,
};
server.tool('whoami', whoami);

/** Object returns are auto-serialized to JSON. Throw errors to signal failure. */
const calculate: ToolHandler = (_mctx, req, res) => {
  const { operation, a, b } = req as {
    operation: string;
    a: number;
    b: number;
  };

  // Guard clause: check for invalid input before doing any work
  if (operation === 'divide' && b === 0) {
    log.error({ error: 'Division by zero attempted', operation, a, b });
    throw new Error(`Cannot divide ${a} by zero. The divisor must be a non-zero number.`);
  }

  const ops: Record<string, number> = {
    add: a + b,
    subtract: a - b,
    multiply: a * b,
    divide: a / b,
  };

  if (!(operation in ops)) {
    throw new Error(`Invalid operation: ${operation}. Use add, subtract, multiply, or divide.`);
  }

  log.debug({ operation, a, b, result: ops[operation] });

  res.send({ operation, a, b, result: ops[operation] });
};
calculate.description = 'Performs arithmetic operations with support for basic arithmetic';
calculate.input = {
  operation: T.string({
    required: true,
    enum: ['add', 'subtract', 'multiply', 'divide'],
    description: 'Arithmetic operation to perform',
  }),
  a: T.number({ required: true, description: 'First operand' }),
  b: T.number({ required: true, description: 'Second operand' }),
};
// readOnlyHint: true  — pure math; no state is read from or written to external systems
// destructiveHint: false — arithmetic cannot remove or corrupt any data
// openWorldHint: false — entirely self-contained; no I/O of any kind
// idempotentHint: true  — f(a, b) always returns the same result for the same inputs
calculate.annotations = {
  readOnlyHint: true,
  destructiveHint: false,
  openWorldHint: false,
  idempotentHint: true,
};
server.tool('calculate', calculate);

/**
 * Progress tracking via res.progress(current, total).
 * Calls res.progress() at each phase so clients can show status updates,
 * then calls res.send() with the final result.
 */
const analyze: ToolHandler = async (_mctx, req, res) => {
  const { topic } = req as { topic: string };

  log.info(`Starting analysis of topic: ${topic}`);

  res.progress(1, 3);
  log.debug('Phase 1: Research complete');

  res.progress(2, 3);
  log.debug('Phase 2: Analysis complete');

  res.progress(3, 3);
  log.notice('Phase 3: Synthesis complete');

  const result = `Analysis of "${topic}" complete. Found 42 insights across 7 categories.`;
  log.info({ topic, result: 'success', insights: 42, categories: 7 });

  res.send(result);
};
analyze.description = 'Analyzes a topic with progress updates';
analyze.input = {
  topic: T.string({
    required: true,
    description: 'Topic to analyze',
    minLength: 3,
    maxLength: 200,
  }),
};
// readOnlyHint: true  — local computation only; reports progress but writes nothing
// destructiveHint: false — analysis produces output, never deletes or mutates anything
// openWorldHint: false — no network calls or external system access
// idempotentHint omitted — the simulated analysis result is constant here, but real
//   analysis tools often incorporate live data sources whose content changes over time;
//   omitting the hint leaves clients free to decide retry/caching policy themselves
analyze.annotations = {
  readOnlyHint: true,
  destructiveHint: false,
  openWorldHint: false,
};
server.tool('analyze', analyze);

/**
 * res.ask enables LLM sampling — your tool can ask the client's LLM for help
 * mid-execution. res.ask is null if the client doesn't support it
 * (e.g., HTTP/stateless transport), so always check before calling.
 *
 * When available, use the advanced SamplingOptions form to control the model,
 * system prompt, and token budget. The simple string form also works for
 * straightforward one-shot prompts.
 */
export const smartAnswer: ToolHandler = async (_mctx, req, res) => {
  const { question } = req as { question: string };

  log.info(`Processing question: ${question}`);

  if (!res.ask) {
    // Sampling requires bidirectional transport (WebSocket/SSE).
    // In HTTP mode, fall back to a direct answer without LLM assistance.
    log.warning('LLM sampling not available (HTTP transport); returning direct answer');
    res.send(
      `Question: ${question}\n\nAnswer: LLM sampling is not available in this transport mode. Connect via a streaming transport (WebSocket or SSE) to enable the smart-answer tool's full capability.`,
    );
    return;
  }

  // Use the advanced SamplingOptions form to demonstrate the full res.ask API:
  // - messages: structured conversation history passed to the LLM
  // - systemPrompt: role/persona for the sampled response
  // - maxTokens: upper bound on response length
  log.debug('LLM sampling available — requesting answer via res.ask()');
  const answer = await res.ask({
    messages: [
      {
        role: 'user',
        content: {
          type: 'text',
          text: question,
        },
      },
    ],
    systemPrompt: 'You are a knowledgeable assistant. Answer the question clearly and concisely.',
    maxTokens: 1024,
  });
  log.debug({ answer });

  res.send(`Question: ${question}\n\nAnswer: ${answer}`);
};
smartAnswer.description =
  'Answers questions using LLM sampling (res.ask) when available, with a direct fallback for HTTP transport';
smartAnswer.input = {
  question: T.string({
    required: true,
    description: 'Question to answer',
    minLength: 5,
  }),
};
// readOnlyHint: true  — reads a question and returns an answer; no state is modified
// destructiveHint: false — the tool produces text; it cannot remove or corrupt anything
// openWorldHint: true  — delegates to the client's LLM via res.ask(), crossing a network
//   boundary into an external AI system whose outputs are non-deterministic
// idempotentHint omitted — LLM sampling is inherently non-deterministic; the same
//   question can produce different answers on every call, so callers must not assume
//   retries are safe to deduplicate
smartAnswer.annotations = {
  readOnlyHint: true,
  destructiveHint: false,
  openWorldHint: true,
};
server.tool('smart-answer', smartAnswer);

// ─── Resources ───────────────────────────────────────────────────────
//
// Resources expose data via URIs that LLM clients can read.
//   - Static resources use exact URIs (e.g., docs://readme)
//   - Dynamic resources use URI templates with {param} placeholders

/** Static resource: exact URI, no parameters. */
const readme: ResourceHandler = (_mctx, _req, res) => {
  res.send(
    'Welcome to the example MCP server built with @mctx-ai/mcp. This MCP server demonstrates tools, resources, prompts, progress tracking, and sampling.',
  );
};
readme.description = 'MCP server documentation';
readme.mimeType = 'text/plain';
server.resource('docs://readme', readme);

/** Dynamic resource: URI template extracts params automatically. */
const userProfile: ResourceHandler = (_mctx, req, res) => {
  const { userId } = req as { userId: string };

  res.send(
    JSON.stringify({
      id: userId,
      name: `User ${userId}`,
      joined: '2024-01-01',
      role: 'developer',
    }),
  );
};
userProfile.description = 'User profile by ID';
userProfile.mimeType = 'application/json';
server.resource('user://{userId}', userProfile);

// ─── Prompts ─────────────────────────────────────────────────────────
//
// Prompts are reusable message templates that pre-fill LLM conversations.
//   - Call res.send() with a string for a single user message
//   - Call res.send() with conversation() for multi-role dialogue

/** Single-message prompt: a string passed to res.send() becomes one user message. */
const codeReview: PromptHandler = (_mctx, req, res) => {
  const { code, language } = req as { code: string; language?: string };

  res.send(
    `Please review this ${language || 'code'} for bugs, security issues, and improvements:\n\n\`\`\`${language || ''}\n${code}\n\`\`\``,
  );
};
codeReview.description = 'Code review prompt';
codeReview.input = {
  code: T.string({ required: true, description: 'Code to review' }),
  language: T.string({ description: 'Programming language' }),
};
server.prompt('code-review', codeReview);

/** Multi-message prompt: conversation() builds structured user/assistant dialogue. */
const debug: PromptHandler = (_mctx, req, res) => {
  const { error, context } = req as { error: string; context?: string };

  res.send(
    conversation(({ user, ai }) => [
      user.say(`I'm seeing this error: ${error}`),
      ...(context ? [user.say(`Context:\n${context}`)] : []),
      ai.say('I will analyze the error and provide step-by-step debugging guidance.'),
    ]),
  );
};
debug.description = 'Debug assistance prompt with structured dialogue';
debug.input = {
  error: T.string({
    required: true,
    description: 'Error message or description',
    minLength: 1,
  }),
  context: T.string({
    description: 'Additional context, stack trace, or logs',
    maxLength: 5000,
  }),
};
server.prompt('debug', debug);

// ─── Export ──────────────────────────────────────────────────────────
//
// The server's fetch handler processes JSON-RPC 2.0 requests over HTTP.
// This export format is compatible with Cloudflare Workers and mctx hosting.

export default { fetch: server.fetch };
