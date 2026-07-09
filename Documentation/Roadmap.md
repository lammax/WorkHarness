# WorkHarness Development Roadmap

Updated: 08.07.2026

WorkHarness is a local-first macOS SwiftUI AI Agent Harness. It must stay Run-centric, provider-agnostic and safety-aware. Do not treat it as a generic chat app.

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
- CodexCLIProvider v1.
- Codex CLI selectable provider.
- Codex CLI stdout/stderr mapping.
- Tests passing for the current stable slice.

Do not add `CursorCLIProvider` before the safety and process infrastructure steps are complete.

## Roadmap Rules

- Do not skip foundations.
- Keep Views out of repositories, providers, tools and engine internals.
- Keep ViewModels behind service/facade boundaries.
- Add safety and observability before real shell/tool/CLI execution.
- Route external/cloud AI providers through MCP-backed provider adapters, not direct SDK/HTTP adapters inside WorkHarness.
- Use `/Users/lammax/Documents/ThisIsMy/Programming/AI/MCP_server` as the existing local MCP server base for MCP-backed providers/tools unless a task explicitly chooses another server.
- Route local LLM model providers, such as Ollama, Qwen and llama.cpp-style backends, through the same MCP-backed provider path.
- Use `/Users/lammax/Documents/ThisIsMy/Programming/AI/LlamaLocalServer` as the existing source implementation for local LLM logic; migrate the reusable parts into the MCP server base instead of duplicating that logic inside WorkHarness.
- Keep local CLI agent providers, such as Codex CLI and Cursor CLI, behind `ProcessRunner` and the normal safety/approval boundaries.
- Prefer small, buildable steps with tests where behavior crosses service, repository, engine, provider or ViewModel boundaries.
- Commit and push stable validated slices before starting broad new work.

## Completed Steps

- Step 1 - Project Selector UI v1.
- Step 2 - Durable Project Storage v1.
- Step 3 - Run Timeline v1.
- Step 4 - Approval / Safety Foundation.
- Step 5 - CLI Infrastructure v1.
- Step 6 - CodexCLIProvider v1.

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

## Step 7 - CursorCLIProvider v1

Goal:
Validate the provider abstraction with a second real backend.

Boundary:
Cursor CLI is treated as a local CLI agent provider. External/cloud providers are not added with this pattern; they must go through MCP.

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

## Step 8 - Local LLM MCP Provider v1

Goal:
Add local model support without putting Ollama/Qwen/llama.cpp-specific code directly into WorkHarness.

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

## Step 9 - ContextBuilder v1

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

## Step 10 - Tools Foundation v1

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

Done when:
Tools are registered, MCP can become a controlled external capability source, and dangerous operations go through `ApprovalService`.

## Step 11 - Persistence v1

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

## Step 12 - Token / Cost Statistics v1

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

## Step 13 - Context Folding v1

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

## Step 14 - Memory v1

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

## Step 15 - RAG v1

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

## Step 16 - Multi-Agent v1

Goal:
Support real agentic development workflows.

Scope:

- `AgentRuntime` expansion.
- `PlannerAgent`.
- `CoderAgent`.
- `ReviewerAgent`.
- `TestRunnerAgent`.
- Multi-agent Run loop.
- `ExecutionGraph` placeholder or model.
- Run Timeline integration.
- Tests.

Done when:
Multiple agent roles can participate in a Run while preserving Run/Event observability.

## Step 17 - Remote Control v1

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

## External And Local Model Providers Go Through MCP

External/cloud AI providers are not integrated as direct SDK or raw HTTP adapters inside WorkHarness.

Local model providers such as Ollama, Qwen and llama.cpp-style servers are also not integrated as direct HTTP adapters inside WorkHarness.

Instead, WorkHarness talks to external and local model backends through MCP-backed provider adapters.

The local MCP server base already exists at:

`/Users/lammax/Documents/ThisIsMy/Programming/AI/MCP_server`

Use that project as the starting point for MCP-backed providers/tools unless a specific task says otherwise.

The existing local LLM implementation already exists at:

`/Users/lammax/Documents/ThisIsMy/Programming/AI/LlamaLocalServer`

When adding local LLM support, migrate or wrap the reusable local LLM logic from `LlamaLocalServer` into `MCP_server`. Do not copy that backend logic into WorkHarness.

This keeps provider integrations:

- replaceable
- auditable
- permissioned
- observable
- outside the core orchestration surface

Local CLI agent providers, such as Codex CLI and Cursor CLI, are the exception: they run locally through `ProcessRunner` and must still respect the same safety, approval and RunEvent boundaries.

---

## Core Philosophy

### Local-first

Everything should work locally whenever practical.

Cloud services are optional.

---

### Provider-agnostic

Never design around one provider.

Codex, Cursor, OpenAI, Anthropic, Ollama and future providers are implementations of the same abstraction.

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

- Codex CLI
- Cursor CLI

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
- supported providers
- version

---

### Provider Never Executes Tools

Architecture rule:

Run

↓

Orchestrator

↓

Agent

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

Providers generate AI.

Tools perform actions.

Providers must never execute tools directly.

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

- Codex CLI
- Cursor CLI
- MCP server launcher/helper processes
- Git
- Swift Build
- xcodebuild
- npm
- ffmpeg

Never specialize ProcessRunner for Codex, Cursor, Ollama or any other single backend.

Local LLM model execution must stay behind MCP-backed provider adapters, not direct WorkHarness `ProcessRunner` providers.

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
