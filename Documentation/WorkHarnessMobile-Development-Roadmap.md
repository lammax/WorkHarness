# WorkHarness → WorkHarnessMobile Development Roadmap

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

Still required for autonomous mobile development:

- durable task-source abstraction;
- serial execution loop across multiple Runs;
- automatic profile selection per task;
- validation and commit gating;
- per-attempt metrics and comparison reports;
- a tool-capable local-model AgentRuntime for the Day 5 local comparison.

### WorkHarnessMobile

Already available:

- SwiftUI application foundation;
- MVVM/service-oriented structure;
- dependency composition and navigation;
- remote-client protocol and domain types;
- fixture-backed pairing/workspace UI;
- Runs, Approvals and New Run surfaces;
- deterministic unit and UI coverage.

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

## Track A — WorkHarness as the Mobile Development Harness

### WH-A0. Mobile workspace contract

Status: Baseline exists; tighten before the first autonomous loop.

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

Status: MVP implemented as WorkHarness Step 24; course execution evidence
pending.

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

Status: Planned.

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

Status: Mostly implemented; production networking boundaries remain.

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
- roadmap status matches actual behavior.
