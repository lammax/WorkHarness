# WorkHarness Development Roadmap

Updated: 29.07.2026

WorkHarness is a local-first macOS SwiftUI AI Agent Harness. It must stay Run-centric, provider-agnostic, agent-agnostic and safety-aware. Do not treat it as a generic chat app.

## Engineering Priorities

The following priorities are global and apply to every implementation step.

Architecture quality has higher priority than implementation speed.

Long-term maintainability has higher priority than short-term convenience.

When there is a trade-off, always prefer the solution that keeps WorkHarness:

- modular
- observable
- replaceable
- testable
- local-first

Avoid introducing shortcuts that increase coupling or bypass architectural boundaries.

Every new feature should strengthen the architecture rather than weaken it.

## Current State

WorkHarness already has:

- macOS SwiftUI skeleton.
- Swinject DI.
- Screen/Page architecture.
- Run-centric domain model.
- `RunEvent` model.
- `HarnessEngine` v0.
- `RunRecorder`.
- `RunService`.
- `InMemoryRunRepository`.
- `MockAIProvider`.
- Provider abstraction.
- `ProviderRegistry`.
- `ProviderService`.
- Provider Settings UI.
- Active provider selection.
- Durable AppSettings boundary.
- `UserDefaultsAppSettingsService`.
- Project Core v1.
- `ProjectRepositoryProtocol`.
- `ProjectServiceProtocol`.
- Current project state.
- Project Selector UI v1.
- `UserDefaultsProjectRepository`.
- Durable current project selection.
- Run Timeline v1.
- Run detail timeline.
- Event inspector.
- Token/cost summary in Runs UI.
- Artifacts placeholder.
- Approval / Safety Foundation v1.
- `ApprovalServiceProtocol`.
- Approval request lifecycle.
- Safety modes.
- Approval UI surface.
- Approval RunEvents.
- CLI Infrastructure v1.
- `ProcessRunnerProtocol`.
- `ProcessRunner`.
- Process stdout/stderr streaming.
- Process timeout and cancellation.
- Process exit/error mapping.
- MCP-backed provider adapter shape.
- `MCPProviderClientProtocol`.
- `MCPBackedAIProvider`.
- Codex CLI MCP provider descriptor.
- Cursor CLI MCP provider descriptor.
- Local LLM MCP provider descriptor.
- Local LLM MCP JSON-RPC client path in `MCPProviderClient`.
- Local LLM provider registration in `ProviderRegistry`.
- Local LLM provider settings selectability.
- `LocalLLMMCPServer` in `/Users/lammax/Documents/ThisIsMy/Programming/AI/MCP_server`.
- Local LLM MCP tools:
  - `local_llm_list_models`.
  - `local_llm_describe_model`.
  - `local_llm_generate`.
  - `local_llm_health`.
- ContextBuilder v1.
- `ContextBuilderProtocol`.
- `ContextBuilder`.
- `ContextSnapshot` provider context path.
- `contextBuilt` RunEvents.
- Tools Foundation v1.
- `ToolProtocol`.
- `ToolRegistry`.
- `ToolPermission`.
- `ToolResult`.
- `ToolServiceProtocol`.
- `ToolService`.
- `FileReadTool`.
- `FileWriteTool`.
- `ShellTool`.
- `GitTool`.
- `MCPToolAdapter`.
- MCP-only tool execution path.
- Approval-gated MCP tool execution.
- Tool RunEvents:
  - `toolCallRequested`.
  - `toolCallStarted`.
  - `toolCallFinished`.
  - `toolCallFailed`.
  - `toolResult`.
- Persistence v1.
- `SQLiteDatabase`.
- `SQLiteRunRepository`.
- `SQLiteProjectRepository`.
- SQLite-backed Run, RunEvent and Project storage.
- `WORKHARNESS_SQLITE_PATH` test override for isolated repository tests.
- Token / Cost Statistics v1.
- `UsageStatisticsServiceProtocol`.
- `UsageStatisticsService`.
- Run, provider and daily usage aggregates.
- Stats page v1 in the main navigation.
- Settings v1.
- Editable durable AppSettings.
- Durable safety mode setting.
- Durable MCP server base path setting.
- Durable Local LLM endpoint and model settings.
- Durable default token budget settings.
- Settings page controls that save and reset app parameters.
- Explicit Execution Backend selector showing the provider used by the next Run.
- Provider transport and locality labels in Settings.
- Tests passing for the current stable slice.
- Project Memory v1.
- `MemoryRepositoryProtocol` with SQLite-backed storage.
- `MemoryServiceProtocol` with project memory write/read boundaries.
- Memory write policy rejecting empty, oversized and sensitive content.
- `memorySaved` RunEvents for run-linked memory writes.
- Basic Memory page for the selected project.
- AgentRuntime foundation with capability-based agent sessions.
- ACP client/runtime contracts isolated under `AgentRuntime/ACP`.
- ACP event mapping into existing `RunEvent` timeline concepts.
- ACP subprocess transport with JSON-lines stdin/stdout and event codec.
- ACP subprocess client with initialize handshake, capability discovery and session controls.
- Generic `ACPAgentFactory` for registering executable-backed agent definitions.
- Cursor ACP executable discovery and `cursor.acp` runtime registration.
- Durable Agent runtime selection in Settings → Execution & Providers.
- Selected AgentRuntime execution path through `HarnessEngine` with ContextSnapshot and RunEvent mapping.
- Cursor ACP model picker with durable selection and `session/set_config_option` forwarding.
- ACP text delta aggregation for a single growing assistant block in Chat UI.
- App Sandbox disabled for the local-first macOS harness so approved subprocess/MCP/ACP integrations can execute external agents.
- MCP-backed RAG client and service boundary.
- RAG index/search/clear operations routed to the existing `RAGMCPServer`.
- RAG citations mapped into `ContextSnapshot` through an opt-in agent context policy.
- MCP-backed `RAGSearchTool` descriptor.
- Durable RAG settings with Settings UI controls for enablement, chunking, retrieval, filtering, Top-K and threshold.
- Cursor ACP permission requests routed through the shared `ApprovalService` and Approval UI.
- ACP permission decisions returned to Cursor over JSON-RPC with `allow-once` / `reject-once` mapping.
- Claude Code CLI Agent Runtime v1 with isolated per-Run MCP configuration,
  streamed provider-agnostic events, continuation, cancellation and model
  selection.
- General-purpose Execution Loop MVP with:
  - Markdown task-source abstraction;
  - deterministic workflow-profile selection;
  - one Run per task;
  - significant child-Run progress mirrored into the controller Run;
  - validation and Auto-approve-gated commit/push;
  - current-branch execution without forced task branches;
  - task-level runtime and model snapshots;
  - visible start, pause-after-current-task, resume and stop controls;
  - Markdown execution metrics and comparison-report output.
- Claude direct-Run model routing MVP with:
  - routing disabled by default;
  - configurable Haiku fast path and Sonnet fallback;
  - a configurable 240-character threshold;
  - critical-keyword and multi-requirement heuristics;
  - immutable per-Run model selection;
  - observable routing decisions in the Run timeline.
- Cross-agent WorkHarness context-engineering policy with one version-controlled
  skill source, native Codex/Claude/Cursor discovery, mandatory project rules
  and a context-impact completion note for relevant changes.

All LLM/provider backends must go through MCP-backed provider adapters.

All tool execution must go through MCP-backed tool adapters.

Existing MCP server base contains these ready server targets:

- `DeveloperToolsMCPServer`
- `FileOperationsMCPServer`
- `GitHubMCPServer`
- `LocalLLMMCPServer`
- `MobileAutomationMCPServer`
- `RAGMCPServer`
- `SupportMCPServer`
- `UtilityMCPServer`
- `VisionBackendServer`
- `Shared`

All agent runtimes must eventually go through `AgentRuntime`, with ACP as the preferred transport.

Direct CLI provider work already done for Codex CLI and Cursor CLI was temporary scaffold and must not be extended as the final agent architecture.

## Roadmap Rules

