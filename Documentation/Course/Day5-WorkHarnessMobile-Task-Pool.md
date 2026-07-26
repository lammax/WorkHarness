# Day 5 — WorkHarnessMobile Execution Task Pool

This Markdown file is the temporary task tracker for the Day 5 execution loop.
WorkHarness must treat the task definitions as the immutable ordered source of
truth. Per-attempt status and execution metadata belong in that attempt's
execution log so every comparison uses the same file revision.

The complete product and WorkHarness delivery sequence is maintained in
`Documentation/WorkHarnessMobile-Development-Roadmap.md`. This pool implements
only its first production release slice.

## Target

- Repository: `/Users/lammax/Documents/ThisIsMy/Programming/AI/WorkHarnessMobile`
- Base branch: `main`
- Build command: `xcodebuild build -project WorkHarnessMobile.xcodeproj -scheme WorkHarnessMobile -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`
- Test command: `xcodebuild test -project WorkHarnessMobile.xcodeproj -scheme WorkHarnessMobile -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`
- Execution order: ascending task ID
- Allowed status values: `pending`, `in_progress`, `passed`, `failed`, `blocked`
- Initial status for every task: `pending`
- During a course attempt, the status field in this source file remains
  `pending`; effective status is recorded in the attempt log.

## Loop Contract

1. Verify that the target repository is clean before starting a course run.
2. Record the target repository's current branch and HEAD. Do not create,
   switch or delete branches; all work stays on the branch active at loop start.
3. For each task, WorkHarness must:
   - select the most appropriate agent profile from the task and repository
     context;
   - create one observable Run;
   - execute only the stated scope;
   - run the task validation and the required regression checks;
   - create exactly one local Git commit only after validation passes;
   - record status, profile, runtime, start/end timestamps, duration, validation
     result and commit SHA in the execution log;
   - continue automatically with the next task.
4. Commit and push the current execution branch only when the saved
   WorkHarness Application setting `Auto-approve actions` is enabled. Do not
   force-push, open a pull request, install dependencies, change signing or
   access secrets during a course run.
5. Stop the loop on the first `failed` or `blocked` task, an unresolved approval,
   an unexpected dirty worktree, or a request for human clarification.
6. Do not edit a task prompt or acceptance criteria between tasks.
7. A task that needed a human message, a manual code correction or a second Run
   is not a first-pass success.

## Shared Validation

Before the first task, select an available iOS Simulator destination with
`xcodebuild -showdestinations`. Unless a task narrows validation, every passed
task must leave both commands successful:

```bash
xcodebuild build \
  -project WorkHarnessMobile.xcodeproj \
  -scheme WorkHarnessMobile \
  -destination '<selected iOS Simulator destination>'

xcodebuild test \
  -project WorkHarnessMobile.xcodeproj \
  -scheme WorkHarnessMobile \
  -destination '<selected iOS Simulator destination>'
```

## Tasks

### WHM-001 — Establish mobile repository guidance

- Status: `pending`
- Category: documentation
- Dependencies: none
- Goal: replace the generic project description with accurate
  WorkHarnessMobile development guidance.
- Scope:
  - document that the app is a thin remote client and WorkHarness owns all
    orchestration and model execution;
  - document the current SwiftUI/MVVM/service boundaries;
  - document build and test commands;
  - document that the mobile client talks only to the Remote Control API and
    never directly to ACP, MCP tools or an LLM;
  - correct the application name typo in the README.
- Done when:
  - repository-level instructions and README describe WorkHarnessMobile rather
    than the macOS WorkHarness application;
  - no source-code behavior changes;
  - Shared Validation passes.

### WHM-002 — Split remote-control domain types from the client protocol

- Status: `pending`
- Category: refactoring
- Dependencies: `WHM-001`
- Goal: make the Remote Control boundary easier to extend without changing
  behavior.
- Scope:
  - move remote session, capability, run, event, approval and error types out of
    `RemoteControlClient.swift` into clearly named files or cohesive groups;
  - preserve public names and semantics;
  - do not add networking or new UI.
