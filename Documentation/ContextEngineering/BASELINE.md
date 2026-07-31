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