- Do not skip foundations.
- Keep Views out of repositories, providers, tools and engine internals.
- Keep ViewModels behind service/facade boundaries.
- Add safety and observability before real shell/tool/CLI execution.
- Route every LLM/provider backend through MCP-backed provider adapters, not direct SDK/HTTP/CLI adapters inside WorkHarness.
- Route every tool execution through MCP. WorkHarness must not execute file, shell, git, RAG, browser or external service tools directly.
- Treat local tool types inside WorkHarness as descriptors/metadata only, never as fallback execution paths.
- Route every full agent integration through `AgentRuntime`; ACP is the preferred transport for agents.
- Treat MCP as the tool/provider protocol and ACP as the agent runtime protocol.
- Direction rule: MCP means `Agent -> Harness tools/resources/provider capabilities`; ACP means `Harness -> Agent`.
- Build an embedded ACP Host / ACP Client Runtime inside WorkHarness first; do not introduce a standalone ACP server or daemon until Remote Control requires it.
- Use `/Users/lammax/Documents/ThisIsMy/Programming/AI/MCP_server` as the existing local MCP server base for MCP-backed providers/tools unless a task explicitly chooses another server.
- Before adding a new MCP capability, check the existing server targets: `DeveloperToolsMCPServer`, `FileOperationsMCPServer`, `GitHubMCPServer`, `LocalLLMMCPServer`, `MobileAutomationMCPServer`, `RAGMCPServer`, `SupportMCPServer`, `UtilityMCPServer`, `VisionBackendServer` and `Shared`.
- Do not duplicate an existing MCP server capability inside WorkHarness as a local tool.
- Route local LLM model providers, such as Ollama, Qwen and llama.cpp-style backends, through the same MCP-backed provider path.
- Use `/Users/lammax/Documents/ThisIsMy/Programming/AI/LlamaLocalServer` as the existing source implementation for local LLM logic; migrate the reusable parts into the MCP server base instead of duplicating that logic inside WorkHarness.
- Treat direct local CLI providers, such as Codex CLI and Cursor CLI over `ProcessRunner`, as temporary scaffolding only.
- Treat MCP-backed Codex CLI / Cursor CLI provider descriptors as interim compatibility surfaces; the final architecture for full coding agents is ACP-backed `AgentRuntime`.
- Never branch on concrete agent names such as Codex, Cursor, Claude Code, Gemini CLI or OpenHands in `HarnessEngine`, planner, tools or UI.
- Prefer small, buildable steps with tests where behavior crosses service, repository, engine, provider or ViewModel boundaries.
- For changes affecting model context, apply
  `.agent-skills/workharness-context-engineering/SKILL.md`: prefer the smallest
  high-signal context, just-in-time retrieval, deterministic ordering, bounded
  tool outputs, explicit budgets and observable omission/compaction.
- Commit and push stable validated slices before starting broad new work.

## Completed Steps

- Step 1 - Project Selector UI v1.
- Step 2 - Durable Project Storage v1.
- Step 3 - Run Timeline v1.
- Step 4 - Approval / Safety Foundation.
- Step 5 - CLI Infrastructure v1.
- Step 6 - CodexCLIProvider v1.
- Step 7 - CursorCLIProvider v1.
- Step 8 - Provider MCP Migration v1.
- Step 9 - Local LLM MCP Provider v1.
- Step 10 - ContextBuilder v1.
- Step 11 - Tools Foundation v1.
- Step 12 - Persistence v1.
- Step 13 - Token / Cost Statistics v1.
- Step 14 - Settings v1.
- Step 15 - Context Folding v1.
- Step 16 - Memory v1.
- Step 17 - RAG v1.
- Step 18 - ACP Agent Runtime v1.
- Step 19 - Multi-Agent v1.
- Step 20 - Remote Control v1.
- Step 21 - Claude Code CLI Agent Runtime v1.

## Active Steps

- Step 22 - Mobile Remote Client v1: WorkHarness Remote Control v1 is complete;
  the production mobile client and end-to-end integration remain.
- Step 23 - Course Day 4: Local Boost v1: technical MVP is complete; submission
  evidence remains.
- Step 24 - Course Day 5: Execution Loop v1: product MVP is complete; two cloud
  attempts, one tool-capable local-model attempt and the comparison report
  remain.
- Step 25 - Course Fine-Tuning: Days 6–10:
  - Day 6 implementation is complete;
  - Day 7 code and live evaluation are complete; video remains;
  - Day 8 code and deterministic evaluation are complete; real routing video
    evidence remains;
  - Day 9 WorkHarness multi-stage inference and deterministic tests are
    complete; live comparison video remains;
  - Day 10 requirements have not been received.

## Agreed Next Implementation Sequence

Agreed: 30.07.2026.

Continue product development in this order:

1. Agent output safety and bounded artifacts:
   - detect plain-text pseudo-tool transcripts;
   - reject incomplete final answers instead of reporting success;
   - keep oversized tool results and diffs out of the Run timeline;
   - store full output as artifacts and show a bounded human-readable summary;
   - add regression coverage for oversized diffs and interrupted responses.
2. Durable Execution Loop recovery:
   - persist the selected task pool and attempt state;
   - restore paused loops after application relaunch;
   - reconcile branch, HEAD and working-tree state before resume;
   - classify token exhaustion, runtime crash, validation failure and repository
     mismatch separately;
   - retry an interrupted task as an explicit new attempt without counting it
     as first-pass success;
   - continue an existing runtime session only when that runtime supports safe
     continuation; otherwise restart the task with a recorded context snapshot.
3. Remote Control API contract verification:
   - maintain canonical request/response fixtures;
   - test health, capabilities, Runs, RunEvents and Approvals;
   - test authentication and error responses;
   - test SSE framing, ordering and reconnect cursors;
   - expose an API compatibility version through capabilities.
4. WorkHarnessMobile validation pipeline:
   - run focused checks during a task;
   - require the full build/test gate before commit;
   - add optional UI smoke validation for UI tasks;
   - retain `.xcresult`, logs and screenshots as Run artifacts;
   - distinguish code, simulator and infrastructure failures.
5. Tool-capable Local LLM AgentRuntime:
   - use Ollama behind an agent-runtime boundary;
   - route file, shell and Git actions through WorkHarness MCP tools and
     approvals;
   - preserve RunEvents and execution-loop metrics;
   - execute the Day 5 local-model comparison honestly even if the model
     completes zero tasks.
6. Model routing v2:
   - add fallback after a real fast-model runtime failure;
   - support execution-loop routing with immutable per-task model snapshots;
   - record escalation reasons, latency and cost;
   - defer calibrated confidence routing until the Day 10 requirements and
     course evidence are known.
7. Measured context-engineering hardening:
   - [x] audit current `ContextBuilder`, folding, memory/RAG and tool-result
     traces before changing their architecture;
   - [x] deliver the existing selected context exactly once through Cursor ACP,
     Claude CLI, and the structured Local LLM boundary;
   - [x] replace raw `contextBuilt` content with bounded metadata and record a
     typed delivery mode;
   - [x] classify selected context as required-now, retrievable, persistent or
     discardable;
   - [x] add typed provenance, priority, freshness, estimated token cost and
     retention metadata where the audit shows it is needed;
   - [x] enforce the effective input budget, apply deterministic overflow
     priority, fail mandatory overflow, and expose omissions through
     `ContextSnapshot` metadata and append-only RunEvents;
   - [x] replace oversized WorkHarness MCP tool results and multi-agent
     handoffs with bounded factual previews plus addressable artifact
     references; bound persisted multi-agent stream deltas and expose narrow
     output windows;
   - [x] expose safe selected-source reasons, section estimates, omissions,
     provider limits, build/retrieval duration, and reported token/cost usage
     through ContextSnapshot-linked RunEvents and the existing Runs inspector;
   - [x] replace eager project-memory delivery with metadata-first reference
     selection and deterministic just-in-time resolution, bounded to 8 recent
     items and 8,000 characters before ContextBuilder budget enforcement;
   - add cleanup for persistent context/tool artifacts and an artifact-content
     retrieval contract that does not require exposing host paths;
   - add measured history limits for runtime-managed Cursor/Claude sessions
     when their adapters expose history/context telemetry;
   - [x] compare deterministic representative traces before and after each
     completed context-policy slice and record quality, latency, token and cost
     impact in the context-engineering baseline;

Do not start parallel execution, production fine-tuned-model integration,
Notion task-source synchronization or a Dataset/Models UI before the preceding
recovery, validation and course-evidence gates are stable.

## Step 1 - Project Selector UI v1 (Done)

Goal:
Allow the user to select a working project.

Scope:

- Project selector UI.
- Manual project name input.
- Manual root path input.
- Add project.
- Select current project.
- Empty state.
- Sidebar current project display.
- ViewModel tests.

Do not add:

- File picker.
- CLI.
- RAG.
- Indexing.
- SQLite.

Done when:
The user can add a project, select it, and see the current project in the sidebar.

## Step 2 - Durable Project Storage v1 (Done)

Goal:
Projects survive app restart.

Scope:

- `UserDefaultsProjectRepository` or `JSONProjectRepository`.
- Persist project list.
- Persist current project id.
- Restore projects on launch.
- Fallback if current project is missing.
- DI registration.
- Tests.

Do not add:

- GRDB.
- File indexing.
- Project scanning.

Done when:
The added project and current project are restored after recreating the service or repository.

## Step 3 - Run Timeline v1 (Done)

Goal:
Runs page becomes an audit/debug surface.

Scope:

- Run detail page.
- Ordered `RunEvent` timeline.
- Event row.
- Event inspector.
- Run status.
- Token/cost summary.
- Artifacts placeholder.
- Empty events state.
- ViewModel tests.

Done when:
The user can open a Run and understand what happened inside it.

## Step 4 - Approval / Safety Foundation (Done)

Goal:
Lay down safety before CLI and tools.

Scope:

- `ApprovalServiceProtocol`.
- `ApprovalService`.
- `ApprovalRequest` lifecycle.
- Approval states:
  - pending.
  - granted.
  - rejected.
- Safety modes:
  - Read Only.
  - Ask Before Write.
  - Ask Before Shell.
  - Auto Inside Sandbox.
- Approval modal or page.
- Approval `RunEvent` entries.
- Tests.

Done when:
The system can request approval, show it to the user, and receive approve/reject.