- Done when:
  - `RemoteControlClient.swift` contains the client protocol and only directly
    related declarations;
  - all existing tests pass without weakening assertions;
  - Shared Validation passes.

### WHM-003 — Replace the placeholder unit test with domain-state coverage

- Status: `pending`
- Category: tests
- Dependencies: `WHM-002`
- Goal: add useful deterministic coverage for remote domain behavior.
- Scope:
  - remove the template placeholder test;
  - cover run terminal/non-terminal status behavior;
  - cover approval pending/resolved behavior;
  - cover user-facing remote error descriptions.
- Done when:
  - at least one focused assertion exists for each behavior above;
  - tests use no real network or arbitrary sleep;
  - Shared Validation passes.

### WHM-004 — Show remote workspace failures and provide retry

- Status: `pending`
- Category: bug
- Dependencies: `WHM-003`
- Goal: make existing load/action failures visible and recoverable.
- Scope:
  - render the current workspace error state;
  - add a retry action that invokes the existing reload path;
  - clear obsolete errors after a successful retry;
  - add stable accessibility identifiers and focused ViewModel tests.
- Done when:
  - a deterministic fixture failure is visible to the user;
  - retry can transition the same screen to loaded content;
  - the test suite proves both transitions;
  - Shared Validation passes.

### WHM-005 — Add Reject to the approval flow

- Status: `pending`
- Category: feature
- Dependencies: `WHM-004`
- Goal: support both decisions required by the Remote Control approval API.
- Scope:
  - add reject to the client protocol, fixture clients, service, ViewModel and
    approval UI;
  - keep approve behavior unchanged;
  - prevent duplicate decisions while a request is in flight;
  - add unit and UI coverage.
- Done when:
  - a pending approval can be rejected in one or two taps;
  - the rejected approval leaves the pending list;
  - approve and reject failures are both surfaced;
  - Shared Validation passes.

### WHM-006 — Normalize manually entered server addresses

- Status: `pending`
- Category: feature
- Dependencies: `WHM-005`
- Goal: turn a manual address into a valid, predictable Remote Control base URL.
- Scope:
  - introduce a small endpoint builder/value type;
  - accept a host with or without `http://` or `https://`;
  - preserve an explicit port;
  - reject unsupported schemes, missing hosts and malformed input;
  - do not perform a network request.
- Done when:
  - table-driven tests cover valid and invalid examples;
  - no URL string concatenation remains in pairing UI code;
  - Shared Validation passes.

### WHM-007 — Add transport DTO and domain mapping boundaries

- Status: `pending`
- Category: refactoring
- Dependencies: `WHM-006`
- Goal: isolate the WorkHarness wire format from mobile UI domain models.
- Scope:
  - add `Decodable` response DTOs needed by health, capabilities, runs, events
    and approvals;
  - add explicit mapping into existing mobile domain types;
  - configure date and enum decoding in one place;
  - keep fixtures working.
- Done when:
  - representative JSON fixtures from the current WorkHarness Remote Control API
    decode into expected domain values;
  - unknown optional fields do not break decoding;
  - malformed required fields fail deterministically;
  - Shared Validation passes.

### WHM-008 — Implement the URLSession client request foundation

- Status: `pending`
- Category: feature
- Dependencies: `WHM-007`
- Goal: create the production Remote Control client without coupling it to UI.
- Scope:
  - implement `URLSessionRemoteControlClient`;
  - inject `URLSession` or an equivalent transport boundary;
  - build authenticated JSON requests relative to the normalized base URL;
  - centralize HTTP status validation, decoding and error mapping;
  - use a mocked URL protocol in tests.
- Done when:
  - tests verify request URL, method, bearer header and JSON decoding;
  - non-2xx and invalid-response paths return typed errors;
  - no real network is used by unit tests;
  - Shared Validation passes.

### WHM-009 — Connect health and capabilities

