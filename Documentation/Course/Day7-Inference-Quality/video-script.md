# Day 7 Video Script

Target duration: 2–3 minutes.

Do not show the API key, shell history containing the key, billing details, or
other credentials.

## 1. Introduce the task — 15 seconds

Say:

> This is a quality-control layer for the WorkHarness development-task
> classifier. Fine-tuning is not used. A category is applied automatically only
> when confidence is high.

Show:

- `Documentation/Course/Day7-Inference-Quality/README.md`.

## 2. Show both approaches — 35 seconds

Open:

- `Scripts/Course/Day7InferenceQuality/confidence_policy.py`.

Point out:

1. constraint checks for canonical JSON and the seven allowed categories;
2. two matching votes produce `ACCEPTED` with confidence `1.0`;
3. disagreement triggers a third inference;
4. a `2/3` vote produces `UNSURE`, not silent acceptance.

## 3. Show the test mix — 20 seconds

Open:

- `Documentation/Course/Day7-Inference-Quality/test-cases.jsonl`.

Show at least one `correct`, one `boundary`, and one `noisy` record. Mention
that the frozen set has four cases in each group.

## 4. Run checks — 45 seconds

In Terminal:

```bash
source .venv-day6/bin/activate
python3 -m unittest discover \
  -s Scripts/Course/Day7InferenceQuality \
  -p 'test_*.py' \
  -v
python3 Scripts/Course/Day7InferenceQuality/run_quality_evaluation.py
python3 Scripts/Course/Day7InferenceQuality/validate_results.py
```

Show:

- unit tests passing;
- per-case status, confidence, and API call count;
- `Day 7 result validation PASSED`.

## 5. Show measured outcome — 40 seconds

Open:

- `Documentation/Course/Day7-Inference-Quality/results/summary.json`.

Read out:

- accepted / unsure / rejected;
- not automatically accepted;
- repeated-inference and tie-breaker counts;
- single versus controlled latency;
- single versus controlled estimated cost;
- automatically accepted accuracy.

Finish with:

> The system exposes uncertainty and refuses to silently apply ambiguous or
> constraint-violating output.