## Step 5 - CLI Infrastructure v1 (Done)

Goal:
Create a shared layer for running CLI processes.

Scope:

- `ProcessRunnerProtocol`.
- `ProcessRunner`.
- stdout stream.
- stderr stream.
- start/finish events.
- timeout.
- cancellation.
- exit code mapping.
- error mapping.
- tests with fake or safe process.

Do not add:

- `CodexCLIProvider`.
- `CursorCLIProvider`.
- Tool execution.

Done when:
The app can safely run a simple process, stream stdout/stderr, cancel it, and handle timeout/errors.

## Step 6 - CodexCLIProvider v1 (Done)

Goal:
Add the first real backend.

Status note:
This step created a direct `ProcessRunner` provider scaffold. That is useful validation, but it is not the final architecture.

LLM/provider backends go through MCP-backed provider adapters. Full coding agents move to ACP-backed `AgentRuntime`.

Scope:

- `CodexCLIProvider: AIProvider`.
- Use `ProcessRunner`.
- Map stdout/stderr to `AIEvent`.
- Map errors to provider errors.
- Register in `ProviderRegistry`.
- Show in Settings.
- Select as active provider.
- Tests with fake `ProcessRunner`.

Important:
Do not conceptually change `HarnessEngine`.

Done when:
Codex CLI is selectable in Settings and works through the existing chat/run flow.

## Step 7 - CursorCLIProvider v1 (Done)

Goal:
Validate the provider abstraction with a second real backend.

Boundary:
This step created a second direct `ProcessRunner` provider scaffold. That validates the provider abstraction, but direct CLI execution is not a final architecture path.

LLM/provider backends go through MCP-backed provider adapters. Full coding agents move to ACP-backed `AgentRuntime`.

Scope:

- `CursorCLIProvider: AIProvider`.
- Reuse `ProcessRunner`.
- Map output to `AIEvent`.
- Register provider.
- Show in Settings.
- Select as active provider.
- Tests.

Done when:
The second CLI backend is added without changes in `HarnessEngine`.

## Step 8 - Provider MCP Migration v1 (Done)

Goal:
Move the provider layer to the final rule for LLM/provider backends: they go through MCP-backed provider adapters.

Status note:
This step is final for LLM/provider backends and interim for full coding agents.

Codex CLI and Cursor CLI MCP-backed descriptors are compatibility surfaces until Step 18 introduces ACP-backed `AgentRuntime`.

Scope:

- Define the WorkHarness MCP-backed provider adapter shape.
- Define the MCP server contract for AI provider calls:
  - list providers.
  - list models.
  - describe capabilities.
  - start provider request.
  - stream provider deltas.
  - finish provider request.
  - report provider failure.
  - optionally report token usage.
- Move Codex CLI execution behind MCP.
- Move Cursor CLI execution behind MCP.
- Keep WorkHarness mapping MCP results into:
  - `AIProvider`.
  - `ProviderDefinition`.
  - `ProviderCapabilities`.
  - `AIRequest`.
  - `AIEvent`.
- Use `/Users/lammax/Documents/ThisIsMy/Programming/AI/MCP_server` as the local MCP server base.
- Treat previous direct `CodexCLIProvider` and `CursorCLIProvider` code as migration input, not as final architecture.
- Keep `HarnessEngine` unchanged and provider-agnostic.
- Add tests with fake MCP provider streams.

Do not add:

- New direct SDK/HTTP/CLI provider adapters in WorkHarness.
- Provider-specific branching in `HarnessEngine`.
- Tool execution inside providers.

Done when:
Codex CLI and Cursor CLI are reachable through MCP-backed provider adapters as interim compatibility surfaces, and no LLM/provider backend depends on direct `ProcessRunner` providers inside WorkHarness.

## Step 9 - Local LLM MCP Provider v1 (Done)

Goal:
Add local model support without putting Ollama/Qwen/llama.cpp-specific code directly into WorkHarness.

Status note:
The v1 slice adds a dedicated `LocalLLMMCPServer` to the MCP server package and registers a WorkHarness `Local LLM` provider through the MCP-backed provider adapter path.

The current local LLM MCP server wraps an OpenAI-compatible local endpoint, matching the existing `LlamaLocalServer` / `llama-server` setup. WorkHarness sends MCP JSON-RPC `tools/call` requests to `local_llm_generate` and maps the tool result into `AIEvent` output. Token-by-token upstream streaming can be expanded later without changing `HarnessEngine`.

Boundary:
Local LLMs are providers, but they are not local CLI agent providers like Codex CLI or Cursor CLI.

They must go through MCP-backed provider adapters.

Existing source code:

- Local LLM implementation source: `/Users/lammax/Documents/ThisIsMy/Programming/AI/LlamaLocalServer`.
- MCP server base: `/Users/lammax/Documents/ThisIsMy/Programming/AI/MCP_server`.

Migration instruction:

1. Inspect `/Users/lammax/Documents/ThisIsMy/Programming/AI/LlamaLocalServer` before designing the WorkHarness side.
2. Identify reusable local LLM capabilities:
   - model discovery/listing.
   - model metadata.
   - prompt/completion request.
   - streaming generation.
   - cancellation if already supported.
   - error mapping.
   - health/status checks.
   - token/usage metadata if available.
3. Inspect `/Users/lammax/Documents/ThisIsMy/Programming/AI/MCP_server` and choose the existing extension points for tools/resources/prompts/provider-style capabilities.
4. Move or wrap the reusable LLM logic from `LlamaLocalServer` into `MCP_server`.
5. Keep LLM backend-specific details inside `MCP_server`, not inside WorkHarness:
   - Ollama URLs and payloads.
   - Qwen-specific settings.
   - llama.cpp server details.
   - model-specific request fields.
   - retry/health behavior.
6. Expose a stable MCP contract for local LLM usage:
   - list local models.
   - describe model capabilities.
   - start generation.
   - stream generation deltas.
   - finish generation.
   - report failure.
   - optionally report token usage.
7. Add or prepare a WorkHarness MCP-backed local LLM provider adapter.
8. The WorkHarness adapter maps MCP capabilities/results into existing app concepts:
   - `AIProvider`.
   - `ProviderDefinition`.
   - `ProviderCapabilities`.
   - `AIRequest`.
   - `AIEvent.started`.
   - `AIEvent.messageDelta`.
   - `AIEvent.messageCompleted`.
   - `AIEvent.finished`.
   - `AIEvent.error`.
9. Register the local LLM provider through `ProviderRegistry` only after the MCP contract is stable.
10. Show local MCP-backed LLM provider options in Settings without leaking MCP/internal backend details into UI.
11. Allow choosing a local model such as Qwen through provider settings or provider metadata, depending on the existing UI shape at that time.
12. Keep `HarnessEngine` provider-agnostic; do not add branches for Ollama, Qwen, llama.cpp, MCP or local model families.
13. Keep tool execution separate from local LLM generation. The local LLM provider generates text; tools still go through Tool/Approval/RunEvent boundaries.
14. Add deterministic tests:
   - fake MCP local model list.
   - fake streaming generation.
   - fake backend failure.
   - provider registration/selectability.
   - no `HarnessEngine` changes for local LLM support.
15. Update documentation when migration details become concrete.

Do not add:

- Direct `OllamaProvider` HTTP adapter inside WorkHarness.
- Direct `QwenProvider` adapter inside WorkHarness.
- Direct llama.cpp network adapter inside WorkHarness.
- LLM backend-specific branching in `HarnessEngine`.
- Tool execution inside the local LLM provider.
- RAG or embeddings unless explicitly part of the later RAG step.

Done when:
WorkHarness can select a local MCP-backed LLM provider and receive streamed `AIEvent` output through the existing provider flow, while the local LLM implementation lives in `MCP_server`.

## Step 10 - ContextBuilder v1 (Done)

Goal:
Create one path for building provider context.

Scope:

- `ContextBuilderProtocol`.
- `ContextBuilder`.
- Input:
  - user message.
  - current project.
  - root path.
  - recent run summary placeholder.
  - selected files placeholder.
  - token budget.
- Output:
  - `ContextSnapshot`.
- Tests.

Do not add:

- RAG.
- Memory.
- File indexing.
- Context folding.

Done when:
The provider receives requests through a single context pipeline.

## Step 11 - Tools Foundation v1 (Done)

Goal:
Move from provider chat to harness actions.

Scope:

- `ToolProtocol`.
- `ToolRegistry`.
- `ToolPermission`.
- `ToolResult`.
- `FileReadTool`.
- `FileWriteTool`.
- `ShellTool`.
- `GitTool`.
- `MCPToolAdapter`.
- Approval integration.
- Tool `RunEvent` entries.
- Tests.
- All real execution is routed through MCP.
- WorkHarness owns tool metadata, approval, RunEvents and UI.
- MCP server owns file, shell, git, RAG, browser and external capability execution.

Done when:
Tools are registered as WorkHarness-controlled metadata, all execution is routed through MCP, and dangerous operations go through `ApprovalService` before MCP invocation.

## Step 12 - Persistence v1 (Done)

Goal:
Replace temporary storage with a real database.

Scope:

- GRDB/SQLite.
- Run persistence.
- RunEvent persistence.
- Project persistence.
- AppSettings persistence if needed.
- Repository migration.
- Tests.

Done when:
Runs, events and projects survive app restart through structured persistence.

## Step 13 - Token / Cost Statistics v1 (Done)

Goal:
Make usage observable.

Scope:

- `TokenLedger`.
- `CostLedger`.
- Aggregate by provider.
- Aggregate by run.
- Aggregate by day/session.
- Stats page v1.
- Tests.

Done when:
The user can see token and cost usage by Run and provider.

## Step 14 - Settings v1 (Done)

Goal:
Make Settings an actual configuration surface, not only a read-only provider status page.

Scope:

- Editable app settings page.
- Durable safety mode setting.
- Durable MCP server base path setting.
- Durable Local LLM endpoint setting.
- Durable Local LLM model setting.
- Durable default input token budget.
- Durable default output token budget.
- Save and reset actions.
- Settings ViewModel writes through `AppSettingsServiceProtocol`.
- Explicitly show and select the backend used by the next Run.
- Provider MCP client reads configurable MCP/Local LLM settings.
- `HarnessEngine` reads default token budgets from AppSettings.
- Tests for persistence, ViewModel save flow and engine budget usage.

Do not add:

- Advanced per-provider forms.
- Secret storage.
- Remote settings sync.
- Agent-specific settings.
- MCP server health UI.

Done when:
The user can change core WorkHarness parameters in Settings, persist them, and see those values affect provider/runtime configuration without bypassing service boundaries.

## Step 15 - Context Folding v1

Status: Done.

Goal:
Long runs do not inflate context indefinitely.

Scope:

- Run summary.
- Conversation summary.
- Decision log.
- Current state.
- Failed attempts.
- Next actions.
- `ContextCompacted` event.
- `ContextFoldingServiceProtocol` and deterministic `ContextFoldingService`.
- Persisted fold summary payload in the append-only `contextCompacted` event.
- Reuse of the latest folded summary in `ContextBuilder`.
- `RunServiceProtocol.compactContext(runId:)` application boundary.
- Tests.

Done when:
A long Run can be compacted into a useful summary.

## Step 16 - Memory v1

Status: Done.

Goal:
Persist stable project knowledge.

Scope:

- `ProjectMemory`.
- `MemoryItem`.
- `MemoryService`.
- Memory write policy.
- Memory read policy.
- Memory events.
- Basic Memory page.
- SQLite-backed project memory persistence.
- Project memory inclusion in `ContextBuilder` and `ContextSnapshot.includedMemories`.
- Tests.

Do not add yet:

- Full RAG.

Done when:
Stable project knowledge can be saved, read and shown through a basic app surface.

## Step 17 - RAG v1

Status: Done.

Goal:
Search project knowledge and files.

Scope:

- Document ingestion.
- Chunking.
- MCP-backed embeddings provider.
- Vector storage.
- `RAGSearchTool`.
- Citations/metadata.
- `ContextBuilder` integration.
- Tests.

Implementation notes:

- WorkHarness does not duplicate chunking, embeddings or vector storage. These responsibilities remain in the existing `RAGMCPServer` at `/Users/lammax/Documents/ThisIsMy/Programming/AI/MCP_server`.
- `RAGMCPClient` follows the MCP JSON-RPC lifecycle and calls `rag_index_zip`, `rag_answer` and `rag_clear_index`.
- `RAGService` is the application boundary used by `HarnessEngine`; the engine requests RAG only when `Agent.contextPolicy.includeRAG` is enabled.
- `RAGCitation` preserves source, section, chunk id, quote and relevance score for auditability and context replay.
- The default chat path remains deterministic when the RAG server is unavailable because RAG inclusion is opt-in.
- RAG settings follow the existing editable Settings draft/save/revert/defaults flow and are passed into the next Run through `AppSettingsServiceProtocol`.

Done when:
Relevant indexed knowledge can be retrieved with citations and inserted into context through the approved context path.

## Step 18 - ACP Agent Runtime v1

Status: Done. Cursor ACP is connected through the provider-agnostic runtime; permissions, events and session execution are integrated with WorkHarness boundaries.

Goal:
Introduce one agent runtime abstraction so WorkHarness can run coding agents without depending on Codex, Cursor, Claude Code, Gemini CLI, OpenHands or any future concrete agent.

Architectural decision:
ACP is the preferred transport for full agent integrations.

Layer:

```text
Run
↓
HarnessEngine
↓
TaskPlanner
↓
AgentRuntime
↓
ACPHost / ACPClientRuntime
↓
ACPAgent
```

Scope:

- Create `AgentRuntime/`.
- Define the agent-facing domain API:
  - `AgentRuntime`.
  - `Agent`.
  - `AgentSession`.
  - `AgentTask`.
  - `AgentRequest`.
  - `AgentResponse`.
  - `AgentEvent`.
  - `AgentCapabilities`.
  - `AgentRegistry`.
  - `AgentFactory`.
  - `AgentExecution`.
- Create `ACP/`.
- Define ACP isolation types:
  - `ACPHost`.
  - `ACPClient`.
  - `ACPClientRuntime`.
  - `ACPConnection`.
  - `ACPTransport`.
  - `ACPMessage`.
  - `ACPEvent`.
  - `ACPError`.
  - `ACPCodec`.
- Launch ACP-compatible agents as subprocesses for local integrations.
- Use JSON-RPC 2.0 over stdin/stdout as the default local subprocess transport, unless a specific ACP agent requires a different transport.
- Add a stable agent interface:
  - `connect`.
  - `disconnect`.
  - `capabilities`.
  - `run(task:)`.
  - `cancel`.
  - `pause`.
  - `resume`.
  - `events`.
- Add capability discovery for agents.
- Add `AgentRegistry` for registered agent runtimes.
- Add `AgentSession` state/events/cost/tokens/artifacts/logs/child sessions/timeline placeholders.
- Keep one `AgentSession` per connected/running ACP agent session.
- Receive streamed ACP events from the agent.
- Map ACP event stream into existing `RunEvent` timeline concepts.
- Ensure approvals are requested through the existing `ApprovalService`, not agent-specific UI.
- Ensure agent tool requests route through Harness Tool Runtime / Tool Registry.
- Ensure agents receive `ContextSnapshot` from `ContextBuilder`; agents do not own memory.
- Log diffs, commands, tool calls and artifacts through the Run/AgentSession event pipeline.
- Add tests with fake ACP transports and fake agents.

Implemented foundation:

- `AgentRuntime`, `AgentTask`, `AgentSession`, `AgentExecution`, `AgentEvent` and capability models.
- `AgentRuntimeRegistry` and `AgentFactory` boundaries.
- `ACPMessage`, `ACPEvent`, `ACPConnection`, `ACPTransport`, `ACPClient` and `ACPError` isolation types.
- `ACPClientRuntime` lifecycle, session state, cancellation, pause/resume and event mapping.
- `ACPRunEventMapper` for agent output, tool requests, file changes, approvals, usage, artifacts and failures.
- `ACPSubprocessTransport`, `ACPSubprocessConnection` and `ACPCodec` for local process communication.
- `ACPSubprocessClient` for initialize, run, cancel, pause, resume and disconnect messages.
- `ACPAgentDefinition` and `ACPAgentFactory` for provider-agnostic runtime creation.
- Cursor ACP discovery through `cursor-agent acp`, including initialize, optional `cursor_login` authentication and `session/new` handshake.
- Settings stores the selected AgentRuntime id independently from the LLM provider id.
- A selected ACP runtime now creates coding Runs and receives `AgentTask` context; provider chat remains the fallback when no Agent runtime is selected.
- Deterministic fake-agent test proving ACP events are persisted as `RunEvent`s without concrete Codex/Cursor branching.
- Cursor ACP permission requests are created as shared `ApprovalRequest` records and surfaced by the existing Approval UI.
- Approval decisions are awaited asynchronously and returned through the ACP JSON-RPC connection.
- ACP tool-call notifications, file changes and agent events are mapped into the Run timeline without provider-specific UI.
- Cursor ACP session state is observable through Run status, Chat timeline and the existing Runs inspector.

Step 18 boundary note:

- Cursor ACP owns its internal execution of agent tools; WorkHarness owns the permission boundary, event audit trail and MCP tool registry.
- The ACP client does not duplicate Cursor's internal tool implementation inside WorkHarness.
- Additional agent-specific MCP capability injection belongs to the next agent-runtime expansion, without changing `HarnessEngine`.

Agent capabilities:

- canEditFiles.
- canSearch.
- canPlan.
- canUseTools.
- canStreamTokens.
- canExecuteTerminal.
- canSpawnAgents.
- canApproveChanges.
- canReadGit.
- canRunTests.
- canOpenDiff.
- canIndexWorkspace.
- canGenerateImages.

Adapter priority:

1. ACP.
2. Native SDK, only if it exposes agent-session semantics.
3. CLI subprocess fallback behind `AgentRuntime`.
4. AppleScript.
5. UI automation.

MCP is not an ACP replacement for full agent sessions. Use MCP for Harness tools, resources, prompts and LLM/provider capabilities, plus interim compatibility provider surfaces where already needed.

