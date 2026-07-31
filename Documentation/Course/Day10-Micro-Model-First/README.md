# Day 10 — Micro-model First

Status: code and deterministic tests are complete. One live WorkHarness run and
the video proof remain user actions.

## Task

The pipeline classifies development-task intent. Most requests first go to the
small Claude model. The larger model is called only when the first result is not
safe to accept.

```text
task text
  -> Haiku
  -> strict JSON validation
  -> status == OK and confidence >= 0.80 ? accept
  -> otherwise Sonnet fallback
  -> report + JSON artifact
```

The accepted response has exactly this schema:

```json
{"category":"bug","confidence":0.94,"status":"OK"}
```

Allowed categories are `bug`, `feature`, `refactoring`, `tests`,
`documentation`, `research`, and `security`. Status is `OK` or `UNSURE` and
confidence must be between 0 and 1. Markdown fences, missing or additional
fields, invalid enum values, `UNSURE`, and confidence below `0.80` cause a
fallback.

## Implementation

- `MicroModelEvaluationService` owns the provider-neutral evaluation flow.
- `AgentRuntime` executes Claude CLI through the existing runtime boundary.
- Haiku is the micro-model; Sonnet is the fallback model.
- Every attempt uses a fresh session with no project files, history, memory or
  working directory. The prompt prohibits tools and any requested tool call
  fails the evaluation.
- Raw model output is bounded to 4,000 characters and retained only long enough
  to validate it.
- RunEvents expose each request, validation result, route and aggregate result.
- The frozen catalog contains 24 cases: 8 simple, 8 boundary and 8 complex.

The completed Run produces:

- `day10-micro-model-report.md` — human-readable metrics and per-case routing;
- `day10-micro-model-results.json` — machine-readable complete results.

Metrics include the number handled by Haiku, fallback count, large-model call
count, unresolved and correct cases, average end-to-end latency, token usage and
reported cost.

## Live evaluation

Prerequisites:

1. Claude Code CLI is authenticated and available to WorkHarness.
2. Open WorkHarness and select any project. The evaluation does not read or
   modify that project.
3. Make sure no other long Claude run is competing for the same quota.

In Chat, send exactly:

```text
/micro-model evaluate
```

WorkHarness creates a dedicated `Inference Evaluation` Run immediately. Open
its timeline and wait for `Run Completed`. Do not change agents, models or the
prompt between cases. The command always uses the frozen Haiku → Sonnet policy,
independently of the manually selected chat model.

The assignment is complete when the live Run:

- evaluates all 24 inputs;
- shows Haiku decisions and any Sonnet escalations in the timeline;
- finishes without an unresolved provider error;
- creates both artifacts;
- reports micro-model count, fallback count, large-model calls and average
  latency;
- is captured in the video described in `video-script.md`.

If all 24 cases remain on Haiku, the fallback implementation is still covered
by deterministic tests. For a stronger visual proof, show the automated test
result after the live Run; do not alter the frozen live dataset to force an
escalation.

## Automated verification

```bash
xcodebuild test -project WorkHarness.xcodeproj -scheme WorkHarness \
  -destination 'platform=macOS' \
  -only-testing:WorkHarnessTests/MicroModelEvaluationTests
```

The suite verifies strict validation, every fallback condition, the balanced
24-case catalog, no unnecessary Sonnet calls, fallback-only routing, runtime
failure handling and the Chat command boundary.

## Evidence checklist

- [x] WorkHarness pipeline code.
- [x] 24 frozen simple/boundary/complex inputs.
- [x] Strict enum/score/status validation.
- [x] Haiku-first routing with Sonnet fallback.
- [x] Metrics and Markdown/JSON artifacts.
- [x] Deterministic tests, including forced fallback.
- [ ] Live `/micro-model evaluate` Run.
- [ ] Video proof.
