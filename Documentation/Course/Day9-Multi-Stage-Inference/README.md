# Day 9 — Multi-Stage Inference in WorkHarness

Status: implementation and deterministic tests complete; live comparison video
pending.

## Objective

Compare one monolithic Chat inference with a three-stage Multi-Agent inference
inside WorkHarness. No Python runner or direct model API is used.

The task is safety-aware intake of a complex software-development request:

- classify the primary category;
- choose the execution profile;
- decide whether the request can execute automatically;
- return a canonical reason code.

The final strict result has this shape:

```json
{"category":"security","profile":"implementation","decision":"manual_review","reason_code":"security_sensitive"}
```

## Fair comparison

Both Runs must use:

- the same WorkHarness build;
- the same current project;
- the same agent runtime;
- the same model;
- model routing disabled;
- no manual correction after Run start.

Use Claude Haiku for both Runs when it is available. If Haiku is unavailable,
use Sonnet for both. Do not compare different models in the minimum submission.

## Variant A — Monolithic Chat

1. Open a new Chat Run.
2. Confirm the selected runtime/model.
3. Paste the complete prompt from `monolithic-prompt.md`.
4. Start the Run once without follow-up messages.
5. Record the Run ID, duration, tokens, cost, JSON validity and exact-match
   result.

Expected output:

```json
{"category":"security","profile":"implementation","decision":"manual_review","reason_code":"security_sensitive"}
```

## Variant B — Multi-Agent

1. Open a new Run and select `Multi-Agent`.
2. In the execution-plan draft, disable the assistants from the currently
   selected coding/research profile. This changes only the next Run draft and
   does not rewrite the profile.
3. Enable, in order:
   - Input Normalizer;
   - Decision Maker;
   - Result Formatter.
4. Select the same model used by the monolithic Run for all three agents.
5. Paste only the raw task from `test-cases.md`.
6. Start the Run once without follow-up messages.

WorkHarness passes each stage output to the next stage. Every stage has a strict
JSON output contract. Invalid JSON, missing or extra keys, empty values and
unsupported enum values fail validation and stop the chain.

Expected stages:

```json
{"intent":"add","scope":"code","clarity":"clear","risk":"high"}
```

```json
{"category":"security","profile":"implementation","decision":"manual_review","reason_code":"security_sensitive"}
```

```json
{"category":"security","profile":"implementation","decision":"manual_review","reason_code":"security_sensitive"}
```

## Evidence to record

| Metric | Monolithic Chat | Multi-Agent |
|---|---:|---:|
| Model | Pending | Pending |
| Run ID | Pending | Pending |
| Model calls / agents | 1 | 3 |
| Duration | Pending | Pending |
| Input tokens | Pending | Pending |
| Output tokens | Pending | Pending |
| Cost | Pending | Pending |
| Strict final JSON | Pending | Pending |
| Exact expected result | Pending | Pending |
| Intermediate validation | N/A | Pending |

The honest conclusion must state whether decomposition improved correctness or
observability and how much additional latency, token usage and cost it required.

## Deterministic implementation checks

The automated suite covers:

- the three roles being available without adding a workflow profile;
- their disabled-by-default state;
- dependency ordering;
- draft-only toggles that do not mutate the selected profile;
- strict JSON and enum validation;
- output hand-off between stages;
- stopping before the next stage after invalid output;
- validation RunEvents.

Run:

```bash
xcodebuild test \
  -project WorkHarness.xcodeproj \
  -scheme WorkHarness \
  -destination 'platform=macOS'
```

## Submission

Required evidence:

- WorkHarness code;
- one monolithic Chat Run;
- one three-stage Multi-Agent Run;
- visible Run timeline and metrics;
- the video described in `video-script.md`.