Do not add:

- `if Codex`, `if Cursor`, `if Claude`, `if Gemini` or similar branching.
- Standalone ACP server, ACP daemon or ACP tool server in this step.
- Direct agent CLI process execution in `HarnessEngine`.
- Agent-owned tools.
- Agent-owned memory.
- Mobile remote control or `HarnessDaemon` extraction.
- Provider-specific events leaking into UI.

Done when:
WorkHarness can run at least one fake ACP agent through `AgentRuntime`, persist/observe its events as `RunEvent`s, and keep `HarnessEngine` independent from concrete agent implementations.

## Step 19 - Multi-Agent v1

Status: Done. Capability-based planning, dependency-aware execution, parallel independent steps and a user-visible configurable Multi-Agent run mode are implemented.

Goal:
Support real agentic development workflows.

Scope:

- `AgentRuntime` expansion after ACP foundation.
- Capability-based planner.
- Planner agent role.
- Coder agent role.
- Reviewer agent role.
- Test runner agent role.
- Multi-agent Run loop.
- `ExecutionGraph` placeholder or model.
- Child `AgentSession` support.
- Run Timeline integration.
- Tests.

Implemented first slice:

- `AgentCandidate` combines an agent configuration with discovered `AgentCapabilities`.
- `CapabilityBasedAgentPlanner` selects candidates by capabilities, never by concrete provider or agent name.
- `AgentExecutionPlan` and `AgentPlanStep` model the dependency-aware Architect → Coder → Reviewer → Test Runner graph.
- Deterministic planner failure is returned when no candidate satisfies a required capability set.
- `MultiAgentCoordinator` executes dependency-ordered child sessions and aggregates their output, usage, artifacts and RunEvents.
- Child session start/finish metadata includes plan, step, role, agent and session identifiers.
- Chat composer exposes an explicit `Chat / Multi-Agent` run mode selector.
- Chat shows the planned role sequence before a Multi-Agent run starts.
- Each planned role exposes an enabled toggle, model override and runtime instructions.
- Planner validates disabled-role dependencies before creating the execution graph.
- `RunService` and `HarnessEngine` execute Multi-Agent runs through the same Run-centric path.
- The current MVP can execute Architect, Coder, Reviewer and Test Runner roles on one selected ACP runtime, or parallelize independent roles across different runtimes.
- Independent ready steps can execute in parallel when they are assigned to different runtimes; steps sharing one runtime remain serialized.

Done when:
Multiple agent roles can participate in a Run while preserving Run/Event observability.

## Step 20 - Remote Control v1

Status: Done. WorkHarness exposes a bearer-authenticated local API with configurable binding, health, capability discovery, project, approval, run, run-event and SSE endpoints. Remote run start/cancel is routed through RunService, and port/token/enabled/LAN access state is configurable in Settings with first-run token persistence.

Goal:
Prepare for mobile control.

Scope:

- Local HTTP/WebSocket server.
- Auth.
- Run streaming.
- Approval requests over API.
- Current project status.
- Active run status.
- Individual Run and append-only RunEvent inspection by Run ID.
- Mobile-safe API.
- Optional LAN binding for a future mobile client, disabled by default.
- Mobile clients talk to Harness Remote API, not directly to ACP agents.
- WorkHarness on Mac remains the owner of the embedded ACP Host.
- Consider extracting a separate `HarnessDaemon` only after the in-app ACP Host is stable and mobile control needs a background station process.
- Tests.

Done when:
The desktop app exposes controlled, authenticated Run state and approval operations for a future mobile client.

## Step 21 - Claude Code CLI Agent Runtime v1

Status: Done. The provider-agnostic CLI subprocess foundation supports executable discovery, bidirectional stdin/stdout, stderr, timeout and cancellation. Runtime-owned transport, capabilities, authentication and model metadata are available to Settings and multi-agent configuration, with model choices persisted independently per runtime. A chunk-aware Claude stream-json parser maps streaming text, thinking, tool calls, final messages, usage, cost and failures into provider-agnostic AgentEvents. `ClaudeCLIRuntime` owns session lifecycle, per-Run continuation through Claude session IDs, cancellation, model configuration, working directory and usage mapping. Every invocation receives an isolated per-Run MCP config containing only the authenticated WorkHarness MCP gateway; other MCP settings and all built-in tools are disabled. The gateway implements MCP initialize/list/call, resolves the Run project root and waits for the shared `ApprovalService` decision before continuing a mutating tool call. Production `MCPToolClient` transport routes file, shell, git and RAG operations to the existing MCP server package, lazily starts required local server executables and keeps execution outside WorkHarness. `DeveloperToolsMCPServer` provides workspace-scoped shell and git execution through the established MCP package pattern. An installed Claude executable is registered in `AgentRuntimeRegistry` and appears in Settings with runtime-managed sign-in and Sonnet, Opus and Fable selection. A live opt-in integration test verifies that real Claude Code can complete a Run and read a current-project file exclusively through the authenticated WorkHarness MCP gateway.

Goal:
Integrate locally installed Claude Code as a full coding `AgentRuntime`.

Architecture:

```text
WorkHarness
  -> AgentRuntime
  -> ClaudeCLIRuntime
  -> Claude Code stream-json
  -> approved MCP_server tools
```

Implementation order:

1. Add a reusable CLI AgentRuntime subprocess transport and executable discovery.
2. Add runtime-owned metadata, capability and model configuration.
3. Parse Claude `stream-json` into provider-agnostic `AgentEvent` values.
4. Implement Claude session lifecycle, continuation, cancellation and usage mapping.
5. Generate strict per-Run MCP configuration and disable direct mutating built-in tools.
6. Route mutating MCP operations through the shared WorkHarness approval flow.
7. Add Claude availability, authentication, runtime and model selection to Settings.
8. Add fixture, process, Run integration and approval tests.

Done when:
Claude Code can be selected as an AgentRuntime, execute a coding Run with streamed events, use only approved MCP tools, participate in the shared approval flow and remain invisible as a concrete implementation above the AgentRuntime boundary.

## Step 22 - Mobile Remote Client v1

Status: In progress in the separate `WorkHarnessMobile` repository. The fixture-backed mobile UI and automated test coverage exist, but the production `URLSessionRemoteControlClient`, pairing/token flow, live SSE stream, reject action, Keychain token storage, reconnect/auth expiry handling, and a real mobile-to-WorkHarness integration run are not complete.

Detailed product stages, WorkHarness development capabilities, release
sequencing and the long-term RemoteSDK direction are maintained in
`Documentation/WorkHarnessMobile-Development-Roadmap.md`.

Goal:
Provide a focused mobile control surface for monitoring Runs and handling approvals.

Scope:

- Mobile pairing and token entry.
- Connection health and capability discovery through `/health` and `/capabilities`.
- Run list, Run detail and live event stream.
- Approval inbox with approve/reject actions.
- Remote Run start and cancellation.
- Clear connection, authentication and offline states.
- Tests against a deterministic Remote Control API fixture.

Done when:
A mobile client can pair with WorkHarness, observe a Run and complete an approval flow without direct ACP or MCP access.

## Step 23 - Course Day 4: Local Boost v1

Status: MVP implemented and technically verified. Submission evidence is still
in progress: Claude Haiku is blocked by the current account session limit, the
Cursor Feature/Bug Fix comparison runs and final IDE screenshots remain.

Goal:
Deliver a minimal, reproducible local coding assistant configuration for the
course while preserving the existing MCP-backed provider architecture.

Hardware baseline:

- MacBook Pro with Apple M3 Pro.
- 18 GB unified memory.
- Ollama as the local inference runtime.
- Cursor with Continue for IDE Chat, Edit and Autocomplete.
- WorkHarness uses the existing `LocalLLMMCPServer`.

### Submission MVP

1. Install Continue in Cursor.
2. Install `qwen2.5-coder:1.5b` as the smallest practical baseline model.
3. Configure Continue roles:
   - Chat.
   - Autocomplete.
   - Edit.
   - Apply.
4. Use:
   - context window: 16,384 tokens.
   - maximum generated output: 2,048 tokens.
   - temperature: 0.1.
   - top_p: 0.9.
   - autocomplete prompt budget: 2,048 tokens.
5. Add a project Continue rule derived from `AGENTS.md` / `CLAUDE.md`.
6. Keep Cursor and Claude cloud baselines intentionally minimal:
   - Cursor: `gpt-5.4-nano[reasoning=medium]`.
   - Claude Code: `haiku` (Fable remains available but requires separate usage
     credits on the current account).
7. Add native Claude project agents for:
   - Bug Fix.
   - Research.
8. Use `LocalLLMMCPServer` as the WorkHarness local provider boundary.
9. Discover installed local models through the MCP tool and expose them as a
   Settings picker.
10. Apply a newly saved Local LLM endpoint/model without restarting WorkHarness.
11. Run one Day 1 feature task and the Day 2 Bug Fix / Research tasks against
    the same baseline and acceptance criteria.
12. Record first-pass outcome, build/tests, speed, rule compliance, context
    understanding, offline behavior and manual corrections.
13. Produce a course report with a Cursor vs Claude vs Local table and a
    recommendation for tasks that fit the local model.