- Status: `pending`
- Category: feature
- Dependencies: `WHM-008`
- Goal: verify a configured WorkHarness server before opening the workspace.
- Scope:
  - implement `GET /health` and `GET /capabilities`;
  - make the connection flow validate both responses;
  - expose an actionable incompatible-server error;
  - keep fixture pairing tests supported.
- Done when:
  - a mocked compatible server opens the workspace;
  - unavailable, unauthorized and incompatible responses remain on the
    connection screen with a clear error;
  - focused request and ViewModel tests pass;
  - Shared Validation passes.

### WHM-010 — Connect Runs, Run details and RunEvents

- Status: `pending`
- Category: feature
- Dependencies: `WHM-009`
- Goal: replace fixture Run reads with Remote Control API reads.
- Scope:
  - implement `GET /runs`, `GET /runs/{id}` and
    `GET /runs/{id}/events`;
  - map status, timestamps, provider, token and cost fields when present;
  - keep list ordering deterministic;
  - do not implement live streaming in this task.
- Done when:
  - mocked responses populate the Runs list and selected Run details;
  - empty-list, missing-Run and decoding failures are tested;
  - Shared Validation passes.

### WHM-011 — Connect approval list, approve and reject

- Status: `pending`
- Category: feature
- Dependencies: `WHM-010`
- Goal: execute approval decisions against the real API boundary.
- Scope:
  - implement `GET /approvals`;
  - implement `POST /approvals/{id}/approve`;
  - implement `POST /approvals/{id}/reject`;
  - refresh local state only after a successful response.
- Done when:
  - mocked tests verify all three endpoints and methods;
  - failed decisions leave the item pending and show an error;
  - successful decisions remove or resolve the item;
  - Shared Validation passes.

### WHM-012 — Connect Run creation and cancellation

- Status: `pending`
- Category: feature
- Dependencies: `WHM-011`
- Goal: start and stop WorkHarness Runs from the mobile client.
- Scope:
  - implement `POST /runs` with the documented goal payload;
  - implement `POST /runs/{id}/cancel`;
  - prevent empty goals and duplicate submissions;
  - refresh affected Run state after success.
- Done when:
  - mocked tests verify payload, route and bearer authentication;
  - start/cancel success and failure states are covered;
  - Shared Validation passes.

### WHM-013 — Store the remote session in Keychain

- Status: `pending`
- Category: security
- Dependencies: `WHM-012`
- Goal: remove persistent bearer-token ownership from UI and plain storage.
- Scope:
  - add a session-store protocol;
  - implement token storage with Apple Security/Keychain APIs;
  - support save, load and delete;
  - never log or render the complete token;
  - make tests deterministic with a fake session store.
- Done when:
  - production composition uses the Keychain implementation;
  - tests cover save/load/delete and store failures without reading the real
    user Keychain;
  - no complete token appears in logs or error messages;
  - Shared Validation passes.

### WHM-014 — Restore and clear saved connections

- Status: `pending`
- Category: feature
- Dependencies: `WHM-013`
- Goal: reconnect safely after relaunch and let the user disconnect.
- Scope:
  - restore a saved endpoint and token on launch;
  - validate health/capabilities before showing the workspace;
  - add a disconnect action that clears the session;
  - wire DEBUG fixtures and production URLSession behavior explicitly in
    composition.
- Done when:
  - valid saved sessions restore the workspace;
  - expired/unavailable sessions show a recoverable connection state;
  - disconnect removes saved credentials and returns to pairing;
  - Shared Validation passes.

### WHM-015 — Distinguish offline, unauthorized and invalid-server states

- Status: `pending`
- Category: bug
- Dependencies: `WHM-014`
- Goal: replace generic transport failures with actionable client states.
- Scope:
  - classify offline/timeout, HTTP 401/403, incompatible response and malformed
    payload;
  - clear an expired token after an explicit unauthorized result;
  - preserve the endpoint so the user can reconnect;
  - add retry behavior and deterministic tests.
