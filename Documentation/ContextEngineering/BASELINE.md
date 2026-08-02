# WorkHarness Context Engineering Baseline

## Purpose

This document records the context-related behavior of WorkHarness before the
context-engineering refactor. It is a comparison point, not a target
architecture.

The audit follows:

- `agent-harness`;
- `.agent-skills/workharness-context-engineering/SKILL.md`;
- `WORKHARNESS_CONTEXT_ENGINEERING_INTEGRATION_AND_REFACTOR_PLAN.md`.

No production Swift code was changed while establishing this baseline.

## Baseline identity

| Item | Value |
| --- | --- |
| Date | 2026-07-30 |
| Git commit | `adf771d112afc5a4760525bf358bf05e6ff96914` |
| Branch | `main` |
| Working tree before audit | Clean and synchronized with `origin/main` |
| Host | Apple Silicon (`arm64`) |
| macOS test destination | macOS 15.7.2 |
| Xcode | 26.3 (`17C529`) |
| Swift | 6.2.4 |

## Build and test baseline

Command:

```bash
xcodebuild test \
  -project WorkHarness.xcodeproj \
  -scheme WorkHarness \
  -destination 'platform=macOS'
```

Result:

```text
** TEST SUCCEEDED **
Total tests: 173
Passed: 172
Failed: 0
Skipped: 1
```

The skipped test is the opt-in live Claude/MCP integration test. No existing
build or test blocker was found.

Local result bundle used for this audit:

```text
/Users/lammax/Library/Developer/Xcode/DerivedData/WorkHarness-fftiqwupyecrsohahceetcrnzibt/Logs/Test/Test-WorkHarness-2026.07.30_23-09-54-+0300.xcresult
```

The result bundle is machine-local and is not a durable project artifact.

## Current architecture and ownership

The primary dependency direction is intact:

```text
ChatPageViewModel
    → RunServiceProtocol / RunService
    → HarnessEngine
    → ContextBuilderProtocol
    → AIProvider or AgentRuntime
    → MCP / ACP / Claude CLI adapter
```

Persistence and event recording follow:

```text
HarnessEngine / ToolService / AgentRuntime mapper
    → RunRecorder
    → RunRepository
    → SQLiteRunRepository
```

Relevant DI registrations are centralized:

- `ContextBuilderProtocol`, `ContextFoldingServiceProtocol`, `RunRecorder`,
  `MultiAgentCoordinator`, and `HarnessEngine` are container-scoped in
  `DI/EngineRegister.swift`.
- `RunServiceProtocol`, `MemoryServiceProtocol`, and `RAGServiceProtocol` are
  container-scoped in `DI/ServicesRegister.swift`.
- AI providers are registered through `ProviderRegistry` in
  `DI/ProvidersRegister.swift`.
- MCP tools are registered through `ToolRegistry`, `MCPToolClientProtocol`, and
  `ToolServiceProtocol` in `DI/ToolsRegister.swift`.

No prompt or context construction was found in SwiftUI Views or feature
ViewModels. Prompt construction currently lives in `HarnessEngine`,
`MultiAgentCoordinator`, and runtime/provider adapters.

## Current context flow

### AIProvider path

```text
User message
    → RunService
    → HarnessEngine
    → optional RAG lookup
    → all current project memory loaded
    → ContextBuilder.buildSnapshot
    → ContextSnapshot.contextItems
    → AIRequest.context
    → AIProvider
    → provider-specific MCP encoding
```

Local LLM encoding turns `AIRequest.context` into one system message and then
appends the request messages.

### AgentRuntime path

```text
User message
    → RunService
    → HarnessEngine
    → optional RAG lookup
    → all current project memory loaded
    → ContextBuilder.buildSnapshot
    → AgentTask.context
    → selected AgentRuntime
```

Delivery then diverges:

- Claude CLI renders the snapshot into its command-line prompt.
- Cursor ACP sends only `AgentTask.prompt` through `session/prompt`; the
  snapshot is not currently encoded into the ACP request.

### Multi-agent path

```text
Run goal
    → one ContextSnapshot built before execution
    → MultiAgentCoordinator
    → per-role prompt assembled by the coordinator
    → complete output of the previous step appended to the next prompt
    → same original ContextSnapshot attached to every AgentTask
```

The per-role prompt is separate from `ContextBuilder` policy and is not
budgeted.

### Tool path

```text
Agent/MCP gateway request
    → ToolService
    → approval policy
    → MCPToolClient
    → MCP server
    → ToolResult.output
    → full output returned to caller
    → full output copied into RunEvent.toolResult.message
```

Artifacts returned by MCP are also appended to `Run.artifacts` and represented
by an `artifactCreated` event.

## Context source inventory

The classifications in this table describe current behavior. They do not imply
that the current behavior is correct.