MVP benchmark tasks:

- Day 1 feature: add installed Ollama model discovery and a Settings picker
  through the existing service and MCP boundaries.
- Day 2 Bug Fix: diagnose and fix Local LLM settings being captured at app
  startup instead of applied after Save.
- Day 2 Research: explain the Local LLM flow from Settings through MCP,
  ContextBuilder and RunEvents without changing files.

Done when:

- local Chat and Autocomplete work in Cursor;
- WorkHarness can select an installed Ollama model returned by
  `LocalLLMMCPServer`;
- the selected model is used without an app restart;
- the fixed benchmark prompts and raw results are preserved;
- the comparison report contains evidence-backed verdicts and limitations.

### Post-course Local LLM enhancements

These items are explicitly outside the submission MVP:

1. Compare at least three local models on identical repository revisions:
   - `qwen2.5-coder:1.5b`;
   - `qwen2.5-coder:7b`;
   - one of `deepseek-coder:6.7b`, `starcoder2:7b` or a newer model that fits
     comfortably in 18 GB unified memory.
2. Split model roles:
   - 1.5B–3B Fill-in-the-Middle model for low-latency autocomplete;
   - 7B–14B instruction model for Chat/Edit;
   - tool-capable local model for agent workflows.
3. Benchmark 8K, 16K and 32K context sizes and measure:
   - time to first token;
   - generated tokens per second;
   - peak unified memory;
   - first-pass build/test success;
   - rule and architecture compliance.
4. Add typed Local LLM generation settings to WorkHarness:
   - temperature;
   - top_p;
   - context size;
   - output token limit;
   - optional system prompt/rules source.
5. Expand `LocalLLMMCPServer`:
   - upstream token streaming;
   - cancellation;
   - per-model capability and context metadata;
   - Ollama-native metadata where OpenAI-compatible `/models` is insufficient;
   - structured health and loaded-model diagnostics;
   - stable error classification and retry policy.
6. Add a local coding `AgentRuntime` only behind the agent boundary:
   - prefer ACP;
   - alternatively use a compatible isolated agent host;
   - route file/shell/git actions through WorkHarness MCP tools;
   - reuse approvals and RunEvents;
   - never turn `MCPBackedAIProvider` into a hidden coding agent.
7. Add repeatable benchmark support:
   - immutable task catalog;
   - isolated Git worktrees;
   - per-run timing and hardware metrics;
   - automatic diff/build/test capture;
   - Markdown/CSV comparison reports.
8. Add an offline certification run with network disabled after all required
   models and dependencies are cached.
9. Add UI smoke coverage for model refresh, selection, Save/Revert and backend
   unavailability.
10. Revisit the recommended default after measurements; do not promote the
    smallest model to production agent workflows without evidence.

## Step 24 - Course Day 5: Execution Loop v1

Status: MVP implemented; execution evidence pending. The ordered
WorkHarnessMobile task pool is defined in
`Documentation/Course/Day5-WorkHarnessMobile-Task-Pool.md`. WorkHarness now has
a Markdown task source, deterministic profile selection, autonomous serial
Runs, validation gates, Auto-approve-gated commit/push and a Markdown metrics
report. Two cloud attempts and the local-model comparison still need to be
executed and captured.

Goal:
Execute an ordered task pool for any explicitly configured project
autonomously, committing every validated task and producing reproducible
evidence for two cloud runs and one local-model run. WorkHarnessMobile is the
Day 5 reference project and evidence source, not a dependency of the execution
loop.

### General-purpose readiness requirement

Day 5 is not complete if the loop works only for WorkHarnessMobile. The
production execution path must:

- read the target repository, build command, test command and task definitions
  from the selected task source;
- keep repository-specific names, paths, schemes and validation commands out of
  `ExecutionLoopService`, `HarnessEngine` and the Chat UI;
- operate on the target repository pinned by the loop even when another project
  is currently selected in WorkHarness;
- preserve the target repository's current branch and never require creating a
  task branch;
- use the same profile selection, agent-runtime switching, approvals,
  validation, commit/push, RunEvents and reporting flow for every project;
- allow a new project to be automated by adding/selecting the project and
  supplying a conforming task pool, without changing or rebuilding WorkHarness.

### Submission MVP

1. Add an `ExecutionTask` domain model with immutable prompt and acceptance
   criteria plus mutable execution status.
2. Add `ExecutionTaskSourceProtocol` and a Markdown implementation for the Day 5
   task-pool format.
3. Add a deterministic profile selector that chooses Bug Fix, Research,
   Feature or the nearest available workflow from task content and records the
   choice.
4. Add a serial `ExecutionLoopService` above the existing Run service/engine:
   - claim the next pending task;
   - create one Run for that task;
   - execute with the selected agent runtime/profile;
   - mirror meaningful role results and task transitions into the controller
     Run in real time, excluding token deltas and repetitive read/search calls;
   - validate the result;
   - create one local commit after validation succeeds;
   - update the task/log and continue.
   - resolve and snapshot the currently saved agent runtime and model separately
     for every new task, so Settings changes can take effect between tasks
     without mutating an already running child Run.
5. Preserve the existing boundaries:
   - agents edit and validate only through approved WorkHarness MCP tools;
   - the loop coordinates Runs but does not become a provider or tool;
   - every task transition and stop reason produces an append-only RunEvent or
     execution-loop event.
6. Add course safety limits:
   - require a clean target repository and keep all work on its current branch;
   - pin the base commit and task-pool revision for each attempt;
   - execute one task at a time;
   - allow ordinary commit and push when the saved Application setting
     `Auto-approve actions inside the current project` is enabled;
   - apply that permission to the target repository pinned by the loop rather
     than requiring it to be the project selected before the loop starts;
   - never allow force-push, destructive history rewriting, tags or remote
     branch deletion through that automatic path;
   - stop on failure, blocked approval, clarification request, dirty-worktree
     mismatch, task/time budget or cancellation.
7. Persist a Markdown execution log containing:
   - task ID and selected profile/runtime/model;
   - separate human-readable agent name, runtime ID and model columns for every
     attempted task;
   - timestamps and duration;
   - first-pass outcome;
   - build/test result;
   - commit SHA for passed tasks;
   - failure/blocked reason and consecutive-pass count.
8. Expose a visible Task Loop mode in the Chat composer:
   - select a Markdown pool with a file picker and preview source, target,
     branch and task count;
   - start the loop without remembering a slash command;
   - display active task progress;
   - safely pause after the current task, resume the remaining pool or end a
     paused loop.
   Slash commands remain keyboard shortcuts for the same service operations.
9. Add deterministic tests for parsing, profile selection, state transitions,
   stop conditions, commit gating and metric calculation.
10. Run the same immutable task pool from the same base revision:
    - cloud run 1 with one fixed minimal Cursor or Claude runtime;
    - cloud run 2 with the same runtime after one documented rules/profile
      improvement based on the first failure;
    - local run through a WorkHarness agent runtime backed by Ollama, not through
      a chat-only provider.
11. Produce the final comparison report:
    - completed consecutively without intervention;
    - first failure and reason;
    - average time per attempted and passed task;
    - first-pass success percentage;
    - cloud run 1 vs cloud run 2;
    - cloud vs local-model result and honest limitations.

Course run policy:

- No human messages, prompt edits or manual fixes after a run starts.
- A human response to an approval or clarification ends the uninterrupted
  sequence, even if execution later resumes.
- Reusing the same Run after a failed first attempt does not count as a
  first-pass success.
- A passed task requires its stated validation and a local commit.
- A model/runtime crash, invalid tool call or exhausted context is recorded as a
  failure rather than hidden by changing the task.

Local comparison note:

`MCPBackedAIProvider` is chat/provider inference and is not by itself a coding
agent. To satisfy the local execution-loop comparison, WorkHarness needs a
tool-capable local `AgentRuntime` behind the existing runtime boundary. The
smallest acceptable implementation is a configured agent host that uses Ollama
for inference while retaining WorkHarness MCP tools, approvals and RunEvents.
If the selected small model fails before completing a task, a measured result of
zero consecutive tasks is valid and must be reported honestly.

Done when:

- the Markdown pool contains 15–20 unambiguous mixed tasks;
- no execution-loop production type contains a WorkHarnessMobile-specific path,
  project name, Xcode scheme or validation command;
- a second arbitrary repository/task-pool fixture proves that target selection,
  validation and commit/push routing do not depend on the project currently
  selected in the UI;
- a user can start work on another real project by supplying its task-pool path,
  without changing WorkHarness source code;
- Chat distinguishes the immutable `Current Run` backend from the `Next Runs`
  backend selected in Settings, and Settings explicitly says that a backend or
  model change applies to the next Run;
- an active Run never silently changes agent runtime or model, while an
  execution loop may use a newly saved runtime/model when it starts the next
  task;
- each attempt can run without human input until a recorded stop condition;
- passed tasks are validated and committed one per task;
- both cloud attempts use the same pool, base commit and runtime/model;
- the second cloud attempt has exactly one documented rules/profile iteration;
- the local attempt uses the same pool and base commit;
- the final log and comparison report provide every metric required by Day 5.

### Post-course Execution Loop enhancements

