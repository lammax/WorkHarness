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
- Minimal sidebar project display.
- Tests passing for the current stable slice.

Do not add `CodexCLIProvider` or `CursorCLIProvider` yet.

## Roadmap Rules

- Do not skip foundations.
- Keep Views out of repositories, providers, tools and engine internals.
- Keep ViewModels behind service/facade boundaries.
- Add safety and observability before real shell/tool/CLI execution.
- Prefer small, buildable steps with tests where behavior crosses service, repository, engine, provider or ViewModel boundaries.
- Commit stable validated slices before starting broad new work.

## Step 1 - Commit Current Stable Work

Goal:
Persist the already implemented and tested Durable AppSettings + Project Core changes.

Why:
The working tree already contains meaningful validated architecture work. Commit it before starting new UI or CLI work.

Scope:

- Review current `git status`.
- Stage only related Durable AppSettings + Project Core changes.
- Confirm tests/build state in the commit message or final handoff.
- Push only when explicitly requested.

Done when:
The stable AppSettings + Project Core slice is committed, and the next task can start from a clean baseline.

## Step 2 - Project Selector UI v1

Goal:
Allow the user to add and select a working project from the app UI.

Why:
CLI providers, tools, context building and future RAG all require a current project root path.

Scope:

- Add minimal project selector UI.
- Show current project clearly in the sidebar.
- Allow adding a project with display name and root path.
- Allow selecting current project.
- Support empty state when no projects exist.
- Use `ProjectServiceProtocol`.
- Preserve Screen/Page/View/ViewModel/Design boundaries.
- Add focused ViewModel tests if selection/add flows gain non-trivial state.

Do not add:

- Codex CLI.
- Cursor CLI.
- File indexing.
- RAG.
- SQLite.
- Tools.

Done when:
A user can add a project, select it, see it in the sidebar, and the UI does not bypass the service boundary.

## Step 3 - Durable Project Storage v1

Goal:
Persist projects and current project between app launches.

Why:
Project Core currently uses in-memory storage. Before CLI execution, current project should survive restart.

Scope:

- Add UserDefaults-backed or JSON-backed `ProjectRepositoryProtocol`.
- Keep `InMemoryProjectRepository` for tests.
- Persist project list.
- Persist current project id if appropriate.
- Register the durable implementation in DI.
- Add restore and fallback tests.

Do not add:

- GRDB.
- Run persistence.
- RAG persistence.

Done when:
Projects and the selected current project are restored after app restart, with deterministic tests for persistence behavior.

## Step 4 - Run Timeline v1

Goal:
Turn Runs page into a real observability and debugging surface.

Why:
Before real CLI providers produce complex output, Runs must be inspectable.

Scope:

- Add Run detail page.
- Show ordered `RunEvent` entries.
- Add event inspector.
- Show run status.
- Show token/cost summary.
- Add artifacts placeholder.
- Add ViewModel tests for ordering, selection and summary presentation.

Done when:
The Runs area can explain what happened in a Run without requiring logs or debugger inspection.

## Step 5 - Approval / Safety Foundation

Goal:
Introduce the safety model before shell, tools or CLI execution.

Why:
CLI providers and tools will eventually execute commands or modify files. Safety must exist first.

Scope:

- Add `ApprovalServiceProtocol`.
- Add `ApprovalService`.
- Add safety modes:
  - Read Only.
  - Ask Before Write.
  - Ask Before Shell.
  - Auto Inside Sandbox.
- Support approval states:
  - pending.
  - granted.
  - rejected.
  - cancelled or expired if needed.
- Add approval modal or page.
- Emit or process approval `RunEvent` entries.
- Add tests for state transitions and denied actions.

Done when:
Potentially dangerous actions have a single approval path that can be used later by tools and CLI infrastructure.

## Step 6 - CLI Infrastructure v1

Goal:
Create reusable infrastructure for CLI-backed providers.

Why:
Codex CLI and Cursor CLI should share the same process execution layer.

