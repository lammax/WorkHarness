# WorkHarness Development Roadmap

Updated: 08.07.2026

WorkHarness is a local-first macOS SwiftUI AI Agent Harness. It must stay Run-centric, provider-agnostic and safety-aware. Do not treat it as a generic chat app.

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
- Tests passing for the current stable slice.

Do not add `CodexCLIProvider` or `CursorCLIProvider` before the safety and process infrastructure steps are complete.

## Roadmap Rules

- Do not skip foundations.
- Keep Views out of repositories, providers, tools and engine internals.
- Keep ViewModels behind service/facade boundaries.
- Add safety and observability before real shell/tool/CLI execution.
- Prefer small, buildable steps with tests where behavior crosses service, repository, engine, provider or ViewModel boundaries.
- Commit and push stable validated slices before starting broad new work.

## Completed Steps

- Step 1 - Project Selector UI v1.
- Step 2 - Durable Project Storage v1.
- Step 3 - Run Timeline v1.
- Step 4 - Approval / Safety Foundation.

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

## Step 5 - CLI Infrastructure v1

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

## Step 6 - CodexCLIProvider v1

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

## Step 8 - ContextBuilder v1

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

## Step 9 - Tools Foundation v1

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
- Approval integration.
- Tool `RunEvent` entries.
- Tests.

Done when:
Tools are registered, and dangerous operations go through `ApprovalService`.

## Step 10 - Persistence v1

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

## Step 11 - Token / Cost Statistics v1

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

## Step 12 - Context Folding v1

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

## Step 13 - Memory v1

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

## Step 14 - RAG v1

Goal:
Search project knowledge and files.

Scope:

- Document ingestion.
- Chunking.
- Embeddings provider.
- Vector storage.
- `RAGSearchTool`.
- Citations/metadata.
- `ContextBuilder` integration.
- Tests.

Done when:
Relevant indexed knowledge can be retrieved with citations and inserted into context through the approved context path.

## Step 15 - Multi-Agent v1

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

## Step 16 - Remote Control v1

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
