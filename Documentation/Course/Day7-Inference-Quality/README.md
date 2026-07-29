# Day 7 — Inference Confidence and Quality Control

Status: code and live OpenAI evaluation complete; video is pending.

## Critical task

The Day 6 WorkHarness task classifier is reused without fine-tuning. A wrong
category can select an unsuitable agent workflow, so low-confidence results
must not be applied silently.

Input:

- one natural-language software-development task.

Output:

- category: `bug`, `feature`, `refactoring`, `tests`, `documentation`,
  `research`, or `security`;
- status: `ACCEPTED`, `UNSURE`, or `REJECTED`;
- explicit confidence derived from vote agreement;
- complete attempts, latency, token usage, and estimated cost.

Model: `gpt-4o-mini`.

Fine-tuning: not used.

## Two quality-control approaches

### 1. Constraint-based

Input constraints:

- input must be a string;
- input must not be empty;
- maximum length is 2,000 characters;
- input must contain at least three letters.

Response constraints:

- the complete response must parse as JSON;
- it must contain exactly one `category` field;
- the category must be one of the seven allowed values;
- JSON must use canonical compact format with no Markdown or explanation.

Any input that fails precheck is rejected before an API call. A response that
fails a constraint cannot participate in automatic acceptance.

### 2. Redundancy

Each API-eligible input receives two independent calls with the same request:

1. two valid matching votes → `ACCEPTED`, confidence `1.0`;
2. disagreement or invalid response → a third tie-breaker call;
3. two of three valid votes agree → `UNSURE`, confidence `0.667`;
4. no valid majority → `REJECTED`.

Because the task treats errors as costly, a `2/3` majority is exposed for
manual review rather than silently accepted.

## Frozen test set

`test-cases.jsonl` contains exactly 12 cases:

| Group | Count | Purpose |
|---|---:|---|
| Correct | 4 | Clear bug, feature, tests, and documentation tasks |
| Boundary | 4 | Security/feature, refactoring/tests, bug/research boundaries |
| Noisy | 4 | Log noise, prompt injection, informal text, invalid punctuation |

The final noisy case is intentionally rejected by input constraints without
spending tokens. The other 11 cases use redundant inference.

## Offline validation

Reuse the Day 6 virtual environment:

```bash
source .venv-day6/bin/activate
python3 -m unittest discover \
  -s Scripts/Course/Day7InferenceQuality \
  -p 'test_*.py' \
  -v
python3 Scripts/Course/Day7InferenceQuality/run_quality_evaluation.py --dry-run
```

Expected:

```text
Ran 11 tests
OK
Day 7 dry-run PASSED
Cases: 12 | API-eligible: 11
Planned API calls: 22 minimum, 33 maximum
No network request or cost was created.
```

## Live run

Run this in the same Terminal where `OPENAI_API_KEY` is exported:

```bash
source .venv-day6/bin/activate
python3 Scripts/Course/Day7InferenceQuality/run_quality_evaluation.py
python3 Scripts/Course/Day7InferenceQuality/validate_results.py
```

The runner does not print or store the API key. It creates:

- `results/inference-results.jsonl` — every raw attempt and decision;
- `results/summary.json` — rejection, retry, latency, token, cost, and accuracy
  metrics.

No structured-output enforcement is used. Format validity remains a measured
constraint rather than an API-guaranteed result.

## Recorded metrics

The summary reports:

- accepted, unsure, rejected, and not-automatically-accepted counts;
- precheck rejections;
- cases using redundant inference;
- cases requiring a third tie-breaker;
- total API calls;
- first-inference accuracy;
- automatically accepted accuracy;
- total and overhead latency;
- input/output/total tokens;
- total and overhead estimated cost.

## Live result — 29.07.2026

| Metric | Result |
|---|---:|
| Total cases | 12 |
| API-eligible cases | 11 |
| Accepted | 11 |
| Unsure | 0 |
| Rejected | 1 |
| Not automatically accepted | 1 |
| Cases with repeated inference | 11 |
| Third tie-breakers | 0 |
| Total API calls | 22 |
| Single-inference accuracy | 10/11 (90.91%) |
| Automatically accepted accuracy | 10/11 (90.91%) |
| Single-inference latency | 8,585.097 ms |
| Controlled-inference latency | 16,977.879 ms |
| Latency multiplier | 1.9776× |
| Single-inference estimated cost | $0.00017655 |
| Controlled-inference estimated cost | $0.00035310 |
| Cost multiplier | 2.0× |
| Total tokens | 2,018 |

`D7-N04` was rejected before inference because it contained insufficient text.
This rejection used zero API calls, tokens, and cost.

### Error analysis

`D7-B04` was the only incorrect classification:

- expected: `research`;
- result: `documentation`;
- both responses were valid and identical;
- agreement confidence: `1.0`;
- final status: `ACCEPTED`.

This is a correlated systematic error: redundancy detects instability but
cannot detect two identical wrong answers. Confidence in this experiment means
vote agreement, not calibrated probability of correctness. The frozen case and
gold label remain unchanged. An independent self-check/judge and calibrated
confidence are recorded as post-Day-7 improvements in the shared roadmap.

Cost estimation defaults to the documented `gpt-4o-mini` standard rates:
`$0.15` per million input tokens and `$0.60` per million output tokens. Both
rates are explicit CLI options so recorded experiments can preserve changed
pricing. See the
[official model page](https://developers.openai.com/api/docs/models/gpt-4o-mini).

## Code

- `Scripts/Course/Day7InferenceQuality/confidence_policy.py` — pure constraints,
  response parsing, voting, and acceptance policy;
- `Scripts/Course/Day7InferenceQuality/run_quality_evaluation.py` — live
  inference and metrics;
- `Scripts/Course/Day7InferenceQuality/validate_results.py` — artifact and
  policy-invariant validation;
- `Scripts/Course/Day7InferenceQuality/test_confidence_policy.py` — deterministic
  offline tests.

## Completion criteria

Day 7 is complete when:

1. all offline tests pass;
2. the live runner produces 12 results;
3. the result validator passes;
4. the summary contains rejection, repeated-inference, latency, and cost
   measurements;
5. the user records the short code-and-result video described in
   `video-script.md`.

Further calibration, model ensembles, and production WorkHarness integration
are intentionally deferred to the shared Days 6–10 roadmap.