Scope:

- Add `ProcessRunner`.
- Support stdout streaming.
- Support stderr streaming.
- Support cancellation.
- Support timeout.
- Support exit code and error mapping.
- Add tests using safe commands or a fake process abstraction.

Do not add:

- Codex-specific code.
- Cursor-specific code.
- Provider-specific orchestration branches.

Done when:
The app has tested process execution infrastructure that is not tied to any one AI backend.

## Step 7 - CodexCLIProvider v1

Goal:
Add Codex CLI as the first real AI backend.

Scope:

- Implement `CodexCLIProvider` behind `AIProvider`.
- Use `ProcessRunner`.
- Map CLI output to `AIEvent`.
- Register the provider in `ProviderRegistry`.
- Make it selectable in Settings.
- Preserve `HarnessEngine` concepts.

Done when:
Codex CLI can be selected as a provider and produce Run events through the existing provider abstraction.

## Step 8 - CursorCLIProvider v1

Goal:
Add Cursor CLI as the second real AI backend.

Why:
This validates that the provider abstraction is strong enough.

Scope:

- Implement `CursorCLIProvider`.
- Reuse `ProcessRunner`.
- Map output to `AIEvent`.
- Register the provider.
- Make it selectable in Settings.
- Avoid `HarnessEngine` changes unless a provider-agnostic gap is discovered.

Done when:
Cursor CLI works through the same provider abstraction without Codex-specific assumptions leaking into orchestration.

## Step 9 - ContextBuilder v1

Goal:
Create a single path for assembling context before provider execution.

Scope:

- Add `ContextBuilderProtocol`.
- Add minimal `ContextBuilder`.
- Include:
  - user message.
  - current project.
  - root path.
  - recent run summary placeholder.
  - selected files placeholder.
  - token budget.
- Produce `ContextSnapshot`.
- Add tests.

Do not add:

- RAG.
- Full memory system.
- Large project indexing.

Done when:
Provider requests can be built from a traceable `ContextSnapshot` instead of ad hoc strings.

## Step 10 - Tools Foundation

Goal:
Move from provider chat to real agent harness actions.

Scope:

- Add `ToolProtocol`.
- Add `ToolRegistry`.
- Add:
  - `FileReadTool`.
  - `FileWriteTool`.
  - `ShellTool`.
  - `GitTool`.
- Route dangerous operations through `ApprovalService`.
- Emit tool `RunEvent` entries.

Done when:
Tools are registered, observable and safety-gated without direct UI/provider coupling.

## Step 11 - Persistence v1

Goal:
Introduce durable application persistence.

Scope:

- Add GRDB/SQLite.
- Persist:
  - Runs.
  - RunEvents.
  - Projects.
  - Settings.
- Keep memory/RAG persistence separate for later.

Done when:
Core app state can survive restart through a structured persistence layer with repository boundaries intact.

## Step 12 - Memory / Context Folding / RAG

Goal:
Add long-term intelligence after core execution is stable.

Scope:

- Context folding.
- Project memory.
- Run summaries.
- RAG indexing.
- RAG search tool.
- Citations and metadata.

Done when:
Long-running work can be summarized, searched and reintroduced into context through explicit context-building paths.

## Step 13 - Multi-Agent v1

Goal:
Support orchestrated multi-agent development workflows.

Scope:

- `PlannerAgent`.
- `CoderAgent`.
- `ReviewerAgent`.
- `TestRunnerAgent`.
- Multi-agent Run flow.
- Optional `ExecutionGraph` model.

Done when:
Multiple agent roles can participate in a Run without breaking Run/Event observability.

## Step 14 - Remote Control v1

Goal:
Prepare for mobile app control.

Scope:

- Local HTTP/WebSocket server.
- Run streaming.
- Approval requests.
- Mobile-safe API.
- Authentication.

Done when:
The desktop app can expose controlled, authenticated Run state and approval operations for a future mobile client.
