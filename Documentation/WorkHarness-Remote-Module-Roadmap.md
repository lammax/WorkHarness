# WorkHarness Remote Module Roadmap

Updated: 02.08.2026

Status: R0 Architecture Contract through R2 Server and Client Connection are
complete; R3 Pairing and Trusted Device is next.

This is the repository-owned implementation plan derived from
`/Users/lammax/Downloads/workharness-remote-module-roadmap-lean.md` and audited
against the current WorkHarness codebase on 02.08.2026.

It complements `Documentation/WorkHarness-Development-Roadmap.md`. The main
roadmap remains the product-level source of truth; this file owns the detailed
Remote Platform sequence and current-state audit.

## Product Goal

Deliver a secure, local-first personal control surface:

```text
trusted iPhone
    -> inspect/select projects
    -> inspect/create/cancel Runs
    -> receive live Run events
    -> resolve permitted approvals
    -> inspect/select provider
```

WorkHarness remains the execution node and source of truth. Remote clients are
presentation clients; they do not own agents, tools, providers, approvals,
memory, persistence or orchestration.

Only R0–R7 are active until Remote MVP v1 is complete. Everything in the
parking lot requires a separate explicit decision.

## R0 — Architecture Contract

Status: Complete.

### Dependency direction

```text
Remote client
    -> RemoteClient
    -> RemoteModels
    -> versioned transport contract
    -> WorkHarness RemoteServer
    -> narrow remote application service
    -> existing WorkHarness services / HarnessEngine
```

Required boundaries:

- WorkHarness Core never depends on RemoteServer.
- RemoteModels never import WorkHarness domain, SwiftUI, persistence, Swinject
  or a server framework.
- Remote routes never access repositories, providers, tools, HarnessEngine
  internals or ViewModels directly.
- Remote clients never import WorkHarness Core.
- DTOs are mapped explicitly to and from stable WorkHarness domain values.
- Remote does not expose arbitrary shell, file paths, secrets, database access
  or raw Tool execution.
- Every remote mutation must be authenticated, authorized, idempotent where
  retries are possible and observable through an audit record.

### RemoteSDK decision

Use the dedicated repository at
`/Users/lammax/Documents/ThisIsMy/Programming/AI/WorkHarnessRemoteSDK` as an
independently buildable Swift Package. Its package layout follows the
single-package, multiple-target convention used by `MCP_server`.

Lean package targets:

```text
RemoteSDK
├── RemoteModels
├── RemoteClient
└── RemoteTestSupport
```

R1 implements shared models only. HTTP and streaming implementations begin in
R2/R5 when required. Do not create separate Auth, Transport, Streaming,
WebSocket or umbrella targets before an active phase gives them an independent
responsibility.

### Remote MVP capabilities

- explicit server enable/disable and lifecycle state;
- versioned health/status/capability contract;
- short-lived pairing with local confirmation;
- revocable trusted-device credential stored in Keychain;
- read-only/full-control device access level;
- list/select existing projects;
- list Runs, Run details and ordered RunEvents;
- create and cancel Runs through RunService/HarnessEngine;
- authenticated live event stream with bounded buffering and reconnect;
- list and safely resolve permitted approvals;
- list/select providers without exposing provider configuration or secrets.

### Security constraints

- Remote is disabled by default.
- Loopback/development binding precedes LAN pairing.
- LAN discovery is not authentication.
- Pairing code possession alone never grants permanent trust.
- Permanent credentials live in Keychain; UserDefaults contains safe metadata
  only.
- High-risk approvals remain local-only initially.
- Request bodies, connections, subscriptions and event buffers are bounded.
- Errors never expose raw Swift errors, stack traces, environment variables,
  secrets or sensitive command lines.

### Deferred until after R7

- public internet exposure, cloud relay and APNs;
- multi-user accounts and complex permission matrices;
- arbitrary remote Tool execution or filesystem browsing;
- artifact content download and statistics API;
- Bonjour discovery;
- replay cursors and persistent stream recovery;
- administration console, web, CLI, Watch, voice and vision clients;
- plugin APIs and additional client platforms.

## Current-State Audit

The existing `WorkHarness/RemoteControl/RemoteControlService.swift` is a useful
prototype and compatibility baseline. It is not the final Remote Platform.

### Already available

- `NWListener`-based local HTTP server;
- explicit disabled/starting/running/stopping/failed lifecycle;
- remote server disabled by default with isolated listener failures;
- loopback binding by default unless LAN is enabled;
- versioned `/api/v1/status` contract and typed `URLSessionRemoteClient`;
- bearer-token check;
- `/health` and `/capabilities`;
- current project snapshot;
- Run list, Run details and RunEvent list;
- SSE stream for one Run;
- pending approvals plus approve/reject;
- Run creation and cancellation routed through `RunServiceProtocol`;
- authenticated per-Run MCP approval gateway;
- Settings fields for enabled, LAN, port and token;
- DI registration and a live Claude/MCP integration path.

### Gaps relative to the Remote contract

