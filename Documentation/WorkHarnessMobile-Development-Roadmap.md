# WorkHarness → WorkHarnessMobile Development Roadmap

Updated: 02.08.2026

## Purpose

WorkHarnessMobile is a lightweight remote client for WorkHarness.

All reasoning, agent execution, tools, approvals, persistence and project
ownership remain in WorkHarness on macOS. The mobile application displays remote
state and sends explicit user commands through the authenticated Remote Control
API.

```text
WorkHarness
├── owns Projects, Runs, Agents, Tools and Approvals
├── executes WorkHarnessMobile development tasks
├── validates builds and tests
├── records execution-loop evidence
└── exposes the Remote Control API
             ↓
WorkHarnessMobile
├── authenticates with WorkHarness
├── observes Runs and RunEvents
├── handles Approvals
└── sends small remote commands
```

This document is the long-term roadmap. The immutable Day 5 course pool is a
smaller execution slice:

`Documentation/Course/Day5-WorkHarnessMobile-Task-Pool.md`

## Repository Ownership

- WorkHarness:
  `/Users/lammax/Documents/ThisIsMy/Programming/AI/WorkHarness`
- WorkHarnessMobile:
  `/Users/lammax/Documents/ThisIsMy/Programming/AI/WorkHarnessMobile`
- Shared MCP servers:
  `/Users/lammax/Documents/ThisIsMy/Programming/AI/MCP_server`

WorkHarness agents may modify WorkHarnessMobile only inside an explicit Run and
through the existing approved MCP tool boundary. The mobile app must never call
an LLM, ACP agent or MCP development tool directly.

## Current Baseline

### WorkHarness

Already available:

- Run-centric orchestration and append-only RunEvents;
- Cursor ACP and Claude Code agent runtimes;
- Bug Fix, Research and other workflow profiles;
- validation, approval and MCP tool boundaries;
- Git/file/shell execution through MCP;
- authenticated Remote Control API;
- health, capabilities, project, Runs, RunEvents, approvals and SSE routes.

Now available for autonomous mobile development:

- provider-independent Markdown task-source abstraction;
- serial execution loop across multiple Runs;
- automatic profile selection per task;
- validation and Auto-approve-gated commit/push;
- current-branch execution without forced task branches;
- runtime and model snapshots for every task;
- visible start, pause-after-current-task, resume and stop controls;
- per-attempt metrics and Markdown comparison-report output;
- durable execution-loop checkpoints, relaunch recovery and repository
  reconciliation;
- tool-capable Ollama-backed Local LLM AgentRuntime;
- immutable per-task runtime/model snapshots and routing-v2 fallback metrics;
- bounded agent/tool artifacts and measured context-delivery policies.

Still required:

- tighten the mobile workspace contract before the first evidence run;
- execute and preserve two cloud attempts against the immutable Day 5 pool;
- execute and preserve the tool-capable local-model comparison;
- implement Remote Control API contract verification;
- expand mobile validation artifacts and integrated mobile/API testing.

### WorkHarnessMobile

Already available:

- SwiftUI application foundation;
- MVVM/service-oriented structure;
- dependency composition and navigation;
- remote-client protocol and domain types;
- fixture-backed pairing/workspace UI;
- Runs, Approvals and New Run surfaces;
- deterministic unit and UI coverage.

Current implementation status:

- `WHM-001`, `WHM-002` and `WHM-003` are committed;
- the `WHM-004` error/retry behavior is implemented, but its acceptance gate is
  not complete because the current unit suite contains one failing retry-count
  assertion;
- the app builds for the selected iPhone 17 Pro Simulator;
- DEBUG composition uses fixture routing;
- non-DEBUG composition still uses `InMemoryRemoteControlClient`, so there is
  no production network path yet;
- the next product feature after restoring a green validation baseline is
  `WHM-005` Reject approval.

Still required for the first production-capable client:

- production `URLSessionRemoteControlClient`;
- real endpoint/token connection flow;
- health and capability validation;
- real Runs, RunEvents and Approvals;
- reject approval;
- Keychain token storage;
- offline, unauthorized and expired-token handling;
- SSE live event streaming and reconnect;
- real mobile-to-WorkHarness integration verification.

## Delivery Principles