These items are explicitly outside the submission MVP:

1. Add Notion as an `ExecutionTaskSourceProtocol` implementation through MCP,
   including task claim, status, result and report synchronization.
2. Connect the Notion MCP server to Claude's isolated per-Run MCP configuration
   with explicit allowlisting and the same approval/security policy. Cursor's
   existing personal Notion connection is not assumed to be available inside a
   WorkHarness Run.
3. Add GitHub Issues and Linear task-source adapters without leaking tracker
   specifics into the loop engine.
4. Add resumable loops after app relaunch, crash recovery and idempotent task
   claims.
5. Add isolated Git worktrees per attempt and automatic branch/result cleanup.
6. Add dependency graphs, priorities, retries, skip policy and configurable
   failure budgets.
7. Add cost, token, wall-clock and context budgets at loop and task levels.
8. Add parallel workers only after serial execution, repository isolation and
   merge-conflict policy are proven.
9. Add automatic pull-request preparation and remote push as an explicit,
   separately approved mode.
10. Add a full execution dashboard with queue editing, live task timeline,
    intervention markers, failure classification and report export.
11. Benchmark several cloud and local models with immutable prompts, worktrees
    and hardware telemetry.
12. Persist the selected task-pool path and paused attempt across application
    relaunch, then add crash recovery and explicit reconciliation when the
    repository changed while WorkHarness was offline.
13. Move the remaining WorkHarnessMobile stages into later pools:
    - Pair Code and QR provisioning;
    - Chat, Projects and Providers;
    - advanced Approvals and notifications;
    - Agent Monitor, statistics and search;
    - settings, widgets, Siri/Shortcuts and Apple Watch;
    - extraction of a shared `RemoteSDK`.

## Step 25 - Course Fine-Tuning: Days 6–10

Status: active. Day 6 is complete. Day 7 code and live API evaluation are
complete with only the video pending. Day 8 routing code and deterministic
evaluation are complete with real Haiku/Sonnet video evidence pending. Day 9
WorkHarness multi-stage inference and deterministic tests are complete with the
live comparison video pending. Day 10 requirements have not been received. The
unified course plan and evidence index live in
`Documentation/Course/Fine-Tuning-Days-6-10-Roadmap.md`.

Day 6 prepares a versioned task-classification dataset, validation pipeline,
frozen baseline and a safe fine-tuning client. Days 7–10 will extend the same
experiment only after their exact course requirements are provided.

Production integration is deliberately deferred until the course evidence
shows an improvement over the frozen baseline. Deferred product work includes
an MCP-backed task-classification service, dataset/model registry, secure
training-candidate collection, experiment UI and automated evaluation.

# Architectural Direction

This section does not change the implementation order.

Instead, it defines the long-term direction of the project.

---

## WorkHarness is an AI Operating System

WorkHarness is not a chat application.

It is not a wrapper around Codex.

It is not a Cursor clone.

WorkHarness is a local-first AI Operating Environment.

Applications interact with it.

WorkHarness itself remains the reusable platform.

## MCP for Tools and LLM Providers

LLM/provider backends are not integrated as direct SDK, raw HTTP or direct CLI adapters inside WorkHarness.

This applies to:

- external/cloud providers.
- local model providers such as Ollama, Qwen and llama.cpp-style servers.

WorkHarness talks to AI backends through MCP-backed provider adapters.

The local MCP server base already exists at:

`/Users/lammax/Documents/ThisIsMy/Programming/AI/MCP_server`

Use that project as the starting point for MCP-backed providers/tools unless a specific task says otherwise.

New MCP servers in that package must follow the existing `MCP_server` shape:

- add an `.executable` product and matching `.executableTarget` in `Package.swift`.
- create `Sources/<Name>MCPServer/<Name>MCPServer.swift`.
- depend on `Shared`, Vapor and MCP in the same way as the existing servers.
- expose capabilities through `MCP.Server(...)`, `ListTools` and `CallTool`.
- expose HTTP through the existing Vapor + `StatelessHTTPServerTransport` + `Shared/bridge/MCPHTTPBridge.swift` pattern.
- keep reusable logic in `Sources/Shared/...`.
- do not introduce a second package layout or transport style unless the roadmap is explicitly changed first.

The existing local LLM implementation already exists at:

`/Users/lammax/Documents/ThisIsMy/Programming/AI/LlamaLocalServer`

When adding local LLM support, migrate or wrap the reusable local LLM logic from `LlamaLocalServer` into `MCP_server`. Do not copy that backend logic into WorkHarness.

MCP is also the standard way to connect external tools, resources and prompts.

Codex CLI and Cursor CLI MCP descriptors are interim compatibility surfaces from the early provider abstraction work. They must not become the final architecture for full coding agents.

This keeps provider integrations:

- replaceable
- auditable
- permissioned
- observable
- outside the core orchestration surface

Existing direct `ProcessRunner` providers are temporary scaffolding only; they are not the final provider or agent architecture.

---

## ACP for Agent Runtime

Architectural decision:
WorkHarness is ACP-first for full agent integrations.

MCP is the standard for tools and LLM/provider backends.

ACP is the standard for agents.

Meaning:

- MCP server means an agent comes to WorkHarness for tools, resources, prompts or provider-style capabilities.
- ACP Host / ACP Client Runtime means WorkHarness connects to an agent and manages its session.

Direction:

```text
MCP: Agent -> Harness tools/resources/provider capabilities
ACP: Harness -> Agent
```

Do not model ACP as a WorkHarness tool server.

Harness remains the orchestrator and must not depend on concrete agents such as:

- Codex CLI.
- Cursor Agent.
- Claude Code.
- Gemini CLI.
- OpenHands.
- future custom agents.

Replace this product goal:

```text
Support multiple agent CLIs.
```

with:

```text
Support one Agent Runtime abstraction. ACP is the preferred transport.
```

CLI is only one possible adapter implementation and should be treated as fallback.

Target runtime stack:

```text
WorkHarness
↓
AgentRuntime
↓
ACP Host / ACP Client Runtime
↓
Codex ACP Agent / Cursor ACP Agent / Claude ACP Agent / Custom ACP Agent
```

The execution logic above `AgentRuntime` must not know whether the active agent is Codex, Cursor, Claude Code, Gemini CLI, OpenHands or another implementation.

Do not build this as the current architecture:

```text
WorkHarness
↓
ACP Server
↓
Tools
```

Tools belong to the Harness Tool Runtime and MCP/tool adapters. Agent sessions belong to ACP Host / ACP Client Runtime.

### Agent Runtime

Add `AgentRuntime/` as the lifecycle boundary for agents.

It owns:

- agent connection lifecycle.
- agent task lifecycle.
- agent sessions.
- agent capabilities.
- agent event streams.
- agent cancellation/pause/resume.
- mapping agent output into RunEvents.

Recommended structure:

```text
AgentRuntime/
├── AgentRuntime
├── Agent
├── AgentSession
├── AgentTask
├── AgentRequest
├── AgentResponse
├── AgentEvent
├── AgentCapabilities
├── AgentRegistry
├── AgentFactory
├── AgentExecution
├── ACP/
├── CLI/
└── Local/
```

Runtime knows interfaces and capabilities, not concrete agent names.

The first implementation should be embedded in the macOS app. A separate agent daemon is a later deployment choice, not the Step 18 architecture.

### ACP Module

Add `ACP/` as a separate module that isolates WorkHarness from ACP protocol details.

Recommended structure:

```text
ACP/
├── ACPHost
├── ACPClient
├── ACPClientRuntime
├── ACPConnection
├── ACPTransport
├── ACPMessage
├── ACPEvent
├── ACPError
└── ACPCodec
```

If ACP changes later, changes should be contained inside the ACP module and narrow mapping code.

For local integrations, the default shape is an ACP-compatible agent subprocess with JSON-RPC 2.0 over stdin/stdout. The ACP Host owns subprocess lifecycle, message routing, session state and stream consumption; it does not own tools, memory or approvals.

### Agent Interface

WorkHarness should work through one agent interface:

```text
Agent
├── connect()
├── disconnect()
├── capabilities()
├── run(task)
├── cancel()
├── pause()
├── resume()
└── events()
```

### Capability-Based Agents

Every agent must describe its capabilities.

Examples:

- canEditFiles.
- canSearch.
- canPlan.
- canUseTools.
- canStreamTokens.
- canExecuteTerminal.
- canSpawnAgents.
- canApproveChanges.
- canReadGit.
- canRunTests.
- canOpenDiff.
- canIndexWorkspace.
- canGenerateImages.

Harness decisions must be based on capabilities, not agent names.

Never add:

```text
if Codex ...
if Cursor ...
if Claude ...
```

### Agent Registry

`AgentRegistry` stores registered agents and their capabilities.

Examples:

- Codex.
- Claude Code.
- Cursor Agent.
- Gemini CLI.
- OpenHands.
- Custom Agent.

Registry only registers and exposes metadata.

The planner chooses an agent by capability and task needs.

### Planner Upgrade

Planner should choose agents, not LLMs.

Example:

```text
Task
↓
Needs Git
↓
Needs editing
↓
Needs tool access
↓
Choose capable Agent
```

### Multi-Agent Ready

