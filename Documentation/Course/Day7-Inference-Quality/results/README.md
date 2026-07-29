# Day 7 Results

This directory contains real `gpt-4o-mini` inference artifacts generated on
29.07.2026:

- `inference-results.jsonl`;
- `summary.json`.

The frozen evaluation was run with:

```bash
source .venv-day6/bin/activate
python3 Scripts/Course/Day7InferenceQuality/run_quality_evaluation.py
python3 Scripts/Course/Day7InferenceQuality/validate_results.py
```

Validation result:

```text
Day 7 result validation PASSED
Cases: 12 | Accepted: 11 | Unsure: 0 | Rejected: 1
Repeated inference: 11 | Tiebreakers: 0 | API calls: 22
Latency: 16977.879 ms | Estimated cost: $0.00035310
```

One accepted boundary result was incorrect despite two matching votes. The
complete error analysis is recorded in the parent `README.md`; raw attempts
remain unchanged in `inference-results.jsonl`.
