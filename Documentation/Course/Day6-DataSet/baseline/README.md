# Baseline Output

This directory contains the real `gpt-4o-mini` baseline artifacts generated on
29.07.2026:

- `baseline-results.jsonl`;
- `baseline-summary.json`.

The frozen baseline was run with:

```bash
python3 Scripts/Course/Day6DataSet/run_baseline.py
```

Result:

- category accuracy: `9/10`;
- valid JSON: `10/10`;
- allowed category: `10/10`;
- exact format: `9/10`.

Example 5 was the only classification error. The model categorized secure
bearer-token storage in Keychain as `feature`; the gold category is `security`.
The raw responses and expected labels remain in `baseline-results.jsonl`.
