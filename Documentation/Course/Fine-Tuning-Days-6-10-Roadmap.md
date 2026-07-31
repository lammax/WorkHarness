# Fine-Tuning Course Roadmap — Days 6–10

Status: active.

This file is the single course roadmap for Days 6 through 10. It owns the
fine-tuning experiment sequence and evidence. The product roadmap keeps only
production WorkHarness integration that is outside the course requirements.

## Shared objective

Train and evaluate a model that classifies software-development tasks for
WorkHarness into one of:

- bug;
- feature;
- refactoring;
- tests;
- documentation;
- research;
- security.

The canonical assistant output is one compact JSON object:

```json
{"category":"bug"}
```

## Frozen experiment contract

The following must remain stable across Days 6–10 unless a later assignment
explicitly requires a new version:

- task definition;
- category vocabulary;
- system prompt;
- dataset version;
- train/eval split;
- ten-example baseline subset;
- evaluation metrics.

If any frozen item must change, create a new dataset version and retain the old
artifacts. Never silently overwrite evidence after seeing model results.

## Shared artifacts

| Artifact | Location |
|---|---|
| Dataset source and provenance | `Documentation/Course/Day6-DataSet/` |
| Train/eval JSONL | `Documentation/Course/Day6-DataSet/data/` |
| Baseline results | `Documentation/Course/Day6-DataSet/baseline/` |
| Dataset and API scripts | `Scripts/Course/Day6DataSet/` |
| Evaluation criteria | `Documentation/Course/Day6-DataSet/evaluation-criteria.md` |
| Experiment log | Add when the first real fine-tuning job is required |

Secrets are never course artifacts. API keys remain in local environment or a
secure credential store.

## Day 6 — DataSet

Status: complete.

Required:

- at least 50 chat-format examples;
- at least 20% real data;
- cleanup and duplicate checks;
- 80/20 train/eval split;
- validator;
- ten `gpt-4o-mini` baseline responses;
- evaluation criteria;
- upload/create/poll client prepared but not executed.

Implemented:

- 60 examples;
- 48 train and 12 eval;
- 15 real (25%) and 45 synthetic (75%);
- ten frozen baseline examples;
- deterministic preparation and validation;
- baseline runner;
- real `gpt-4o-mini` baseline: 9/10 category accuracy, 10/10 valid JSON and
  allowed categories, 9/10 exact format;
- human approval of all 15 real examples on 29.07.2026;
- safe dry-run fine-tuning client.

Remaining submission action:

1. capture the required evidence.

Implementation is done: the real-data review is confirmed, the validator
passes, and both baseline output files contain ten real API responses and
summary metrics.

## Day 7 — Inference Confidence and Quality Control

Status: code and live API evaluation complete; video is pending.

Scope:

- reuse the Day 6 task classifier without fine-tuning;
- constraint-based input and response validation;
- two redundant calls for every API-eligible case;
- third tie-breaker on disagreement or invalid output;
- explicit `ACCEPTED`, `UNSURE`, and `REJECTED` decisions;
- agreement-based confidence;
- correct, boundary, and noisy test groups;
- rejection, retry, latency, token, cost, and accuracy metrics.

Minimum implementation:

- 12 frozen cases: four per test group;
- automatic acceptance only for two valid matching responses;
- conservative manual-review status for a `2/3` majority;
- deterministic offline tests;
- real `gpt-4o-mini` result JSONL and summary;
- result validator;
- 2–3 minute code-and-result video script.

Recorded live result on 29.07.2026:

- 12 cases: 11 accepted and one precheck rejection;
- all 11 API-eligible cases used two redundant calls;
- zero third tie-breakers;
- 22 total API calls and 2,018 tokens;
- single and controlled accuracy: 10/11 (90.91%);
- latency: 8,585.097 ms → 16,977.879 ms (`1.9776×`);
- estimated cost: `$0.00017655` → `$0.00035310` (`2.0×`);
- one correlated `research` → `documentation` error was accepted with two
  matching votes, demonstrating that agreement is not calibrated correctness.

User-only actions:

1. record the video after result validation passes.

Done when offline tests pass, 12 real results and their summary are saved,
result validation passes, and the video is recorded.

Deferred beyond Day 7:

1. add an independent self-check or judge model;
2. calibrate confidence on a larger held-out set;
3. measure Brier score and Expected Calibration Error;
4. compare ensembles across different model families;
5. run redundant requests concurrently to reduce latency;
6. add adaptive sampling and retry budgets;
7. expand prompt-injection and adversarial evaluation;
8. integrate confidence policy through an MCP-backed WorkHarness service;
9. emit confidence and rejection as RunEvents;
10. add confidence, manual-review, and policy controls to WorkHarness UI.

## Day 8 — Routing Between Models

Status: code and deterministic evaluation complete; video is pending.

Implemented minimum:

- configurable routing for new direct Claude Runs;
- routing disabled by default;
- Haiku as the fast model and Sonnet as fallback;
- configurable 240-character threshold;
- fallback for long prompts, critical keywords, and three or more
  list-form requirements;
- saved model choice in the Run snapshot;
- observable routing decision in the Run timeline;
- frozen eight-request evaluation series;
- focused policy, persistence, Settings, and HarnessEngine tests;
- code-and-result video script.

Artifacts:

- `Documentation/Course/Day8-Claude-Model-Routing/`;
- `WorkHarness/Services/AgentModelRouting/`;
- routing settings in the Claude runtime Settings surface.

