---
name: WorkHarness Project Rules
alwaysApply: true
---

# WorkHarness

WorkHarness is a local-first macOS SwiftUI AI Agent Harness. `Run` is the
central domain entity; Chat is only a UI surface over append-only `RunEvent`
values.

## Required architecture

```text
View -> ViewModel -> Service / HarnessFacade -> HarnessEngine
                                                ↓
                                      Repository / Provider / Tool
```

- Views render layout, bindings, and forwarded actions only.
- Feature ViewModels depend on service protocols, never repositories,
  providers, tools, runtimes, network clients, or persistence.
- Providers and real tools execute only through MCP-backed boundaries.
- Full coding agents stay behind `AgentRuntime`; prefer ACP.
- Generic orchestration must not branch on concrete model or agent names.
- Important Run actions append `RunEvent` values; never mutate recorded events.
- Dangerous actions use the shared approval path.

## Swift and UI conventions

- Use Swift, SwiftUI, Observation, Swift Concurrency, Swinject, SQLite, and
  Swift Testing patterns already present in adjacent files.
- Feature types live in `extension <Name>Screen`.
- Keep Page routing in the Screen ViewModel.
- Keep UI strings, spacing, sizes, icons, and identifiers in one module Design.
- Use constructor injection, typed errors, explicit cancellation, and focused
  deterministic tests.
- New Swift files use `Created by Auto (Codex) on DD.MM.YYYY`.

## Validation and scope

- Inspect neighboring code, DI registration, and tests before editing.
- Implement the smallest coherent slice without unrelated refactoring.
- For Swift changes, run the macOS `xcodebuild build` and relevant tests.
- Do not claim validation succeeded without command evidence.
- Do not commit or push unless explicitly requested.

The complete source of truth is `AGENTS.md`; `CLAUDE.md` contains the equivalent
Claude-specific rules and concrete good/bad code examples.