| Source | Current owner | Current classification | Retrievable later? | Persisted? | Current bound | Sensitive? | Current retention |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Current user message / goal | `RunService` → `HarnessEngine` | Required now | Yes, from `Run.goal` and events | Yes | No explicit limit | Yes | `Run.goal`, `userMessage` event, provider/runtime request |
| Agent system prompt | `Agent` | Not included | Yes, from `Agent` | With `Run.agents` | No explicit limit | Possible | Stored but not delivered by `ContextBuilder` |
| Project name | `ProjectService` | Included when a project exists | Yes | Yes | No explicit limit | Low | Snapshot text and `contextBuilt` event |
| Project root | `ProjectService` | Included when a project exists | Yes | Yes | No explicit limit | Yes | Snapshot text and `contextBuilt` event |
| Auto-approval instruction | `ContextBuilder` | Required in auto mode | Yes, static source | Indirectly | Static | Security-relevant | Copied into `contextBuilt` event |
| Recent run summary | `ContextBuilder` input | Dormant | Potentially | No current producer | No explicit limit | Possible | Builder supports it, Engine does not supply it |
| Folded context summary | `ContextFoldingService` | Included after manual compaction | Yes, from event metadata | Yes | No token limit | Yes | Full event message plus JSON in metadata |
| Selected file paths | `ContextBuilder` input | Dormant | Yes | No current producer | No explicit limit | Possible | Builder supports names only |
| User attachments | `RunContextAttachmentService` / `Run` | Required by current behavior | Yes, from `Run` | Yes | 256 KB per file; no count or total-token bound | Yes | Full content in `Run`, request context, and `contextBuilt` event |
| Project memory | `MemoryService` | All items included | Yes, by memory ID | Yes | 20,000 characters per item; no item-count or total-token bound | Yes | Memory table, request context, and `contextBuilt` event |
| RAG citations and quotes | `RAGService` | Included when RAG is enabled | Yes, by source/chunk ID | Partially | Retrieval `topK`; no local quote/token bound | Yes | Request context and `contextBuilt` event |
| Safety mode | `AppSettingsService` | Required configuration | Yes | Yes | Enum | Security-relevant | `contextBuilt` metadata |
| Token budget | `AppSettingsService` / `Agent.ContextPolicy` | Declared but not enforced | Yes | Yes | Defaults to 16,000 input / 2,000 output in app DI | No | Passed to request and snapshot input |
| Multi-agent role instructions | `AgentProfileService` / `MultiAgentCoordinator` | Required per role | Yes | Configuration is persisted with Run | No token bound | Possible | Per-step prompt and events |
| Previous multi-agent output | `MultiAgentCoordinator` | Required by current coordinator | Yes, from events/results | Yes | No bound | Yes | Full next-step prompt and assistant event |
| Recovery event excerpts | `HarnessEngine` | Required for resume | Yes, from Run events | Yes | Last 20 events, 800 characters each | Yes | Newly generated recovery prompt |
| Tool result | `ToolService` / external agent session | Runtime-dependent | Sometimes, through artifact or rerun | Yes | No WorkHarness output bound | Yes | Full caller result and full `toolResult` event |

## Representative trace A — successful provider Run

Deterministic source:

- test: `startingRunRecordsInitialEvents`;
- provider: `TestAIProvider`;
- goal: `Create a harness run`.

### Request delivered to the provider

```text
messages:
  - role: user
    content: Create a harness run

context: []
model: test-model
tools: []
budget:
  maxInputTokens: 16000
  maxOutputTokens: null
```

`maxOutputTokens` is `null` in this test because the test constructs
`HarnessEngine` without `AppSettingsService`. The production DI graph supplies
the 2,000-token application default.

### Current RunEvent sequence

```text
runCreated
agentStarted
userMessage
providerRequestStarted
contextBuilt
providerRequestStarted
providerStreamDelta
assistantMessage
providerRequestFinished
agentFinished
runCompleted
```

There are two `providerRequestStarted` events: one before request construction
and another when the provider emits `.started`.

### Usage and result

```text
status: completed
assistant message: Hello from test provider.
input tokens: 3
output tokens: 5
cost: $0
artifacts: none
```

The usage is stored on `Run`; no dedicated usage event is emitted for this
AIProvider path.

### Context persistence

`ContextBuilder` creates a snapshot with no context items and a summary of
`No additional context was included.` The snapshot itself is not stored in a
snapshot repository. Only a `contextBuilt` event containing the summary and
metadata is persisted.

## Representative trace B — provider error

Deterministic source:

- test: `providerErrorLeavesRunFailed`;
- provider: `FailingAIProvider`;
- goal: `Exercise failure path`;
- provider error: `Provider failed.`

### Request delivered to the provider

The request has the same baseline shape as trace A: one user message, no
additional context, no tools, and the agent input budget.

### Current RunEvent sequence

```text
runCreated
agentStarted
userMessage
providerRequestStarted
contextBuilt
providerRequestStarted
providerRequestFailed
error
runFailed
```

Expected absences:

```text
agentFinished
runCompleted
```

### Usage and result

```text
status: failed
input tokens: 0
output tokens: 0
cost: $0
artifacts: none
```

The failing provider does not emit usage.

## Representative tool retention trace

Deterministic source:

- test: `toolServiceRoutesSafeFileReadThroughMCPAndRecordsEvents`;
- tool: `file.read`;
- result: `let value = 42\n`.

Event sequence:

```text
toolCallRequested
toolCallStarted
toolCallFinished
toolResult
```

The complete result is returned as `ToolResult.output` and copied into
`RunEvent.message`. There is no preview limit, output hash, byte count,
truncation marker, retention policy, or artifact fallback for a large result.

## Persistence baseline

SQLite currently contains tables for:

- `runs`;
- `run_events`;
- `projects`;
- `app_state`;
- `memory_items`.

There is no `context_snapshots` table.

Each event is currently stored twice by `SQLiteRunRepository`:

1. inside the encoded `Run.events` array in `runs.payload`;
2. as its own encoded payload in `run_events`.

Consequences relevant to context engineering:

- full `contextBuilt.message` data is duplicated;
- full `toolResult.message` data is duplicated;
- Run attachments are stored in `runs.payload`;
- `contextSnapshotId` is not resolvable to a persisted snapshot;
- there is no explicit clearing or expiration policy for raw context.

