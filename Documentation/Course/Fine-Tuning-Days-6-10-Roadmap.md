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

## Days 8–10

Status: requirements not received.

Add each assignment here when its exact wording is available. Do not infer
course requirements in advance.

Every later day must state:

- required input dataset version;
- model and parameters;
- commands executed;
- external cost or approval required;
- produced artifacts;
- evaluation against the frozen baseline;
- user-only evidence steps;
- completion criteria;
- out-of-scope production work.

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