1. WorkHarness remains the source of truth for Run and approval state.
2. Mobile UI depends on a service/client protocol, never on URLSession directly.
3. Transport DTOs are mapped into mobile domain models before reaching UI.
4. Remote API changes are versioned or backward compatible.
5. Every production endpoint has deterministic transport tests.
6. Every mobile stage has an explicit done/not-done acceptance gate.
7. Security-sensitive values are stored in Keychain and never written to logs.
8. Live data is append-only where it represents WorkHarness RunEvents.
9. Features are delivered as small execution-loop tasks with one validated
   commit per task.
10. WorkHarnessMobile does not duplicate orchestration, provider or tool logic.
11. Large logs, tool results and artifacts stay outside active model/mobile
    context and are exposed through bounded previews, pagination or opaque
    references.
12. Mobile observability shows explicit Run state and safe summaries; it never
    invents or exposes private chain-of-thought.

## Current Delivery Snapshot

### Stable task progress

| Task | State | Evidence |
|---|---|---|
| `WHM-001` | Complete | Repository guidance and build/test contract committed. |
| `WHM-002` | Complete | Remote-control domain types split from the client protocol. |
| `WHM-003` | Complete | Placeholder test replaced with domain-state coverage. |
| `WHM-004` | Validation repair required | Error/retry UI exists; full unit gate currently fails in `retryCallsLoad()`. |
| `WHM-005`–`WHM-020` | Not started | Immutable Day 5 task definitions remain pending by design. |

The Day 5 task pool is immutable input. Effective completion state belongs in
this roadmap and execution-attempt reports; task-source `Status` fields remain
`pending` so cloud and local attempts use identical prompts.

### Validation snapshot — 02.08.2026

- Build: passed on `platform=iOS Simulator,name=iPhone 17 Pro`.
- Unit tests: 61 passed, 1 failed.
- Failing test: `RemoteWorkspaceViewModelTests/retryCallsLoad()` expects one
  aggregate load call, while retry currently invokes the three load-related
  service operations: capabilities, Runs and Approvals.
- UI/integration validation was not rerun during this roadmap audit.

### Available WorkHarness Remote Control surface

WorkHarness currently exposes bearer-authenticated health, capabilities,
Projects, Runs, Run details, RunEvents, SSE streaming, Approvals, approve,
reject, Run creation and cancellation routes. The remaining gap is the mobile
production transport and verified shared contract, not the absence of the
basic server operations.

Still missing at the shared contract level:

- canonical request/response fixtures consumed by contract tests;
- an explicit compatibility/version value in capabilities;
- verified mobile DTO coverage for errors, dates, enums and optional fields;
- verified SSE framing, ordering and reconnect cursor behavior.

### Immediate delivery order

1. Repair the `WHM-004` test contract and restore a green full unit gate.
2. Execute `WHM-005`–`WHM-009`: Reject, endpoint normalization, DTO mapping,
   URLSession foundation, health and capabilities.
3. Execute `WHM-010`–`WHM-015`: production Runs/Approvals/actions, Keychain,
   restore/disconnect and explicit connectivity/authentication states.
4. Execute `WHM-016`–`WHM-019`: SSE parser/stream, minimum Dashboard and Run
   Details.
5. Complete `WHM-020` with a real mobile-to-WorkHarness integration runbook and
   Release M1 evidence.

## Track A — WorkHarness as the Mobile Development Harness

### WH-A0. Mobile workspace contract

Status: Operational baseline exists; hardening and evidence capture remain.

Scope:

- register WorkHarnessMobile as the target workspace;
- load its repository rules and architecture guidance;
- constrain tools to the mobile repository;
- discover an available iOS Simulator;
- define standard build, unit-test and UI-test commands;
- refuse to start from an unexpected dirty worktree.

Done when:

- a Run can inspect, edit, build and test WorkHarnessMobile without accessing
  unrelated repositories;
- the selected simulator and validation commands are recorded as RunEvents.

### WH-A1. Execution Loop v1

Status: MVP and durable recovery implemented as WorkHarness Step 24; course
execution evidence pending.

Scope:

- read the ordered Markdown task pool;
- choose the workflow profile automatically;
- create one Run per task;
- validate, commit and push only successful tasks when the saved global
  `Auto-approve actions` setting permits it;
- bind Git operations to the repository pinned by the loop, independently of
  the project selected before execution starts;
- continue without user messages;
- stop and classify the first failure or intervention;
- produce the Day 5 metrics report.

Done when:

- the same immutable pool can be executed from the same base commit in two cloud
  attempts and one local-model attempt.

### WH-A2. Mobile validation pipeline

Status: Planned. Basic configured build/test execution exists, but artifact
retention, failure classification and a consistently green mobile regression
gate are not complete.

Scope:

- fast focused tests while a task is active;
- full mobile build/test gate before commit;
- optional UI-smoke gate for UI tasks;
- capture `.xcresult`, logs and screenshots as Run artifacts;
- classify compilation, test, simulator and infrastructure failures separately.

Done when:

- a failed validation prevents commit and records actionable evidence;
- a passed task links its commit to its validation artifacts.

### WH-A3. Remote API contract verification

Status: Planned.

Scope:

- keep canonical request/response fixtures in WorkHarness;
- verify mobile DTO compatibility with the current Remote Control API;
- cover authentication, errors, dates, enums and optional fields;
- validate SSE framing and event ordering;
- add a compatibility/version value to capabilities if the API evolves.

Done when:

- incompatible API changes fail contract tests before reaching the mobile app.

### WH-A4. Integrated mobile test environment

Status: Planned after the production URLSession client.

Scope:

- start a disposable local Remote Control server configuration;
- generate a temporary token;
- boot an iOS Simulator;
- exercise health, capabilities, Runs, RunEvents and Approvals;
- capture server and mobile logs in one parent Run;
- remove temporary credentials after the test.

Done when:

- WorkHarness can prove the end-to-end path without a manually configured
  production token.

### WH-A5. Task sources and planning

Status: Markdown first; Notion later.

Scope:

- keep `ExecutionTaskSourceProtocol` independent of a tracker vendor;
- use Markdown for the Day 5 submission;
- add Notion through MCP after the loop is stable;
- later add GitHub Issues or Linear adapters if needed;
- synchronize claim, status, result, commit and report links.

Claude note:

- Claude Runs use an isolated, explicitly allowlisted MCP configuration;
- connecting Notion to the user's standalone Claude installation is not enough;
- the Notion MCP capability must later be intentionally exposed through the
  WorkHarness runtime configuration with the same security policy;
- Cursor's existing Notion connection must not become a hidden dependency of
  the execution-loop engine.

Done when:

- changing tracker implementation does not change execution-loop orchestration.

### WH-A6. Mobile delivery dashboard

Status: Post-course.

Scope:

- task queue and current task;
- selected agent/profile/model;
- build/test state;
- commits and changed files;
- intervention and failure classification;
- consecutive-pass, first-pass, time, token and cost metrics;
- comparison of execution attempts.

Done when:

- a complete mobile-development attempt can be inspected and audited from
  WorkHarness without reading raw terminal output.

## Track B — WorkHarnessMobile Product Stages

## Stage 0. Foundation

Status: Fixture foundation implemented; production composition and a green
regression gate remain.

Goal:
Maintain a small, testable application foundation.

Scope:

- SwiftUI;
- MVVM;
- dependency injection/composition;
- Screen/Page or equivalent explicit navigation;
- remote-client service boundary;
- domain/transport separation;
- deterministic fixtures and tests.

Done when:

- UI does not own networking or credentials;
- feature ViewModels call service/client protocols;
- DEBUG fixtures and production composition are explicit;
- the app builds and tests on the selected iOS Simulator.

Current gap:

- non-DEBUG composition still selects `InMemoryRemoteControlClient`;
- the current unit suite has one failing `WHM-004` retry assertion.

## Stage 1. Pairing

Status: In progress. Fixture/manual UI exists; production pairing does not.

Goal:
Connect the phone to one WorkHarness instance safely.

Delivery order:

1. Manual address and bearer-token entry.
2. Health and capability validation.
3. Keychain persistence, restore and disconnect.
4. Offline, unauthorized and expired-token recovery.
5. Server-backed Pair Code.
6. QR representation of the same pairing protocol.

Done when:

- manual production connection works without embedding a token in source;
- token is stored only in Keychain;
- unauthorized state requires an explicit new credential;
- Pair Code and QR are not marked complete until WorkHarness exposes a real
  short-lived pairing protocol.

## Stage 2. Dashboard

Status: Planned; a minimum dashboard is included in the Day 5 pool.

Goal:
Make the most important remote state visible at launch.

Cards:

