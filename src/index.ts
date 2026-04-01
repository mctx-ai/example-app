/**
 * Example App
 *
 * A complete reference implementation built with @mctx-ai/app.
 * Read top-to-bottom to learn every framework capability:
 *
 *   1. Server setup and configuration
 *   2. Tools — sync handlers, object returns, generators, and LLM sampling
 *   3. Resources — static URIs and dynamic URI templates
 *   4. Prompts — single-message strings and multi-message conversations
 *   5. Channel events — one-way push notifications via ctx.emit()
 *   6. Export — the fetch handler that ties it all together
 */

import {
  createServer,
  T,
  conversation,
  createProgress,
  log,
  type ToolHandler,
  type GeneratorToolHandler,
  type ResourceHandler,
  type PromptHandler,
} from '@mctx-ai/app';

// ─── Server ──────────────────────────────────────────────────────────
//
// createServer() returns an App instance. The `instructions` field
// tells LLM clients what this App offers and how to use it.

const server = createServer({
  instructions:
    'An example App showcasing all framework features. ' +
    "Use 'greet' for a hello (customizable via GREETING env var), " +
    "'whoami' to retrieve the authenticated mctx user ID (ctx.userId), " +
    "'calculate' for math, 'analyze' for progress-tracked analysis, " +
    "'smart-answer' for LLM-assisted Q&A, 'notify' to push a custom " +
    'message as a real-time channel event into the connected Claude Code session, ' +
    "'schedule' to deliver a deferred channel event at a future ISO 8601 timestamp " +
    '(with optional correlation key for deduplication), and ' +
    "'cancel-event' to cancel a pending scheduled event by its eventId. " +
    "Resources include docs://readme and user://{userId}. Prompts include 'code-review' " +
    "and 'debug'. " +
    'Channel events (ctx.emit()) let this App push one-way notifications without ' +
    'the client polling — notify demonstrates immediate delivery, schedule demonstrates ' +
    'deferred delivery, and greet fires a greeting event as a side-effect. ' +
    "Use schedule then cancel-event (with the returned eventId) to manage pending events. " +
    'Channel events only deliver when running on mctx; they no-op silently in local dev and HTTP transport.',
});

// ─── Tools ───────────────────────────────────────────────────────────
//
// Tools are functions that LLM clients can invoke. Each tool gets a handler
// function, a description, and an input schema built with the T type system.
//
// The framework supports four handler patterns:
//   - Sync handler returning a string
//   - Sync handler returning an object (auto-serialized to JSON)
//   - Generator handler yielding progress notifications
//   - Async handler using `ask` for LLM sampling

/**
 * Simplest tool pattern: receive args, return a string.
 *
 * Demonstrates environment variable usage via GREETING env var.
 * Set GREETING in the mctx dashboard to customize the greeting message.
 * Reads process.env lazily inside the handler (not at module scope) because
 * env vars may not be available at import time in some runtimes.
 */
