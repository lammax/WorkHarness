# WorkHarness Development Roadmap

Updated: 09.07.2026

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
- Tests passing for the current stable slice.

All LLM/provider backends must go through MCP-backed provider adapters.

All tool execution must go through MCP-backed tool adapters.

Existing MCP server base contains these ready server targets:

- `FileOperationsMCPServer`
- `GitHubMCPServer`
- `LocalLLMMCPServer`
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
- Before adding a new MCP capability, check the existing server targets: `FileOperationsMCPServer`, `GitHubMCPServer`, `LocalLLMMCPServer`, `RAGMCPServer`, `SupportMCPServer`, `UtilityMCPServer`, `VisionBackendServer` and `Shared`.
- Do not duplicate an existing MCP server capability inside WorkHarness as a local tool.
- Route local LLM model providers, such as Ollama, Qwen and llama.cpp-style backends, through the same MCP-backed provider path.
- Use `/Users/lammax/Documents/ThisIsMy/Programming/AI/LlamaLocalServer` as the existing source implementation for local LLM logic; migrate the reusable parts into the MCP server base instead of duplicating that logic inside WorkHarness.
- Treat direct local CLI providers, such as Codex CLI and Cursor CLI over `ProcessRunner`, as temporary scaffolding only.
- Treat MCP-backed Codex CLI / Cursor CLI provider descriptors as interim compatibility surfaces; the final architecture for full coding agents is ACP-backed `AgentRuntime`.
- Never branch on concrete agent names such as Codex, Cursor, Claude Code, Gemini CLI or OpenHands in `HarnessEngine`, planner, tools or UI.
- Prefer small, buildable steps with tests where behavior crosses service, repository, engine, provider or ViewModel boundaries.
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

Codex CLI and Cursor CLI MCP-backed descriptors are compatibility surfaces until Step 17 introduces ACP-backed `AgentRuntime`.

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

## Step 14 - Context Folding v1

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
- Tests.

Done when:
A long Run can be compacted into a useful summary.

## Step 15 - Memory v1

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
- Tests.

Do not add yet:

- Full RAG.

Done when:
Stable project knowledge can be saved, read and shown through a basic app surface.

## Step 16 - RAG v1

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

Done when:
Relevant indexed knowledge can be retrieved with citations and inserted into context through the approved context path.

## Step 17 - ACP Agent Runtime v1

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

## Step 18 - Multi-Agent v1

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

Done when:
Multiple agent roles can participate in a Run while preserving Run/Event observability.

## Step 19 - Remote Control v1

Goal:
Prepare for mobile control.

Scope:

- Local HTTP/WebSocket server.
- Auth.
- Run streaming.
- Approval requests over API.
- Current project status.
- Active run status.
- Mobile-safe API.
- Mobile clients talk to Harness Remote API, not directly to ACP agents.
- WorkHarness on Mac remains the owner of the embedded ACP Host.
- Consider extracting a separate `HarnessDaemon` only after the in-app ACP Host is stable and mobile control needs a background station process.
- Tests.

Done when:
The desktop app exposes controlled, authenticated Run state and approval operations for a future mobile client.

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

The first implementation should be embedded in the macOS app. A separate agent daemon is a later deployment choice, not the Step 17 architecture.

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