- Current Project;
- Current Run;
- Current Agent;
- Pending Approvals;
- Recent Runs;
- Quick Actions.

Delivery order:

1. Current Project, active Run and pending-approval count.
2. Navigation to Runs, Approvals and New Run.
3. Current Agent and Recent Runs.
4. Configurable Quick Actions.

Done when:

- empty, loading, offline and unauthorized states are explicit;
- every card is derived from remote domain state rather than fixture-only data.

## Stage 3. Runs

Status: Fixture-backed UI exists; production API integration is pending.

Goal:
Browse current and historical Runs.

Scope:

- history;
- status;
- duration;
- cost;
- provider/runtime;
- refresh and pagination when needed.

Done when:

- `GET /runs` populates the screen;
- status and optional metrics decode safely;
- active and terminal Runs are visually distinct;
- empty and transport-failure states are tested.

## Stage 4. Run Details

Status: Fixture-backed foundation exists; live production data is pending.

Goal:
Inspect one Run without reproducing WorkHarness orchestration on the phone.

Scope:

- timeline;
- logs;
- RunEvents;
- artifact references;
- tokens;
- cost;
- live SSE updates.

Done when:

- `GET /runs/{id}` and `/events` build the initial state;
- `/stream` appends events in order;
- leaving the screen cancels the stream;
- reconnect does not duplicate events;
- artifact references are visible even before artifact download is implemented.

## Stage 5. Chat

Status: Not started.

Goal:
Provide a minimal conversational surface over Runs.

Scope:

- ask a question;
- create a Run;
- continue a Run;
- show the resulting Run rather than owning a separate chat history.

Done when:

- every submitted message belongs to a Run;
- continuation uses a server-supported Run/session contract;
- Chat remains secondary to Dashboard and Runs.

## Stage 6. Projects

Status: Not started.

Goal:
Manage the project selected by WorkHarness.

Scope:

- Select;
- Open;
- Create;
- Delete.

Delivery constraint:

- Select/Open may precede mutation;
- Create/Delete require explicit WorkHarness API operations and approval policy;
- the mobile client must not access the Mac filesystem directly.

Done when:

- project operations are reflected by WorkHarness and audited as events;
- destructive operations require confirmation and server authorization.

## Stage 7. Providers

Status: Not started.

Goal:
Inspect and select the backend used by future Runs.

Scope:

- Current Provider/AgentRuntime;
- capabilities;
- switch runtime/model for a new Run.

Done when:

- choices come from WorkHarness capability discovery;
- unsupported combinations cannot be submitted;
- switching affects new Runs and does not silently mutate an active Run.

## Stage 8. Approvals

Status: In progress. Approve exists in fixtures; Reject and production API are
pending.

Goal:
Make the most important mobile action safe and fast.

Scope:

- Approve;
- Reject;
- View Diff;
- View Command;
- View Tool;
- one- or two-tap confirmation.

Delivery order:

1. Pending list with Approve and Reject.
2. Production API integration.
3. Clear resolved/error states.
4. Command/tool details.
5. Structured diff preview.

Done when:

- both decisions reach the shared WorkHarness approval service;
- duplicate decisions are prevented;
- sensitive or destructive details are visible before confirmation;
- approval resolution is observable in the related Run timeline.

## Stage 9. Notifications

Status: Not started.

Goal:
Notify the user only when remote attention is valuable.

Events:

- Approval Needed;
- Run Completed;
- Run Failed;
- Question From Agent.

Done when:

- notifications deep-link to the correct Run or approval;
- notification preferences are respected;
- tokens and sensitive command contents are not exposed on the lock screen by
  default;
- delivery works through an explicit WorkHarness notification architecture.

## Stage 10. Agent Monitor

Status: Not started.

Goal:
Create a truthful live view of agent progress.

Fields:

- Current Thought or safe summary;
- Current Step;
- Current Tool;
- Current File;
- Progress;
- ETA.

Done when:

- all fields come from explicit RunEvents or derived server state;
- private chain-of-thought is never invented or exposed;
- ETA is marked unavailable when there is insufficient evidence.

## Stage 11. Statistics

Status: Not started.

Goal:
Show useful usage and reliability metrics.

Scope:

- Daily Usage;
- Tokens;
- Cost;
- Providers/runtimes;
- Runs;
- Success Rate.

Done when:

- mobile totals match WorkHarness statistics for the same period;
- missing provider cost/token data remains distinguishable from zero.