Any agent may create child `AgentSession`s through the Harness.

Examples:

```text
Planner
↓
Codex
↓
Claude
↓
Cursor
```

or:

```text
Planner
↓
5 ACP Agents
↓
Merge Results
```

Even if the MVP uses one agent, the architecture should allow many.

### Agent Sessions

`Run` contains many `AgentSession`s.

An `AgentSession` should eventually contain:

- state.
- events.
- cost.
- tokens.
- artifacts.
- logs.
- child sessions.
- timeline.

For ACP-backed agents, the session tracks the connected subprocess or remote endpoint, protocol state, active task, streamed event cursor, cancellation state, pause/resume state, diffs, commands, tool calls and artifacts.

### Agent Events

ACP generates an event stream.

Examples:

- agentStarted.
- agentThinking.
- toolCallRequested.
- patchCreated.
- patchApplied.
- approvalRequested.
- fileOpened.
- commandExecuted.
- artifactCreated.
- taskFinished.
- taskFailed.

All important events must map into the existing Harness event model so Timeline does not need agent-specific adapters.

The ACP Host should translate agent events into `RunEvent`s as soon as they are observed. Diffs, commands, tool calls and artifacts must be logged through the same Run/AgentSession event pipeline rather than through agent-specific UI state.

### Approval Ownership

Approval belongs to Agent Runtime and Harness safety policy, not to any concrete agent.

Any agent can request approval for:

- edit.
- delete.
- shell.
- git push.
- git commit.
- secrets.
- network.
- filesystem.

Harness shows one approval UI and records one consistent approval event flow.

ACP approval requests are routed into the same `ApprovalService` and approval UI used by tools and shell execution. The agent receives the decision; it does not create its own approval surface.

### Tool Ownership

Agents do not directly execute tools.

Preferred flow:

```text
Agent
↓
ACP
↓
Harness Tool Runtime
↓
ToolRegistry
↓
Tool
```

Harness remains the owner of tools, permissions and audit trail.

### Memory Ownership

Agents do not own memory.

Harness owns memory.

Agents receive `ContextSnapshot`s and return results/events.

After agent completion, Harness decides what to write through memory policy.

### Context Ownership

`ContextBuilder` is agent-independent.

It builds context from:

- project.
- memory.
- RAG.
- workspace.
- open files.
- git.
- selection.
- rules.
- skills.
- task.

Then it passes the prepared snapshot to Agent Runtime.

ACP-backed agents receive a `ContextSnapshot` prepared by WorkHarness. They may request more context through approved tool/context paths, but they do not own memory, RAG indexing or project state.

### Adapter Priority

Adapter preference for full agents:

1. ACP.
2. Native SDK, only if it exposes agent-session semantics.
3. CLI subprocess fallback behind `AgentRuntime`.
4. AppleScript.
5. UI automation.

MCP is not an ACP replacement for full agent sessions. Use MCP for Harness tools, resources, prompts and LLM/provider capabilities, plus interim compatibility provider surfaces where already needed.

ACP is the long-term path.

CLI is fallback.

### Future Remote Runtime

Do not add a standalone ACP server for the current desktop architecture.

Separate runtime extraction is only a later Remote Control concern. The intended future shape is:

```text
iPhone
↓
Harness Remote API
↓
WorkHarness on Mac
↓
ACP Host
↓
Agent
```

If WorkHarness later gains a `HarnessDaemon`, it may host the ACP Host so the Mac works as a local agent station and mobile clients act as remote controllers. Until that step, ACP Host / ACP Client Runtime lives inside the macOS app.

---

## Core Philosophy

### Local-first

Everything should work locally whenever practical.

Cloud services are optional.

---

### Provider-Agnostic and Agent-Agnostic

Never design around one provider or one agent.

OpenAI, Anthropic, Ollama, Qwen and future model backends are implementations of provider abstractions.

Codex, Cursor Agent, Claude Code, Gemini CLI, OpenHands and future coding agents are implementations of agent abstractions.

---

### Run-centric

Run remains the central domain object.

Everything meaningful happens inside a Run.

Chat is only one possible Run interface.

Future voice, automation, mobile and scheduled execution should also create Runs.

---

### Everything Is Observable

Every meaningful action should become observable.

Examples:

- provider execution
- agent execution
- tool execution
- approvals
- validation
- memory writes
- context building
- project changes

Nothing important should happen silently.

---

### Everything Is Replaceable

Providers.

Agents.

Repositories.

Tools.

Persistence.

Memory.

Context.

UI.

Remote API.

Every subsystem should be replaceable.

---

## Long-Term Concepts

The following concepts should gradually appear as the roadmap progresses.

Do not implement them until they become necessary.

### Capability-Oriented Architecture

Eventually the system should reason about capabilities instead of implementations.

Future concept:

CapabilityRegistry

Examples:

Capability:

Code Editing

Providers:

- MCP-backed local LLM provider
- MCP-backed cloud LLM provider

Agents:

- ACP-backed Codex agent
- ACP-backed Cursor agent
- ACP-backed Claude Code agent

Capability:

Git

Provided by:

GitTool

Capability:

Vision

Provided by:

Vision Tool

CapabilityRegistry is metadata.

It is not a service locator.

---

### Tools Are First-Class Domain Objects

Tools are not simply functions.

A Tool is a domain entity.

Recommended metadata:

- id
- name
- description
- category
- permissions
- capability tags
- input schema
- output schema
- estimated latency
- estimated cost
- safety level
- supported providers or agents
- version

---

### Providers and Agents Never Execute Tools Directly

Architecture rule:

Run

↓

Orchestrator

↓

ContextBuilder

↓

Provider

↓

AI Response

↓

ToolRouter

↓

Tool

↓

Tool Result

↓

RunEvent

Agent runtime rule:

Run

↓

HarnessEngine

↓

AgentRuntime

↓

ACP Agent

↓

Tool request

↓

Harness Tool Runtime

↓

ToolRegistry

↓

Tool

↓

Tool Result

↓

AgentEvent / RunEvent

Providers generate AI output.

Agents coordinate task execution.

Tools perform actions.

Providers and agents must never bypass the Harness tool, approval and event pipeline.

Providers and agents must never execute tools directly inside WorkHarness.

---

### ContextBuilder Is a Pipeline

Avoid one large ContextBuilder.

Instead:

User Message

↓

Current Project

↓

Project Context

↓

Recent Run Summary

↓

Working Memory

↓

Project Memory

↓

RAG

↓

Selected Files

↓

Agent Instructions

↓

Provider Instructions

↓

Prompt Assembly

Each stage should remain independently replaceable.

---

### Memory Is Event Driven

Preferred flow:

RunCompleted

↓

MemoryPolicy

↓

MemoryWriter

↓

MemoryStorage

Memory reacts to events.

Business logic should not write memory directly whenever possible.

---

### Generic ProcessRunner

ProcessRunner represents executable processes.

Future users:

- MCP server launcher/helper processes
- Git
- Swift Build
- xcodebuild
- npm
- ffmpeg

Never specialize ProcessRunner for Codex, Cursor, Ollama or any other single backend.

AI provider execution must stay behind MCP-backed provider adapters, not direct WorkHarness `ProcessRunner` providers.

Agent execution must stay behind `AgentRuntime`, preferably ACP-backed, not direct WorkHarness `ProcessRunner` agent wrappers.

---

### Vertical Subsystems

As the project grows, organize by responsibility.

Examples:

- ProjectSubsystem
- RunSubsystem
- ProviderSubsystem
- ApprovalSubsystem
- ToolSubsystem
- MemorySubsystem
- StatisticsSubsystem

Avoid one enormous flat Services directory.

---

### Facades

When subsystem complexity increases, expose Facades to ViewModels.

Example:

ProjectFacade

Methods:

- current()
- all()
- create()
- delete()
- select()

Internally the facade may coordinate multiple services.

ViewModels should remain simple.

---

### Reserved Future Domain Objects

Reserve architectural space for:

Workspace

Task

ExecutionGraph

Do not implement them yet.

Workspace will eventually own:

- Projects
- Providers
- Runs
- Settings
- Memory

Task will represent durable user goals.

ExecutionGraph will describe relationships between:

- Agents
- Tools
- Validation
- Build
- Review

---

### AIChallenge Relationship

AIChallenge should remain a client.

WorkHarness Core

↓

Providers

↓

Tools

↓

Memory

↓

Orchestrator

↓

Remote API

↓

Applications

Examples:

- AIChallenge Vision
- Mobile App
- Future Web UI

Applications are clients.

WorkHarness is the platform.

---

### Avoid Premature Complexity

Do not introduce yet:

- CapabilityRegistry
- Workspace
- Task
- ExecutionGraph
- Skill Graph
- Plugin Marketplace
- Voice Pipeline
- Vision Pipeline
- Distributed Workers

Implement them only when the existing roadmap naturally reaches those requirements.

---

# Final Engineering Rule

Before implementing any feature ask:

1. Does this preserve Run-centric architecture?
2. Does this reduce coupling?
3. Is it replaceable?
4. Is it observable?
5. Does it belong to the correct layer?
6. Can it evolve without redesign?

If the answer to any question is "no", redesign before implementation.