The broader Run/event persistence normalization is not part of the first
refactoring slice. It must remain visible as follow-up work.

## Current token and cost behavior

- Settings expose default maximum input and output token values.
- `HarnessEngine` passes `TokenBudget` into both `ContextBuildInput` and
  `AIRequest`.
- `ContextBuilder` does not apply that budget.
- Input estimation counts whitespace-separated words, not model tokens.
- Provider context-window capability is not combined with the configured
  budget or output reservation.
- Local LLM forwarding uses only `maxOutputTokens`; no local input enforcement
  is performed.
- Simple provider and single AgentRuntime paths replace Run usage with the
  latest usage value.
- Multi-agent execution accumulates usage across steps.
- Actual provider input usage cannot currently be reconciled with a persisted,
  resolvable context snapshot.

## Existing test protection

Current tests cover:

- basic ContextBuilder project metadata and ordering assumptions;
- conditional auto-approval instruction;
- attachments reaching `AIRequest.context`;
- attachments present on an `AgentTask.context` object;
- project memory inclusion;
- RAG citation inclusion and retrieval settings;
- manual context folding and `contextCompacted` event creation;
- token budget forwarding to `AIRequest`;
- context construction through `HarnessEngine`;
- MCP provider mapping;
- tool event sequencing and artifact recording;
- DI resolution of `ContextBuilderProtocol`;
- provider error state and RunEvent behavior;
- ACP and Claude runtime lifecycle behavior.

These tests protect the current object graph, but several do not verify the
final bytes or text delivered across the provider/runtime boundary.

## Missing characterization tests

Before changing production behavior, add focused tests for:

1. Cursor ACP `session/prompt` contains the built context exactly once.
2. Claude process prompt contains each context section exactly once.
3. Local LLM message encoding preserves deterministic context section order.
4. `contextBuilt` does not expose raw attachment, memory, RAG, secret, or tool
   content.
5. Identical input produces an identical ordered context plan.
6. Input budget is enforced below, at, and above the boundary.
7. Mandatory overflow fails explicitly.
8. Optional overflow creates observable omission metadata.
9. All-memory loading is replaced by a deterministic bounded selection.
10. Multi-agent previous output is bounded or replaced by an addressable
    handoff.
11. Tool result events store bounded metadata rather than unbounded output.
12. Usage is aggregated consistently across repeated provider and runtime
    requests.
13. A context snapshot ID resolves to retained metadata or is not advertised as
    resolvable.
14. Missing, stale, unauthorized, and malformed source references fail safely.

## Findings

### P0 — correctness, security, or data-retention risk

#### P0.1 Cursor ACP drops the built context

`HarnessEngine` attaches `ContextSnapshot` to `AgentTask`, but
`ACPSubprocessClient` sends only `task.prompt` to `session/prompt`.

Impact:

- attachments, project memory, RAG results, safety instructions, and folded
  context are not delivered to Cursor through this path;
- `contextBuilt` still claims that context was constructed;
- the existing attachment test checks the intermediate `AgentTask`, not the ACP
  wire request.

#### P0.2 Raw context is persisted without an explicit retention policy

`contextBuilt.message` is the complete `ContextSnapshot.summary`, and the
summary is the joined raw context items.

Impact:

- attachment contents, project memory, RAG quotes, project paths, and folded
  context can enter the Run timeline and SQLite;
- data is duplicated through current Run/event persistence;
- no redaction, hash-only mode, expiration, or raw-content clearing rule is
  defined.

### P1 — architecture or uncontrolled-context risk

#### P1.1 Claude receives duplicate context

`ContextSnapshot.summary` already joins `contextItems`; Claude then appends both
`summary` and `contextItems` to its prompt.

#### P1.2 Declared input budget is not enforced

`ContextBuildInput.tokenBudget` is unused. Mandatory and optional content have
no overflow policy, and provider context-window capability is not applied.

#### P1.3 Context policies are mostly dormant

`Agent.systemPrompt`, `ContextPolicy.includeGitDiff`,
`includeRecentRunSummary`, `includeMemoryFacts`, and
`MemoryPolicy.canReadMemory` do not affect context construction.

#### P1.4 Project memory and attachments can grow beyond the model budget

Every project memory item is loaded. Attachments have a per-file byte limit but
no count or aggregate token limit.

#### P1.5 Multi-agent handoff is unbounded and outside ContextBuilder policy

The complete previous step output is appended to the next prompt, while one
original snapshot is reused for all roles.

#### P1.6 Tool outputs are unbounded at the WorkHarness event boundary

The complete MCP result is copied into `toolResult.message`, without preview,
pagination, artifact fallback, or retention metadata.

### P2 — observability and test gaps

- `contextSnapshotId` is emitted but cannot be resolved.
- `contextBuilt` records raw content but not typed source reasons, priorities,
  freshness, retention, omissions, truncations, or delivery mode.
- Word count is labeled as a token estimate.
- Provider input/output usage is not emitted consistently as a dedicated
  append-only event.
- Simple provider requests create duplicate `providerRequestStarted` events.
- Existing runtime tests stop at `AgentTask.context` rather than the adapter
  boundary.
- Run usage replacement versus multi-agent accumulation is inconsistent.
- RunEvents are persisted both inside `runs.payload` and `run_events`.

### P3 — optional optimization or deferred architecture

- Exact provider tokenizers.
- Automatic compaction thresholds.
- Structured cross-session notes.
- A dedicated Context Inspector UI.
- Context quality scoring.
- Provider-specific cached prompt accounting.
- Full Run/event persistence normalization.