## Stage 12. Search

Status: Not started.

Goal:
Search remote WorkHarness state.

Scope:

- Runs;
- Projects;
- Artifacts;
- Files;
- Tools.

Done when:

- search executes through a server API with project authorization;
- results deep-link to supported mobile destinations;
- the phone does not build an independent source-code index.

## Stage 13. Settings

Status: Partially represented by connection UI; full settings are not started.

Goal:
Control mobile-client preferences without duplicating WorkHarness settings.

Scope:

- Notifications;
- Appearance;
- Security;
- Devices;
- Server;
- Provider Preferences.

Done when:

- client-only settings remain local;
- server/provider settings use explicit Remote Control API operations;
- Save/Revert state is clear;
- secrets remain in Keychain.

## Stage 14. Widgets

Status: Not started.

Goal:
Expose glanceable, safe remote state.

Examples:

- Current Run;
- Pending Approval;
- Daily Cost.

Done when:

- widget data uses a secure shared container and refresh policy;
- sensitive approval content is hidden by default;
- tapping opens the correct application destination.

## Stage 15. Siri / Shortcuts

Status: Not started.

Goal:
Expose a minimal set of explicit system actions.

Actions:

- Create Run;
- Approve;
- Show Status;
- Open Project.

Done when:

- intents enforce authentication and confirmation appropriate to the action;
- approval cannot bypass WorkHarness policy;
- every mutation is recorded by WorkHarness.

## Stage 16. Apple Watch

Status: Optional.

Goal:
Support only the highest-value short interactions.

Scope:

- Approve;
- Reject;
- Run Status;
- Notifications.

Done when:

- actions are authenticated and synchronized with the phone/server;
- no independent orchestration or credential model is introduced.

## Release Sequence

### Release M1 — Production Remote Control

Includes:

- Stage 0 completion;
- Stage 1 manual address/token connection;
- minimum Stage 2 Dashboard;
- Stage 3 Runs;
- Stage 4 Run Details and SSE;
- Stage 8 Approve/Reject;
- Stage 13 server/session subset;
- Track A execution, validation and integration foundations.

This is the active WorkHarnessMobile target and contains the Day 5 task pool.

Current M1 state: foundation and fixture UX are present, but no production
transport milestone is complete. Release M1 is blocked first by the red unit
gate, then by `WHM-005`–`WHM-020`.

### Release M2 — Remote Interaction

Includes:

- Pair Code and QR;
- Stage 5 Chat;
- Stage 6 Projects;
- Stage 7 Providers;
- advanced Stage 8 previews;
- Stage 9 Notifications.

### Release M3 — Observability and Discovery

Includes:

- Stage 10 Agent Monitor;
- Stage 11 Statistics;
- Stage 12 Search;
- complete Stage 13 Settings.

### Release M4 — Apple Ecosystem

Includes:

- Stage 14 Widgets;
- Stage 15 Siri/Shortcuts;
- optional Stage 16 Apple Watch.

## Long-Term RemoteSDK Direction

Status: Architectural direction, not part of the immediate Day 5/M1 scope.

Proposed package:

```text
RemoteSDK
├── Models
├── API
├── Authentication
├── Streaming
├── WebSocket
├── RESTClient
├── EventBus
└── Serialization
```

Ownership:

- WorkHarness implements `RemoteServer`;
- iPhone, iPad, visionOS, web and CLI clients consume the protocol through the
  shared SDK or generated equivalents;
- the SDK contains transport/domain contracts, not UI or orchestration.

Extraction trigger:

- the production Remote Control contract is stable;
- WorkHarnessMobile has real REST and SSE implementations;
- a second client or platform needs the same protocol;
- duplicated networking/mapping code is measurable.

Do not extract the package only to prepare for hypothetical reuse. First prove
the contract through Release M1.

## Global Definition of Done

A mobile stage is complete only when:

- WorkHarness server capability exists and is documented;
- mobile production code uses the service/client boundary;
- DTO/domain mapping and failure states are covered;
- build and relevant tests pass;
- real integration is verified where a server interaction is involved;
- security and approval behavior is explicit;
- WorkHarness RunEvents and artifacts provide evidence;
- remote payloads and artifact access are bounded, reference-based and do not
  duplicate large raw content across UI, events and logs;
- roadmap status matches actual behavior.
