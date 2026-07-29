# Day 6 Evaluation Criteria

Dataset version: `1.0.0`.

Evaluation set: `data/eval.jsonl`.

Frozen baseline subset: `data/baseline-eval.jsonl`.

Baseline model: `gpt-4o-mini`.

Generation parameters:

- temperature: `0`;
- maximum output tokens: `40`;
- no fine-tuning;
- no structured-output enforcement;
- the same system prompt used by the dataset.

Structured-output enforcement is intentionally disabled for the baseline
because format compliance is one of the measured outcomes.

## Primary metric

Category accuracy:

```text
correct parsed category / 10 baseline examples
```

The parsed category must equal the gold assistant category. Different
capitalization, synonyms and explanatory prose do not count as a correct
category unless the response also contains the required JSON payload.

## Format metrics

1. Valid JSON rate — the entire response parses as JSON.
2. Allowed-category rate — the parsed category belongs to the seven-label
   vocabulary.
3. Exact-format rate — the response is exactly one compact object such as
   `{"category":"bug"}`, with no Markdown or explanation.

## Error analysis

For every incorrect response record:

- expected category;
- parsed category, if any;
- raw model response;
- whether the failure was classification or formatting;
- likely confused category.

Later course days may add a confusion matrix and per-class recall. The frozen
eval and baseline inputs must not be rewritten after seeing model responses.

## Definition of improvement

A later fine-tuned model is better only when:

1. category accuracy is higher than the frozen baseline;
2. valid JSON rate does not decrease;
3. allowed-category rate does not decrease;
4. it uses the same ten baseline inputs and the same system prompt;
5. no eval example was copied into train.

Preferred target:

- category accuracy: at least 9/10;
- valid JSON: 10/10;
- allowed category: 10/10;
- exact format: 10/10.

The target is an evaluation goal, not a claim about the current baseline.

## Recorded baseline — 29.07.2026

| Metric | Result |
|---|---:|
| Category accuracy | 9/10 (0.9) |
| Valid JSON rate | 10/10 (1.0) |
| Allowed-category rate | 10/10 (1.0) |
| Exact-format rate | 9/10 (0.9) |

The only mismatch was baseline example 5:

- expected: `{"category":"security"}`;
- response: `{"category":"feature"}`;
- failure type: classification, not formatting;
- likely confusion: the model treated a security-motivated Keychain migration
  as implementation of a new feature.

The baseline therefore already meets the preferred category-accuracy target.
A fine-tuned model must improve accuracy above `9/10` while preserving both
JSON and allowed-category rates; matching `9/10` alone is not an improvement.