These items are not required for the first refactoring slice.

## Approved first refactoring slice

The smallest coherent production slice after characterization tests is:

1. Render the existing context once for Cursor ACP.
2. Render the existing context once for Claude CLI.
3. Add delivery-level tests for Cursor, Claude, and Local LLM.
4. Replace raw `contextBuilt.message` content with a safe bounded summary and
   metadata.
5. Record how the context was delivered:
   - `structuredMessages`;
   - `renderedPrompt`;
   - `runtimeManaged`;
   - `unsupported`.

Deliberately unchanged in this slice:

- the public Settings UI;
- RAG implementation;
- memory storage;
- ContextBuilder source-selection behavior;
- token budget enforcement;
- multi-agent context rebuilding;
- tool/MCP response contracts;
- compaction;
- SQLite schema.

Budget enforcement and the typed context-plan contract should begin only after
the adapters reliably deliver one canonical context representation.

## Step 1 implementation result

Completed on 31.07.2026:

- Cursor ACP now receives the selected `ContextSnapshot.contextItems` once
  through a canonical rendered prompt.
- Claude CLI uses the same canonical rendering and no longer appends
  `ContextSnapshot.summary` and `contextItems` as duplicate sections.
- Local LLM retains structured-message delivery with one context system
  message.
- `ContextSnapshot` and runtime descriptors record a typed delivery mode:
  `structuredMessages`, `renderedPrompt`, `runtimeManaged`, or `unsupported`.
- `contextBuilt` now persists a bounded summary plus counts, snapshot/provider/
  agent IDs, token estimate, delivery mode, and safety mode instead of raw
  selected context.
- Delivery-boundary characterization tests cover Cursor ACP, Claude CLI, Local
  LLM, and safe `contextBuilt` metadata.

Finding status after this slice:

- P0.1 is resolved for the existing Cursor ACP path.
- The `contextBuilt` portion of P0.2 is resolved. Full attachment, Run payload,
  event-retention, redaction, and expiration policy remains deferred.
- P1.1 is resolved for the existing Claude CLI path.
- P1.2 through P1.6 remain deliberately unchanged.

Verification:

- 4 focused context-delivery tests passed.
- The complete serial test plan passed: 176 passed and 1 opt-in live
  Claude/MCP test remained skipped.
- 4 UI test invocations passed when UI parallelization was disabled. The
  default parallel UI run reproduced an existing macOS activation conflict
  (`Running Background`) and is not caused by the context-delivery paths.

## Step 2 implementation result

Completed on 31.07.2026:

- `ContextSnapshot` is now the minimal provider-neutral context contract behind
  the existing `ContextBuilderProtocol` boundary; no parallel builder or
  provider DTO was introduced.
- Context is represented as deterministic ordered `ContextSection` values.
  The legacy `contextItems` delivered to providers/runtimes are derived from
  those sections, preserving the existing model-visible text and order.
- Every selected source records a typed source kind, purpose, classification,
  priority, freshness, estimated token count, retention policy, and sensitive
  data flag.
- The snapshot records configured input tokens, reserved output tokens, and
  the provider context-window limit when the provider reports one.
- Typed omission models exist for the next budget slice, but no source is
  omitted or truncated in Phase 2.
- `contextBuilt` exposes safe section/source counts, section order, and known
  window constraints without storing source content or sensitive source IDs.
- Existing encoded `ContextSnapshot` values remain decodable when the new
  contract fields are absent.

Deliberately unchanged:

- input budgets and provider limits are recorded but not enforced;
- source selection remains identical, including eager project memory and
  attachment inclusion;
- no new retrieval, compaction, tool-result, persistence, or UI behavior was
  added;
- runtime descriptors do not yet expose provider context-window limits.

Verification:

- 7 focused contract and delivery tests passed.
- The complete serial test plan passed: 179 passed and 1 opt-in live
  Claude/MCP test remained skipped.
- The successful provider trace retains the same user message and ordered
  context text; only provider-neutral metadata was added before adapter
  encoding.

## Step 3 implementation result

Completed on 31.07.2026:

- `ContextBuilder` now applies an effective WorkHarness-owned input budget:
  `min(configured input limit, provider context window - reserved output)`.
  When one limit is unknown, the known limit is used.
- The objective, active safety instruction, and user-selected attachments are
  mandatory. They fail with a typed `ContextBuildError` before provider
  invocation when they cannot fit.
- Optional sections are selected deterministically by priority. Trusted recent
  and folded summaries plus RAG evidence have precedence over project metadata,
  selected-file references, and project memory.
- Selection is priority-based, but included sections are delivered in their
  original canonical order.
- Optional overflow produces typed `ContextOmission` values. No source is
  silently truncated.
- Token estimation is behind `ContextTokenEstimatorProtocol`; the current
  implementation remains the documented whitespace approximation.
- `contextBuilt` records effective budget, included input estimate, omission
  count/reasons/section kinds, and omitted-token estimate without logging
  source content or sensitive source IDs.
- Cancellation and estimator failures stop context construction explicitly.

Deliberately unchanged:

- provider/runtime-managed instructions and tool schemas are not measurable by
  the current WorkHarness contract and are not included in this estimate;
- AgentRuntime descriptors still do not report model context-window limits, so
  those paths use the configured input limit;
- memory, RAG, and attachments are still loaded before selection; just-in-time
  retrieval remains a later phase;
- no partial string truncation, automatic compaction, tool/history bounding,
  persistence, or UI was added.

Verification:

- 8 focused budget-policy tests cover below-budget, exact-boundary, optional
  overflow, mandatory overflow, stable priority, smaller provider window,
  cancellation, estimator failure, Run failure before provider invocation, and
  safe omission metadata.
- The complete serial test plan passed: 187 passed and 1 opt-in live
  Claude/MCP test remained skipped.
- One RAG fixture now reserves 200 output tokens for its 1,000-token fake
  provider instead of the invalid previous 2,000-token reservation.

Finding status after this slice:

- P1.2 is resolved for context owned and measurable by WorkHarness.
- P1.4 is mitigated at the model-input boundary; eager loading and aggregate
  source retrieval remain unresolved.
- P2 omission, effective-budget, and estimated-input observability gaps are
  resolved for `contextBuilt`; exact token usage and snapshot resolvability
  remain open.

## Step 4 implementation result

Completed on 31.07.2026:

- `ToolService` applies one typed retention policy before a result reaches the
  agent-facing MCP gateway or `RunEvent`.
- Results of at most 12,000 characters remain inline. Larger results are
  redacted, written once to a `tool-result` artifact under WorkHarness
  Application Support, and replaced by a 2,000-character factual preview plus
  an artifact reference.
- `ToolResultRetention` records storage disposition, original and retained
  character counts, redaction state, artifact ID, and explicit retention.
  Legacy encoded `ToolResult` values decode as inline request-scoped results.
- Every WorkHarness MCP tool advertises `_output_offset` and `_output_limit`.
  These reserved controls are removed before downstream MCP invocation and
  produce deterministic character windows capped by the inline limit.
- Tool errors are redacted and limited to 2,000 characters before both
  `toolCallFailed` persistence and caller exposure.
- Agent-facing references use artifact IDs when storage is outside the current
  workspace, and `artifactCreated` metadata no longer copies host filesystem
  paths into RunEvents.
- Multi-agent execution now gives the next role only the preceding role's
  bounded handoff. Outputs over 12,000 characters become
  `multi-agent-handoff` artifacts; only the first 4,000 streamed characters are
  retained as delta events, followed by one explicit bound marker.
- Full results are no longer copied into a second full `assistantMessage` or
  `toolResult` event when artifact fallback is active.
- Artifact storage is behind `RunArtifactStoreProtocol` and is shared through
  DI by tool retention and multi-agent handoff policy.

Retention rules:

- small successful tool output: inline for the request and bounded RunEvent;
- large successful tool output: persistent artifact until explicit cleanup,
  with only a preview/reference in active context and RunEvent;
- tool error: bounded request/event text; overflow is discarded after the
  failure is reported;
- large multi-agent output: persistent artifact until explicit cleanup;
  bounded handoff lives only through subsequent execution state and events;
- existing MCP-provided artifacts remain unchanged and addressable.

Measured deterministic before/after traces:

- the large-tool fixture produces 672 raw characters. Previously all 672
  characters would reach both the caller and `toolResult.message`; now neither
  surface contains the full payload, the 651-character redacted source exists
  once in a resolvable artifact, and the event records typed counts and
  disposition;
- the multi-agent fixture produces 750 characters. The next role and
  `assistantMessage` receive only the bounded reference/preview, the tail marker
  is absent from active handoff context, and the complete output is resolvable
  from the artifact;
- no additional provider inference is introduced, so provider tokens and cost
  are unchanged; the policy adds local redaction/file-write latency only for
  oversized results. Exact local latency was not promoted to product telemetry
  in this slice.

Verification:

- 5 focused retention tests cover large results, repeated calls, deterministic
  windows, bounded/redacted failures, artifact resolvability, and legacy
  decoding.
- The coordinator integration test covers bounded next-role context, clearing
  the consumed raw handoff, stream-event limits, and artifact resolution.
- The MCP gateway regression verifies pagination controls are advertised,
  applied, and not forwarded as downstream tool arguments.
- The complete serial test plan passed: 193 passed and 1 opt-in live
  Claude/MCP test remained skipped (194 total, 0 failed).

Deliberately unchanged:

- Cursor and Claude may retain runtime-managed session history outside the
  WorkHarness context contract; their current adapters expose no measurable
  history window to compact safely.
- Artifact content is resolvable by `RunArtifact` path and the Runs UI, but
  there is no path-free artifact-content tool for agents yet.
- Persistent artifacts do not yet have automatic deletion tied to Run removal;
  the metadata therefore says `persistent-until-explicit-cleanup`.
- downstream MCP servers may still generate a large response internally;
  WorkHarness bounds it immediately at its own agent/event boundary.
- no semantic summarization model or new memory subsystem was introduced.

Finding status after this slice:

- P1.6 is resolved at the WorkHarness MCP gateway and RunEvent boundary.
- P1.5 is mitigated for previous-step handoff and persisted stream growth;
  per-role prompt/token budgeting remains a later slice.
- P2 tool-result retention, size, redaction, and artifact-reference metadata
  are now observable without persisting the original raw payload in events.

## Step 5 implementation result

Completed on 31.07.2026:

- `contextBuilt` now records typed JSON observations for every observed
  selected source, section token estimate, and omission. Source observations
  include kind, purpose, selection reason, priority, freshness, estimated token
  count, and retention policy.
- Source IDs are represented by stable SHA-256-derived opaque IDs. Filesystem
  paths, RAG source paths, attachment IDs, memory IDs, and raw content are not
  copied into observability events.
- Observation arrays are bounded to 128 selected sources and 128 omissions.
  Explicit unrecorded counts disclose metadata overflow instead of silently
  hiding it.