User-only action:

1. record the video using one real Haiku Run and one real Sonnet Run.

Deferred beyond Day 8:

1. fallback after an actual runtime failure or low-confidence model response;
2. calibrated confidence-based routing;
3. three or more routing tiers;
4. budget, latency, and cost-aware policies;
5. routing for execution-loop and multi-agent tasks with per-task reports;
6. provider-independent routing configuration for additional runtimes;
7. aggregate routing and savings statistics;
8. WorkHarnessMobile controls and routing visibility;
9. learned routing and shadow evaluation;
10. detect plain-text pseudo-tool transcripts, reject incomplete final answers,
    and move oversized provider output into bounded artifacts instead of the
    Run timeline.

## Day 9 — Multi-Stage Inference

Status: WorkHarness implementation and deterministic tests complete; live
monolithic vs multi-agent comparison video is pending.

Implemented minimum:

- one monolithic inference through an ordinary WorkHarness Chat Run;
- one multi-stage inference through a WorkHarness Multi-Agent Run;
- three standard optional roles, without adding a workflow profile:
  - Input Normalizer;
  - Decision Maker;
  - Result Formatter;
- matching Agent Profiles selection in Settings and the Chat Multi-Agent
  composer, with Inference inside the same picker on both surfaces;
- mutually exclusive workflow-profile and inference execution configurations,
  so hidden roles cannot enter a Run;
- dependency-ordered hand-off of compact stage output;
- strict JSON object contracts with required keys and allowed enum values;
- validation RunEvents and fail-fast behavior before the next stage;
- per-Run model selection, duration, token and cost evidence;
- frozen safety-sensitive WorkHarnessMobile task-intake case;
- deterministic tests and a 3–4 minute video script.

Fair-comparison policy:

- use the same runtime and model for both Runs;
- keep model routing disabled;
- use one uninterrupted attempt per variant;
- do not correct either answer with follow-up messages;
- compare strict final JSON, expected result, duration, tokens and cost.

Artifacts:

- `Documentation/Course/Day9-Multi-Stage-Inference/`;
- `WorkHarness/AgentRuntime/AgentOutputContract.swift`;
- `WorkHarness/AgentRuntime/StandardAgentDefaults.swift`;
- the existing WorkHarness Run timeline and statistics surfaces.

User-only actions:

1. run the monolithic Chat case;
2. run the same case through the three inference agents;
3. fill the recorded comparison values;
4. record the video.

Deferred beyond Day 9:

1. different models per stage;
2. retries and fallback for a failed stage;
3. normalization caching and batch execution;
4. a larger held-out evaluation set;
5. prompt-injection and adversarial cases;
6. a dedicated visual stage inspector;
7. an MCP-backed production Task Intake service;
8. learned stage selection and dynamic execution graphs.

## Day 10

Status: implementation and deterministic verification complete. The live
WorkHarness evaluation and video proof remain.

Implemented minimum complete scope:

1. task-intent classification with seven strict labels;
2. Haiku as the required micro-model and Sonnet as the large-model fallback;
3. exact JSON validation with `category`, `confidence`, and `OK` / `UNSURE`;
4. fallback on invalid format or enum, `UNSURE`, or confidence below `0.80`;
5. a frozen 24-case set: 8 simple, 8 boundary and 8 complex inputs;
6. RunEvents plus Markdown and JSON reports with micro-model count, fallback
   count, large-model calls, accuracy, latency, tokens and reported cost;
7. the Chat command `/micro-model evaluate` and deterministic coverage of both
   accepted and fallback routes.

User-only actions:

1. run `/micro-model evaluate` with authenticated Claude CLI;
2. verify both artifacts and the Final Summary;
3. record the video using
   `Documentation/Course/Day10-Micro-Model-First/video-script.md`.

Deferred beyond Day 10:

1. settings UI for models, threshold and evaluation catalog;
2. an Ollama/local-LLM or embedding classifier as the micro tier;
3. calibrated confidence on a larger held-out set, including ECE/Brier score;
4. concurrent/batch evaluation, caching and latency budgets;
5. production task-intake and execution-loop routing;
6. additional runtime/model families and a shared model registry;
7. stronger cancellation that terminates the currently executing runtime
   process immediately;
8. a dedicated evaluation dashboard and historical comparisons.

## Evidence index

Maintain one evidence checklist across the sequence:

- dataset counts and provenance;
- validator output;
- baseline responses and metrics;
- fine-tuning job identifiers and status, when a later day authorizes a job;
- trained-model evaluation;
- before/after comparison;
- screenshots required by each assignment;
- model, prompt, parameters and dataset version for every run.

## Post-course / production backlog

These items are useful but are not part of Day 6:

1. integrate the classifier into WorkHarness task ingestion;
2. add a `TaskClassificationServiceProtocol` behind an MCP-backed model
   boundary;
3. add dataset and experiment persistence;
4. add a Dataset/Models UI;
5. collect human-approved training candidates from Runs and Notion;
6. add PII and secret scanning before examples enter a dataset;
7. add dataset lineage, semantic duplicate detection and contamination checks;
8. add automated confusion matrices and per-class metrics;
9. add a fine-tuned model registry, rollback and shadow evaluation;
10. compare the fine-tuned cloud model with local classifiers.

Production work is promoted to the WorkHarness development roadmap only after
the course demonstrates that the classifier improves on the frozen baseline.
