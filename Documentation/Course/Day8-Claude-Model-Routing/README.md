# Day 8 — Claude Model Routing

Status: implementation and deterministic evaluation complete; video evidence
is pending.

## Result

WorkHarness routes new direct Claude Runs between two Claude Code models:

```text
prompt
  ├─ short and simple ────────────────> Haiku
  └─ long, critical, or multi-part ──> Sonnet
```

The feature is disabled by default. The safe defaults are:

- fast model: Haiku;
- strong fallback model: Sonnet;
- prompt-length threshold: 240 characters.

The user enables and configures routing in:

`Settings → Execution & Providers → Claude Code CLI`

Changes are draft values until **Save for Next Run** is pressed. They never
replace the model inside an already running Run.

## Routing heuristics

Sonnet is selected when any condition is true:

1. the prompt contains more than the configured number of characters;
2. the prompt contains a critical keyword, including architecture, security,
   authentication, authorization, migration, concurrency, credential, or
   token terms in English or Russian;
3. the prompt contains at least three list-form requirements.

Otherwise Haiku is selected.

If routing is disabled, WorkHarness uses the manually selected agent model.

## Observability

Every automatic decision creates a `Model Routing` RunEvent with:

- selected model;
- fast or fallback route;
- decision reason;
- prompt length;
- configured threshold;
- matched critical keyword, when applicable.

The selected model is also frozen in `Run.executionBackend.modelId` and passed
to the Claude runtime. A later Settings change cannot alter that Run.

## Verification

The automated suite verifies:

- disabled routing preserves the manual model;
- a short prompt selects Haiku;
- long, critical, and multi-requirement prompts select Sonnet;
- routing settings save, revert, restore safe defaults, and persist;
- HarnessEngine records the decision and configures the selected model;
- all RunEvent types have valid timeline icons.

Commands:

```bash
xcodebuild build \
  -project WorkHarness.xcodeproj \
  -scheme WorkHarness \
  -destination 'platform=macOS'

xcodebuild test \
  -project WorkHarness.xcodeproj \
  -scheme WorkHarness \
  -destination 'platform=macOS'
```

The frozen evaluation series is in
[`test-prompts.md`](test-prompts.md). The short submission recording follows
[`video-script.md`](video-script.md).

## Submission checklist

- [x] working routing between two models;
- [x] cheap/fast model first;
- [x] fallback to the stronger model;
- [x] more than one explicit heuristic;
- [x] deterministic series showing which model each request uses;
- [x] code;
- [ ] user records the video.