- `contextBuilt` records monotonic build duration in milliseconds alongside
  configured input limit, provider context window, output reservation,
  effective input limit, total estimate, and delivery mode.
- Failed construction now emits `contextBuildFailed` before provider
  invocation. Mandatory overflow records safe source ID, required tokens and
  available tokens without logging the source or error content.
- RAG execution emits `contextRetrievalStarted` and
  `contextRetrievalFinished` with a correlation ID, retrieval bounds, duration,
  candidate/result counts, status, and opaque selected citation IDs. The query,
  quote, answer and source path remain absent.
- Provider, AgentRuntime, and multi-agent usage paths emit `usageUpdated` when
  actual usage is reported. The event links to `contextSnapshotId` and records
  input/output/total tokens, cost, estimated input, and estimate delta.
- The existing Runs Event Inspector pretty-prints observation JSON. No new
  screen, repository access from UI, or parallel telemetry subsystem was
  introduced.
- Existing `contextCompacted` remains the explicit compaction event; this slice
  did not add automatic compaction.

Representative trace comparison:

- before Step 5, the provider trace exposed only aggregate context counts and
  the Run-level final usage; selected source reasons, section estimates, build
  time, and estimate-versus-actual usage could not be correlated;
- after Step 5, the same deterministic provider Run exposes one opaque
  objective source, its selection reason, effective 50-token input limit under
  a 100-token provider window, build duration, reported 9 input / 4 output
  tokens, `$0.01` cost, and the delta from the linked context estimate;
- the output and context delivered to the provider are unchanged. The change
  adds local metadata serialization and append-only events, not provider calls,
  model tokens, or provider cost.

Verification:

- 5 focused observability tests cover safe selected-source metadata, section
  estimates, omission reasons, build failure, actual usage linkage, successful
  retrieval events, duration fields, and absence of raw path/attachment/RAG
  content.
- Existing ContextDelivery and ContextBudget suites continue to pass.
- The Runs ViewModel regression verifies JSON observation values are rendered
  as readable multiline inspector metadata.
- The complete serial test plan passed: 198 passed and 1 opt-in live
  Claude/MCP test remained skipped (199 total, 0 failed).

Deliberately unchanged:

- `ContextSnapshot` is still not persisted in a dedicated repository; the
  observation is correlated through its snapshot ID and safe event metadata.
- Actual usage remains unavailable when a provider/runtime does not report it;
  WorkHarness does not present estimates as actual usage.
- runtime-managed Cursor/Claude conversation history is still opaque to
  WorkHarness and cannot yet be measured or compacted safely.
- source-observation metadata is intentionally bounded; unrecorded counts are
  visible, but a separate observation artifact is not created.
- exact model tokenizer support remains behind the estimator backlog; current
  context estimates retain the documented approximation.

Finding status after this slice:

- P2 selected-source, section-cost, omission, provider-limit, duration,
  retrieval, and actual-usage observability gaps are resolved at the RunEvent
  boundary.
- Snapshot resolvability, runtime-managed history telemetry, and exact
  tokenizer reconciliation remain open.

## Step 6 implementation result

Completed on 31.07.2026:

- Project memory is no longer requested from `MemoryService` as an unbounded
  content array before context construction. `HarnessEngine` first requests
  typed `MemoryReference` metadata and resolves only selected IDs.
- `ContextMemoryRetrievalPolicy` sorts references deterministically by newest
  creation date and stable ID, then applies both production limits: at most 8
  items and at most 8,000 referenced content characters.
- Selection respects `ContextPolicy.includeMemoryFacts` and
  `MemoryPolicy.canReadMemory`. Disabled memory policy produces no selected
  references or content resolution.
- Resolution remains project-scoped. Missing selected IDs are omitted safely,
  reported as invalid references, and do not block the optional-memory provider
  request. Reference creation dates provide the explicit recency signal used
  for selection.
- Resolved memory enters `ContextBuilder` as typed `MemoryItem` values, so each
  context source preserves its real memory ID as provenance instead of an
  unstable array index. RunEvent observations continue to expose only opaque
  hashed IDs.
- `contextRetrievalStarted` and `contextRetrievalFinished` now distinguish
  `projectMemory` retrieval and record limits, candidate/selected/resolved/
  omitted counts, selected and retrieved character counts, duration, status,
  and safe source IDs without recording memory content.
- The existing ContextBuilder token budget remains the second guard. A
  metadata estimate that understates resolved content cannot bypass the final
  provider input budget.

Representative trace comparison:

- before Step 6, three available project-memory values were all copied into a
  single section before budget selection; the Engine had no narrow reference
  selection or record of which stored items it attempted to resolve;
- after Step 6, the deterministic Engine fixture sees three references, selects
  and resolves only the two newest IDs, delivers `RECENT_MEMORY` and
  `MIDDLE_MEMORY`, and leaves `OLD_MEMORY` external. The Run completes with one
  provider request and no raw memory content in retrieval or context-build
  events;
- the production-policy fixture starts with 10 references / 10,000 referenced
  characters in reversed input order and consistently selects the 8 newest /
  8,000 characters, omitting 2 before content resolution;
- the small representative ContextBuilder section decreases from 5 estimated
  whitespace tokens with all three facts to 4 with the two selected facts.
  The deterministic provider does not report actual token usage or cost, so
  WorkHarness correctly leaves those values unavailable rather than treating
  estimates as provider usage;
- retrieval latency is measured in the RunEvent. Tests require the duration
  field but intentionally do not assert a machine-specific millisecond value.

Verification:

- 5 focused Step 6 tests cover production-default count/character bounds,
  deterministic ordering, policy disablement, selected-ID-only resolution,
  safe event metadata, missing references, and source provenance;
- existing ContextContract, ContextBudget, and ContextDelivery suites continue
  to pass in the 20-test focused context run;
- the complete serial test plan passed: 203 passed and 1 opt-in live
  Claude/MCP test remained skipped (204 total, 0 failed).

Deliberately unchanged:

- memory selection is recency-based, not semantic. No embeddings, vector
  index, model call, or speculative memory subsystem was added;
- `SQLiteMemoryRepository` still keeps its existing in-process item collection
  for the Memory UI. The new service/engine boundary avoids copying unselected
  contents into context construction and permits a future storage-level narrow
  query without changing HarnessEngine;
- user-selected attachments remain required-now evidence and are not converted
  to optional just-in-time sources;
- RAG already uses bounded query-time retrieval and remains unchanged.

Finding status after this slice:

- the project-memory eager-delivery part of P1.4 is resolved at the Engine and
  context boundary; attachments remain aggregate-budgeted required input;
- the `includeMemoryFacts` and `canReadMemory` portion of P1.3 is active;
- semantic memory ranking remains an optional measured follow-up, not an MVP
  requirement.

## Step 7 decision result

Completed on 02.08.2026.

Decision: do not add automatic context compaction, a separate structured-notes
subsystem, or another subagent-context isolation layer for the current MVP.
Keep the existing explicit `ContextFoldingService` path available, but do not
trigger it automatically until runtime-managed history becomes measurable or a
representative failure demonstrates that the current bounded context loses
required long-horizon state.

Measured local Run snapshot:

- the durable store contained 69 Runs and 21,671 RunEvents;
- the largest Run contained 2,949 events;
- only 3 Runs built context more than once, and the maximum was 3 context
  builds in one Run;
- no persisted `contextCompacted` event existed;
- the largest inspected pre-hardening execution-loop Run contained 2,704
  `providerStreamDelta` events and 8 tool results. The tool-result messages
  totalled 109,761 characters and the largest single result was 83,478
  characters. That trace was recorded on 26.07.2026, before Step 4 introduced
  bounded previews and artifact-backed retention, so it is evidence for the
  completed tool-result fix rather than evidence that automatic compaction is
  still required.

Why event volume does not currently require automatic compaction:

- `HarnessEngine.context(...)` does not copy the Run event list into a provider
  request. It sends the current objective plus deliberately selected typed
  sections only;
- every request is constrained by `ContextBudgetPolicy`, including an output
  reservation and provider context-window limit when the runtime reports it;
- project memory is selected by reference and resolved within the 8-item /
  8,000-character pre-budget limit;
- RAG remains query-time retrieval and user attachments remain explicit
  required-now evidence;
- multi-agent streams are bounded to 4,000 persisted characters per step and
  inter-agent handoffs use a 12,000-character inline limit with a 2,000-
  character preview plus an artifact reference;
- large tool output is no longer retained inline indefinitely after Step 4.

Decision gates:

1. **Automatic compaction:** reopen only when Cursor/Claude exposes measurable
   history or context-window utilization, or when a reproducible Run fails
   because required prior state cannot fit despite the existing selection and
   budget policy.
2. **Structured notes:** do not duplicate Run, Project, ExecutionTask, artifact,
   and memory persistence. Reopen only when required cross-session state cannot
   be represented or retrieved through those typed stores. Durable Execution
   Loop recovery remains a separate product task, not a reason to place loop
   state in model context.
3. **Subagent isolation:** the current multi-agent coordinator already creates
   task-local sessions and supplies bounded, explicit handoffs. Reopen only if
   a measured cross-agent leakage or irrelevant-context failure remains after
   provider consistency work.

If automatic compaction is later approved, it must have an explicit threshold,
preserve intent, constraints, decisions, evidence, artifact references, open
issues and the next action, record an append-only `contextCompacted` event, link
the source events, and pass long-trace regression tests. Provider-internal
history must never be silently rewritten from WorkHarness estimates.

Verification and limitations:

- source-flow inspection confirms that RunEvents are persistent audit state,
  not implicit ContextBuilder input;
- existing ContextContract, ContextBudget, ContextMemoryRetrieval,
  ToolResultRetention, ContextDelivery and ContextFolding tests cover the
  mechanisms used by this decision;
- the persisted long traces predate Steps 2–6. This prevents an honest claim
  about post-hardening runtime-history utilization, but it does not justify a
  speculative mechanism: runtime-managed Cursor/Claude history is still opaque
  and WorkHarness-managed context is already bounded per request;
- Step 8 must verify provider/adapter consistency and record capability
  fallbacks before this decision can be considered part of the final context
  refactoring closeout.

Context impact:

1. No new content enters model context; existing objective and selected typed
   sections remain unchanged.
2. Complete Run history, artifacts, project state, memory storage and RAG data
   remain external and are retrieved only through their existing boundaries.
3. No new content is discarded or summarized automatically. Existing bounded
   tool/handoff policies and explicit Context Folding remain unchanged.
4. The effective per-request input budget, provider output reservation, memory
   limits, handoff limits and tool-result limits remain the active guards.
5. The decision is based on the persisted Run measurements above, source-flow
   inspection and the focused regression suites listed above.

## Step 8 provider consistency and final closeout

Completed on 02.08.2026.

Provider and runtime boundaries now convert their execution metadata into one
provider-neutral `ContextDeliveryPlan` before `ContextBuilder` is invoked. The
plan carries only the information needed by WorkHarness domain policy:

- delivery mode (`structuredMessages` or `renderedPrompt`);
- reported context-window limit;
- configured output-token reservation;
- streaming and tool support;
- usage-reporting and cancellation support.

`HarnessEngine` passes the same plan shape for direct `AIProvider` requests,
Cursor ACP, Claude CLI and multi-agent runtime requests. `ContextBuilder`
continues to own selection, section order, budgeting and omissions. Adapter-
specific encoding remains local: Local LLM emits one structured system
message, while Cursor ACP and Claude CLI render the same selected context into
their prompt format.

Capability fallback is explicit in the safe `contextBuilt` metadata:

- an unknown provider window records whether the configured WorkHarness input
  budget is used or no limit is available;
- a missing output reservation is recorded as `outputReservation:none`;
- unknown usage reporting records `usageReporting:observeEvents`;
- unknown cancellation support records `cancellation:boundaryContract`.

These fields contain capability state only. They do not copy prompt content,
tool output, memory contents or attachment contents into RunEvents.

Representative deterministic comparison:

| Metric | Structured provider | Rendered runtime | Result |
| --- | --- | --- | --- |
| Context sections | Same typed sections | Same typed sections | Equal |
| Section order | Deterministic builder order | Deterministic builder order | Equal |
| Omissions | Same IDs and reasons | Same IDs and reasons | Equal |
| Estimated input tokens | Same estimate | Same estimate | Equal |
| Encoding | Structured system message | Rendered prompt | Intentionally different |
| Raw attachment in `contextBuilt` | Absent | Absent | Equal |
| Actual output tokens / cost | No live model invoked | No live model invoked | Not generated |
| Network latency | No live model invoked | No live model invoked | Not generated |

The comparison intentionally uses deterministic fake boundaries. Step 8 does
not spend provider credits or present model/network variance as context-policy
evidence. Existing provider usage events still link actual input/output tokens,
cost and estimates to the same `ContextSnapshot` when a real backend reports
them.

Verification:

- macOS build succeeded;
- all 7 focused `ContextDeliveryTests` passed, including Cursor ACP, Claude
  CLI, Local LLM, legacy capability decoding, normalized boundary capability
  equality, safe fallback metadata and provider-neutral policy equivalence;
- the full scheme executed 210 tests successfully and skipped the existing
  opt-in live test; the only failure was the UI test runner timing out while
  enabling macOS Automation Mode before UI tests initialized;
- a separate UI-target retry reproduced an Automation Mode initialization hang
  and was interrupted after 195 seconds;
- no unit, integration, build or context-policy assertion failed.

Result: the ContextPlan implementation is complete for the current MVP.
Provider selection changes encoding and reported capabilities, not WorkHarness
context policy. Persistent artifact cleanup, host-path-free artifact retrieval
and runtime-managed history telemetry remain explicit post-MVP roadmap work.

Context impact:

1. The same objective and selected typed sections enter model context; the new
   capability plan controls delivery and observability, not prompt content.
2. Run history, artifacts, unselected memory, RAG storage and provider-internal
   history remain external and are retrieved through existing typed services.
3. No new content is discarded or summarized. Existing deterministic budget,
   omission, bounded tool-result and handoff behavior remains unchanged.
4. The configured input budget, output reservation and reported provider
   context window determine the effective limit; unknown capabilities now
   produce explicit fallback metadata.
5. Behavior was verified by exact structured-vs-rendered snapshot comparison,
   adapter delivery tests, safe-event assertions, build and the 210-test
   regression run.

## Comparison metrics for later slices

Every representative before/after trace should compare:

- final behavior and Run status;
- exact delivered context section order;
- input and output tokens;
- estimated and actual input size;
- latency;
- cost;
- included source IDs;
- omitted source IDs and reasons;
- raw sensitive content present in RunEvents;
- duplicate context content;
- artifact and reference resolvability.

## Baseline context-impact note

1. **What currently enters model context:** the current user request plus
   project metadata, auto-approval instruction, optional folded summary,
   attachments, all project memory, and RAG citations when those sources are
   available. Claude receives the selected items twice; Cursor ACP currently
   receives only the task prompt.
2. **What remains external:** project repositories, complete Run history,
   memory storage, RAG index, artifacts, and files remain external, but current
   selection often copies full memory, attachment, or quote content into the
   request rather than retaining typed references.
3. **What is discarded, summarized, or compacted:** no automatic active-context
   clearing exists. Manual folding stores a generated summary in a
   `contextCompacted` event. Cursor ACP silently discards the supplied snapshot
   at its adapter boundary.
4. **Current limiting mechanism:** attachment size is limited to 256 KB per
   file and RAG has retrieval-count settings. The declared token budget,
   provider context window, total attachment size, memory count, multi-agent
   handoff, and tool output are not enforced as a combined context limit.
5. **How this baseline was verified:** source-flow inspection, existing
   deterministic provider/tool/runtime tests, DI inspection, SQLite schema
   inspection, and a successful full 173-test `xcodebuild test` run.

## Exit criteria status

- [x] Project builds.
- [x] Full current test baseline recorded.
- [x] Existing skipped test recorded.
- [x] Representative successful provider Run identified.
- [x] Representative provider-error Run identified.
- [x] Provider messages and current event sequences captured.
- [x] Tool-result retention captured.
- [x] Token and cost behavior captured.
- [x] Persistence and ContextSnapshot behavior captured.
- [x] Dependency direction and DI registrations confirmed.
- [x] Initial P0–P3 findings recorded.
- [x] Missing characterization tests recorded.
- [x] No production code changed.