- Done when:
  - each error class produces a distinct user-facing action;
  - unauthorized does not create an automatic retry loop;
  - offline retry can recover without re-entering a valid token;
  - Shared Validation passes.

### WHM-016 — Parse Server-Sent RunEvents

- Status: `pending`
- Category: tests
- Dependencies: `WHM-015`
- Goal: create a deterministic parser for the WorkHarness RunEvent SSE format.
- Scope:
  - parse fragmented UTF-8 input, multiple events, event IDs and JSON data;
  - ignore SSE comments/keepalive records;
  - report malformed event payloads without crashing;
  - do not open a live connection.
- Done when:
  - tests cover chunk boundaries, multiple events, keepalive and malformed data;
  - the parser has no URLSession or SwiftUI dependency;
  - Shared Validation passes.

### WHM-017 — Stream live RunEvents with cancellation and reconnect

- Status: `pending`
- Category: feature
- Dependencies: `WHM-016`
- Goal: update Run details from `GET /runs/{id}/stream`.
- Scope:
  - expose an async event stream from the remote client;
  - authenticate the SSE request;
  - append events without mutating prior events;
  - cancel the stream when leaving/changing the Run;
  - use bounded reconnect with the last event ID when recoverable;
  - do not retry unauthorized responses.
- Done when:
  - deterministic transport tests cover streaming, cancellation, reconnect and
    unauthorized termination;
  - Run details receive events in order without duplicates;
  - Shared Validation passes.

### WHM-018 — Add the minimum Dashboard

- Status: `pending`
- Category: feature
- Dependencies: `WHM-017`
- Goal: provide a compact launch surface from already loaded remote data.
- Scope:
  - show current project, active Run and pending-approval count;
  - provide quick navigation to Runs, Approvals and New Run;
  - derive the cards through a ViewModel/service boundary;
  - do not add statistics, search, widgets or notifications.
- Done when:
  - dashboard cards handle loaded, empty and error states;
  - quick actions navigate to the existing destinations;
  - focused ViewModel and UI coverage exists;
  - Shared Validation passes.

### WHM-019 — Complete the minimum Run Details surface

- Status: `pending`
- Category: feature
- Dependencies: `WHM-018`
- Goal: show the information already available from Run and RunEvent responses.
- Scope:
  - show status, duration, provider, tokens and cost when available;
  - show the ordered event timeline and event details;
  - expose artifact references without implementing file download;
  - preserve the live event updates from `WHM-017`.
- Done when:
  - missing optional metrics render safely;
  - timeline order and terminal state are covered by tests;
  - no fixture-only field is required by production UI;
  - Shared Validation passes.

### WHM-020 — Add the real integration runbook and release checklist

- Status: `pending`
- Category: documentation
- Dependencies: `WHM-019`
- Goal: make the mobile-to-WorkHarness path reproducible.
- Scope:
  - document Remote Control enablement, LAN binding, endpoint and token setup;
  - document simulator/device prerequisites and security cautions;
  - document a manual integration flow for health, capabilities, Runs, live
    events, approve, reject, start and cancel;
  - document build/test commands and known limitations;
  - update the mobile roadmap status to match implemented behavior.
- Done when:
  - a developer can follow one ordered checklist without reading source code;
  - the checklist contains expected results for every API action;
  - documentation does not expose a real bearer token;
  - Shared Validation passes.

## Deferred Mobile Roadmap

The task pool intentionally stops after a production-capable Remote Control
foundation and the minimum Dashboard/Run Details surfaces. The following remain
outside the Day 5 pool:

- QR and pair-code provisioning backed by a real server pairing protocol;
- full Chat continuation UX;
- project create/delete;
- provider switching;
- diff/command/tool approval previews;
- push notifications;
- detailed agent monitor and ETA;
- statistics, global search and client preference surfaces;
- widgets, Siri/Shortcuts and Apple Watch;
- extraction of a reusable `RemoteSDK` package for iPhone, iPad, visionOS, web
  and CLI clients.