| Area | Current state | Required phase |
|---|---|---|
| Protocol models | Internal `Run`, `Project`, `ApprovalRequest` encoded directly | R1/R4 |
| API version | Versioned status; legacy feature routes remain unversioned | R4–R7 |
| Server lifecycle | Explicit lifecycle with isolated listener failure | Complete |
| Default state | Remote is disabled by default | Complete |
| Typed client | Typed status client implemented; feature calls pending | R4–R7 |
| Error model | Ad-hoc `{ "error": String }` | R1/R2 |
| Pairing | Static shared bearer token only | R3 |
| Credential storage | Token persisted in UserDefaults | R3 |
| Devices/revocation | Missing | R3 |
| Permissions | No per-device readOnly/fullControl policy | R3 |
| Project API | Current project only; no safe list/select contract | R4 |
| Run API | Useful prototype, no bounded/versioned DTO mapping | R4 |
| Streaming | Polling SSE per Run; no typed envelope/reconnect policy | R5 |
| Idempotency | Run creation has no `clientRequestId` deduplication | R5 |
| Approval safety | No revision check, device attribution or local-only class | R6 |
| Provider API | Missing | R7 |
| Hardening | No request/rate/session limits or remote audit log | R7 |
| Contract tests | DTO fixtures, client unit test and live status integration pass | R3–R7 |

### Migration rule

The R2 typed status path intentionally runs alongside the legacy feature
routes. Existing routes may be retired only after a versioned client and
integration tests cover each replacement.

## Active Implementation Sequence

| Phase | Status | Deliverable |
|---|---|---|
| R0 | Complete | Boundaries, MVP scope, security and migration contract |
| R1 | Complete | Independent RemoteSDK package with DTOs and fixtures |
| R2 | Complete | Explicit server lifecycle, `/api/v1` status and typed HTTP client |
| R3 | Next | Pairing, trusted device, Keychain credential and revocation |
| R4 | Pending | Versioned project and Run read APIs through service boundaries |
| R5 | Pending | Idempotent Run commands and authenticated bounded live stream |
| R6 | Pending | Versioned safe remote approvals with race protection and audit |
| R7 | Pending | Provider API, limits, logging, compatibility and MVP hardening |

## R1 — RemoteSDK Models

Goal: create the minimal shared protocol contract without server/network code.

Status: Complete in the dedicated `WorkHarnessRemoteSDK` repository.

Create:

```text
WorkHarnessRemoteSDK/
├── Package.swift
├── Sources/
│   ├── RemoteModels/
│   ├── RemoteClient/
│   └── RemoteTestSupport/
└── Tests/RemoteModelsTests/
    └── Fixtures/
```

Initial RemoteModels:

- `ProtocolVersion`;
- `ServerStatusDTO` and `ServerCapabilitiesDTO`;
- `ProjectSummaryDTO`;
- `RunSummaryDTO`, `RunDetailsDTO` and `RunEventDTO`;
- `ProviderSummaryDTO`;
- `ApprovalDTO`;
- `RemoteErrorDTO`;
- `RemoteEventEnvelope`;
- bounded `PageRequest` and `PageResponse`.

Constraints:

- Codable, Sendable and Equatable where useful;
- Foundation-only where practical;
- stable serialized enum values and documented UTC timestamps/durations;
- no WorkHarness target dependency;
- no SwiftUI, GRDB, SQLite, Swinject, Vapor, Hummingbird, Network or URLSession
  implementation;
- no server routes or placeholder services.

Acceptance:

- `swift test` passes inside the `WorkHarnessRemoteSDK` repository;
- representative JSON fixtures round-trip;
- the package builds independently;
- DTO/domain separation and compatibility behavior are documented.

## R2–R7 Acceptance Summary

### R2 — Server and Client Connection

Status: Complete.

- explicit disabled/starting/running/stopping/failed lifecycle;
- disabled by default and server failure isolated from WorkHarness;
- versioned status endpoint and typed client call;
- basic Remote Settings status and integration test.

### R3 — Pairing and Trusted Device

- expiring pairing session with local confirmation;
- one revocable device credential stored in Keychain;
- unpaired/revoked clients rejected;
- readOnly/fullControl authorization boundary;
- no refresh tokens, public accounts or complex roles.

### R4 — Projects and Runs Read API

- safe project list/current/select without arbitrary paths;
- bounded recent Runs, Run details and ordered RunEvents;
- explicit domain-to-DTO mapping through application services.

### R5 — Run Commands and Event Stream

- idempotent create/cancel Run commands;
- one authenticated event stream with heartbeat and bounded buffers;
- disconnect never stops a Run;
- reconnect performs HTTP snapshot refresh.

### R6 — Approvals

- pending/detail plus permitted grant/reject;
- expected state/revision, race handling and duplicate rejection;
- device attribution and audit record;
- high-risk categories remain local-only.

### R7 — Providers and MVP Hardening

- list/current/select provider contract;
- compatibility errors, request/body/session/rate limits;
- structured OSLog without secrets;
- last-seen and basic audit records;
- contract, integration and core security tests pass.

After R7, stop implementation and use the Remote MVP before selecting v2 work.