const greet: ToolHandler = (args, _ask, ctx) => {
  const { name } = args as { name: string };
  const greeting = process.env.GREETING || 'Hello';
  const trimmedName = name.trim();

  log.info(`Greeting ${trimmedName} with: ${greeting}`);

  // emit is fire-and-forget — it runs via ctx.waitUntil() and does not block
  // the tool response. The greeting event is a side-effect; the caller receives
  // the return value below before the event is dispatched.
  // ctx.emit works automatically on the mctx platform with no env var configuration —
  // it sets X-Mctx-Event response headers read by the dispatch worker.
  // No-ops silently in local dev and HTTP transport.
  // The returned eventId is intentionally discarded here — this is fire-and-forget;
  // the greeting event is not something the caller needs to track or cancel.
  if (ctx) {
    ctx.emit(`Greeted ${trimmedName}`, {
      eventType: 'greeting',
      meta: { name: trimmedName },
    });
  }

  return `${greeting}, ${trimmedName}!`;
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
// readOnlyHint: false — fires a channel event via emit() as a side-effect; not purely read-only
// destructiveHint: false — cannot modify or delete anything
// openWorldHint: true  — emit() sets X-Mctx-Event response headers read by the dispatch worker
// idempotentHint: true  — the greeting string return is idempotent; the event is fire-and-forget
greet.annotations = {
  readOnlyHint: false,
  destructiveHint: false,
  openWorldHint: true,
  idempotentHint: true,
};
server.tool('greet', greet);

/**
 * ctx.userId — the authenticated mctx user identity
 *
 * mctx passes a context object as the THIRD argument to every handler:
 *   ToolHandler:          (args, ask?, ctx?) => ...
 *   ResourceHandler:      (params, ctx?)     => ...
 *   PromptHandler:        (args, ctx?)        => ...
 *
 * ctx.userId is a stable, opaque string that identifies the subscriber
 * who is calling this App. Key properties:
 *
 *   - Stable across sessions — the same user gets the same ID every time,
 *     from every device and client, for as long as their mctx account exists.
 *
 *   - Opaque — treat it as an arbitrary string; do not parse it for structure.
 *     mctx makes no guarantees about its format other than uniqueness.
 *
 *   - Platform-injected — it is NOT passed by the MCP client. mctx resolves
 *     the authenticated subscriber and injects it server-side before your
 *     handler runs. Clients cannot forge or override it.
 *
 * Use ctx.userId to:
 *   - Scope stored data per user (per-user KV keys, database rows, etc.)
 *   - Gate access to user-specific resources
 *   - Personalize responses without asking the user to identify themselves
 *
 * When running outside mctx (local dev, HTTP tests, non-authenticated requests)
 * ctx may be undefined or ctx.userId may be absent. Always guard against this.
 */
export const whoami: ToolHandler = (_args, _ask?, ctx?) => {
  // ctx is typed inline — it is the third positional argument on every handler.
  // We only need userId here, so we destructure narrowly.
  const { userId } = (ctx ?? {}) as { userId?: string };

  if (!userId) {
    // This happens in HTTP transport, local dev, or any context where mctx
    // has not injected an authenticated user. Return a helpful explanation
    // rather than an error so the tool degrades gracefully.
    log.warning(
      'whoami called without ctx.userId — not running inside mctx or no authenticated user',
    );
    return 'No mctx user ID is available. This tool returns your stable user ID when called through the mctx platform with an authenticated subscription.';
  }

  log.info({ userId }, 'whoami called by authenticated mctx user');

  return `Your mctx user ID is: ${userId}. This ID is stable across all your devices and sessions.`;
};
whoami.description =
  'Returns the authenticated mctx user ID (ctx.userId) — a stable, platform-injected identifier unique to your mctx account';
// No .input — this tool takes no arguments. The user identity comes from ctx, not from args.
// readOnlyHint: true  — reads ctx.userId only; touches no external state
// destructiveHint: false — returns information; cannot modify or delete anything
// openWorldHint: false — ctx.userId is injected by mctx before the handler runs; no network call
// idempotentHint: true  — same user + same ctx always produces the same output
whoami.annotations = {
  readOnlyHint: true,
  destructiveHint: false,
  openWorldHint: false,
  idempotentHint: true,
};
server.tool('whoami', whoami);

/** Object returns are auto-serialized to JSON. Throw errors to signal failure. */
const calculate: ToolHandler = (args) => {
  const { operation, a, b } = args as {
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

  log.debug({ operation, a, b, result: ops[operation] });

  return { operation, a, b, result: ops[operation] };
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
 * Generator tools yield progress notifications so clients can show status.
 * createProgress(total) returns a step function that auto-increments 1/total, 2/total, etc.
 */
const analyze: GeneratorToolHandler = function* (args) {
  const { topic } = args as { topic: string };

  log.info(`Starting analysis of topic: ${topic}`);

  const step = createProgress(3);

  yield step(); // 1/3
  log.debug('Phase 1: Research complete');

  yield step(); // 2/3
  log.debug('Phase 2: Analysis complete');

  yield step(); // 3/3
  log.notice('Phase 3: Synthesis complete');

  const result = `Analysis of "${topic}" complete. Found 42 insights across 7 categories.`;
  log.info({ topic, result: 'success', insights: 42, categories: 7 });

  return result;
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
// readOnlyHint: true  — local computation only; yields progress but writes nothing
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
 * The `ask` parameter enables LLM sampling -- your tool can ask the client's
 * LLM for help mid-execution. It may be null if the client doesn't support it
 * (e.g., HTTP/stateless transport), so always check before calling.
 *
 * When available, use the advanced SamplingOptions form to control the model,
 * system prompt, and token budget. The simple string form also works for
 * straightforward one-shot prompts.
 */
export const smartAnswer: ToolHandler = async (args, ask?) => {
  const { question } = args as { question: string };

  log.info(`Processing question: ${question}`);

  if (!ask) {
    // Sampling requires bidirectional transport (WebSocket/SSE).
    // In HTTP mode, fall back to a direct answer without LLM assistance.
    log.warning('LLM sampling not available (HTTP transport); returning direct answer');
    return `Question: ${question}\n\nAnswer: LLM sampling is not available in this transport mode. Connect via a streaming transport (WebSocket or SSE) to enable the smart-answer tool's full capability.`;
  }

  // Use the advanced SamplingOptions form to demonstrate the full ask() API:
  // - messages: structured conversation history passed to the LLM
  // - systemPrompt: role/persona for the sampled response
  // - maxTokens: upper bound on response length
  log.debug('LLM sampling available — requesting answer via ask()');
  const answer = await ask({
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

  return `Question: ${question}\n\nAnswer: ${answer}`;
};
smartAnswer.description =
  'Answers questions using LLM sampling (ask) when available, with a direct fallback for HTTP transport';
smartAnswer.input = {
  question: T.string({
    required: true,
    description: 'Question to answer',
    minLength: 5,
  }),
};
// readOnlyHint: true  — reads a question and returns an answer; no state is modified
// destructiveHint: false — the tool produces text; it cannot remove or corrupt anything
// openWorldHint: true  — delegates to the client's LLM via ask(), crossing a network
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

// ─── Channel Events ───────────────────────────────────────────────────────
//
// ctx.emit() pushes a one-way notification into the connected Claude Code
// session (or any mctx channel subscriber). It runs via ctx.waitUntil() so
// the tool response is returned to the client immediately — emit never blocks.
//
// ctx.emit() works automatically on the mctx platform with no configuration —
// it sets X-Mctx-Event response headers that the dispatch worker reads. No env
// vars are needed. It no-ops silently in local dev and HTTP transport, so callers
// do not need to handle failures or guard against missing configuration.
//
// Meta keys must match [a-zA-Z0-9_]+ — hyphens are silently dropped by Claude Code.
//
// v1 is one-way only: the server pushes to the client; there is no reverse channel.

/**
 * Explicit channel event demo: receives a message string, pushes it as a channel
 * event, and returns a confirmation string to the caller.
 *
 * This tool exists purely to showcase the channel pattern. In real servers, emit()
 * is typically a side-effect inside other tools (as in greet above), not the primary
 * purpose of a dedicated tool. The explicit form here makes the pattern easy to study.
 *
 * As of the latest @mctx-ai/app version, ctx.emit() returns Promise<string> — the
 * eventId assigned by the mctx events service. Capturing it lets callers log or
 * reference the event after dispatch. The eventId is only present when running on
 * mctx; it is undefined in local dev and HTTP transport.
 */
export const notify: ToolHandler = (args, _ask, ctx) => {
  const { message } = args as { message: string };
  const trimmedMessage = message.trim();

  log.info(`Emitting channel event: ${trimmedMessage}`);

  // ctx.emit works automatically on the mctx platform (no env vars needed) —
  // it sets X-Mctx-Event response headers read by the dispatch worker.
  // No-ops silently in local dev and HTTP transport.
  // emit() returns the eventId synchronously — capture it to return to the caller
  // so they can pass it to cancel-event if needed.
  if (ctx) {
    const eventId = ctx.emit(trimmedMessage, {
      eventType: 'notification',
      meta: { source: 'example_server' },
    });
    return `Notification sent: "${trimmedMessage}" (eventId: ${eventId})`;
  }

  return `Notification sent: "${trimmedMessage}"`;
};
notify.description =
  'Pushes a custom message as a real-time channel event into the connected Claude Code session. ' +
  'Demonstrates the ctx.emit() one-way push pattern.';
notify.input = {
  message: T.string({
    required: true,
    description: 'Message to push as a channel event',
    minLength: 1,
    maxLength: 500,
  }),
};
// readOnlyHint: false  — produces a side-effect (channel push); not purely read-only
// destructiveHint: false — pushes a notification; cannot delete or corrupt any data
// openWorldHint: true  — sets X-Mctx-Event response headers read by the dispatch worker
// idempotentHint: false — each call pushes a new, distinct event; not safe to deduplicate
notify.annotations = {
  readOnlyHint: false,
  destructiveHint: false,
  openWorldHint: true,
  idempotentHint: false,
};
server.tool('notify', notify);

/**
 * Scheduled channel event: delivers a message at a future ISO 8601 timestamp.
 *
 * Demonstrates the deliverAt and key options of ctx.emit(). The returned eventId
 * can be passed to cancel-event to abort delivery before it fires.
 *
 * The optional key is a developer-supplied correlation identifier for deduplication
 * (e.g., "deploy_123"). UUIDs are not valid keys because they contain hyphens —
 * key must match /^[a-zA-Z0-9_]+$/. If key is not provided, the event has no
 * deduplication key.
 */
export const schedule: ToolHandler = async (args, _ask, ctx) => {
  const { message, deliverAt, key } = args as {
    message: string;
    deliverAt: string;
    key?: string;
  };

  log.info(`Scheduling channel event for ${deliverAt}: ${message}`);

  if (!ctx) {
    return `Event scheduled for ${deliverAt} (eventId: unavailable — not running on mctx)`;
  }

  const options: { eventType: string; deliverAt: string; meta: Record<string, string>; key?: string } = {
    eventType: 'scheduled',
    deliverAt,
    meta: { source: 'example_server' },
  };
  if (key !== undefined && key !== '') {
    options.key = key;
  }

  const eventId = ctx.emit(message, options);

  return `Event scheduled for ${deliverAt} (eventId: ${eventId})`;
};
schedule.description =
  'Schedules a channel event for deferred delivery at a future ISO 8601 timestamp. ' +
  'Demonstrates scheduled delivery via ctx.emit() with the deliverAt option. ' +
  'The optional key is a correlation identifier for deduplication (must match /^[a-zA-Z0-9_]+$/). ' +
  'Returns the eventId synchronously — pass it to cancel-event to abort delivery before it fires.';
schedule.input = {
  message: T.string({
    required: true,
    description: 'Message to deliver as a channel event',
    minLength: 1,
    maxLength: 500,
  }),
  deliverAt: T.string({
    required: true,
    description: 'ISO 8601 timestamp for scheduled delivery (e.g., 2025-12-31T23:59:59Z)',
  }),
  key: T.string({
    description:
      'Optional correlation key for deduplication (must match /^[a-zA-Z0-9_]+$/). ' +
      'Silently ignored if invalid.',
    pattern: '^[a-zA-Z0-9_]+$',
  }),
};
// readOnlyHint: false — produces a side-effect (schedules a future channel event); not read-only
// destructiveHint: false — schedules a delivery; cannot delete or corrupt any data
// openWorldHint: true  — sets X-Mctx-Event response headers read by the dispatch worker
// idempotentHint: false — each call schedules a new distinct event; not safe to deduplicate
schedule.annotations = {
  readOnlyHint: false,
  destructiveHint: false,
  openWorldHint: true,
  idempotentHint: false,
};
server.tool('schedule', schedule);

/**
 * Cancel a pending scheduled channel event by its eventId.
 *
 * Demonstrates ctx.cancel() — the counterpart to ctx.emit() with deliverAt.
 * The eventId is the string returned by a prior call to schedule or notify.
 * Cancelling an event that has already been delivered or does not exist is safe
 * (idempotent) — the dispatch worker ignores unknown eventIds.
 */
export const cancelEvent: ToolHandler = async (args, _ask, ctx) => {
  const { eventId } = args as { eventId: string };

  log.info(`Cancelling channel event: ${eventId}`);

  if (ctx) {
    ctx.cancel(eventId);
  }

  return `Event ${eventId} cancelled`;
};
cancelEvent.description =
  'Cancels a pending scheduled channel event by its eventId. ' +
  'Demonstrates ctx.cancel() — pass the eventId returned by schedule or notify. ' +
  'Cancelling an already-delivered or non-existent event is safe (idempotent).';
cancelEvent.input = {
  eventId: T.string({
    required: true,
    description: 'Event ID to cancel (as returned by schedule or notify)',
    minLength: 1,
  }),
};
// readOnlyHint: false — produces a side-effect (cancels a pending event); not read-only
// destructiveHint: true  — cancels a pending event; the scheduled delivery is permanently aborted
// openWorldHint: true  — sets X-Mctx-Cancel response headers read by the dispatch worker
// idempotentHint: true  — cancelling the same eventId twice is safe; no additional side effects
cancelEvent.annotations = {
  readOnlyHint: false,
  destructiveHint: true,
  openWorldHint: true,
  idempotentHint: true,
};
server.tool('cancel-event', cancelEvent);

// ─── Resources ───────────────────────────────────────────────────────
//
// Resources expose data via URIs that LLM clients can read.
//   - Static resources use exact URIs (e.g., docs://readme)
//   - Dynamic resources use URI templates with {param} placeholders

/** Static resource: exact URI, no parameters. */
const readme: ResourceHandler = () =>
  'Welcome to the example App built with @mctx-ai/app. This App demonstrates tools, resources, prompts, progress tracking, and sampling.';
readme.description = 'App documentation';
readme.mimeType = 'text/plain';
server.resource('docs://readme', readme);

/** Dynamic resource: URI template extracts params automatically. */
const userProfile: ResourceHandler = (params) => {
  const { userId } = params as { userId: string };

  return JSON.stringify({
    id: userId,
    name: `User ${userId}`,
    joined: '2024-01-01',
    plan: 'pro',
  });
};
userProfile.description = 'User profile by ID';
userProfile.mimeType = 'application/json';
server.resource('user://{userId}', userProfile);

// ─── Prompts ─────────────────────────────────────────────────────────
//
// Prompts are reusable message templates that pre-fill LLM conversations.
//   - Return a string for a single user message
//   - Return conversation() for multi-role dialogue

/** Single-message prompt: a string return becomes one user message. */
const codeReview: PromptHandler = (args) => {
  const { code, language } = args as { code: string; language?: string };

  return `Please review this ${language || 'code'} for bugs, security issues, and improvements:\n\n\`\`\`${language || ''}\n${code}\n\`\`\``;
};
codeReview.description = 'Code review prompt';
codeReview.input = {
  code: T.string({ required: true, description: 'Code to review' }),
  language: T.string({ description: 'Programming language' }),
};
server.prompt('code-review', codeReview);

/** Multi-message prompt: conversation() builds structured user/assistant dialogue. */
const debug: PromptHandler = (args) => {
  const { error, context } = args as { error: string; context?: string };

  return conversation(({ user, ai }) => [
    user.say(`I'm seeing this error: ${error}`),
    ...(context ? [user.say(`Context:\n${context}`)] : []),
    ai.say('I will analyze the error and provide step-by-step debugging guidance.'),
  ]);
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
