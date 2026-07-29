# Day 6 — DataSet

Status: complete.

## Task

Fine-tune a classifier for software-development tasks used by WorkHarness.

Input:

- one natural-language development task.

Output:

```json
{"category":"tests"}
```

Allowed categories:

- `bug`
- `feature`
- `refactoring`
- `tests`
- `documentation`
- `research`
- `security`

The classifier category is a domain fact. WorkHarness may later map it to an
agent workflow profile, but that production integration is outside Day 6.

## Dataset

Dataset version: `1.0.0`.

| Artifact | Examples | Purpose |
|---|---:|---|
| `source/examples.jsonl` | 60 | Authoring source with provenance metadata |
| `data/all.jsonl` | 60 | Complete OpenAI-compatible dataset |
| `data/train.jsonl` | 48 | Frozen 80% training split |
| `data/eval.jsonl` | 12 | Frozen 20% evaluation split |
| `data/baseline-eval.jsonl` | 10 | Frozen baseline subset of eval |

Origin:

- real project examples: 15 (25%);
- AI-generated examples: 45 (75%).

The final upload files contain only a `messages` array. Every example has
exactly one non-empty `system`, `user` and `assistant` message. Provenance is
kept separately in `dataset-provenance.json` so course evidence does not add
unsupported metadata to the fine-tuning files.

The real examples come from repository commits, existing Day 5 tasks and actual
course Research/Coverage questions. The project owner reviewed and approved all
15 real examples on 29.07.2026; the signed checklist is
`real-example-review.md`.

## Prepare and validate

From the WorkHarness repository root:

```bash
python3 Scripts/Course/Day6DataSet/prepare_dataset.py
python3 Scripts/Course/Day6DataSet/validate_dataset.py
```

Expected result:

```text
Dataset validation PASSED
Total: 60 | Train: 48 | Eval: 12 | Baseline: 10
Real: 15 (25%) | Synthetic: 45 (75%)
```

The preparation command is deterministic. It reconstructs all derived JSONL
files and `dataset-provenance.json` from `source/examples.jsonl`.

## Human review

Before running the baseline, the user must inspect every record whose
`origin` is `real` and confirm:

1. the task is based on genuine WorkHarness or WorkHarnessMobile work;
2. it contains no secret, token, credential or personal data;
3. its assistant category is the intended gold label;
4. its wording does not reveal private infrastructure.

Useful command:

```bash
python3 - <<'PY'
import json
from pathlib import Path

path = Path("Documentation/Course/Day6-DataSet/source/examples.jsonl")
for line in path.read_text(encoding="utf-8").splitlines():
    item = json.loads(line)
    if item["origin"] == "real":
        user = next(message["content"] for message in item["messages"] if message["role"] == "user")
        assistant = next(message["content"] for message in item["messages"] if message["role"] == "assistant")
        print(f'{item["id"]}: {item["source"]}\n  {user}\n  {assistant}\n')
PY
```

## Baseline

Install the official OpenAI Python client in a local virtual environment:

```bash
python3 -m venv .venv-day6
source .venv-day6/bin/activate
python3 -m pip install -r Scripts/Course/Day6DataSet/requirements.txt
```

Set the API key locally. Never paste it into the dataset, reports, source code
or Git:

```bash
export OPENAI_API_KEY="your-key"
```

Run the frozen ten-example baseline:

```bash
python3 Scripts/Course/Day6DataSet/run_baseline.py
```

The script uses `gpt-4o-mini`, temperature `0`, and saves:

- `baseline/baseline-results.jsonl`;
- `baseline/baseline-summary.json`.

The baseline was run on 29.07.2026 under the user's OpenAI account. It produced
ten real API responses with these results:

- category accuracy: `9/10` (`0.9`);
- valid JSON: `10/10` (`1.0`);
- allowed category: `10/10` (`1.0`);
- exact format: `9/10` (`0.9`).

The only mismatch was the Keychain/token-storage task: the gold category is
`security`, while the base model returned `feature`. The frozen input and gold
label were not changed after observing the result.

The script never prints or stores the API key.

## Fine-tuning client

The client is prepared but must not be executed during Day 6.

Safe dry-run:

```bash
python3 Scripts/Course/Day6DataSet/fine_tuning_client.py
```

Dry-run performs no network request, upload, job creation or polling.

The future paid path additionally requires both `--execute` and the explicit
confirmation phrase printed by `--help`. When enabled, the client:

1. uploads train and eval with `purpose=fine-tune`;
2. creates a supervised fine-tuning job;
3. polls the job to a terminal status;
4. saves the job metadata.

Do not run the paid path until a later course day explicitly requires it.

## Submission evidence

Capture:

1. the validator success output;
2. `wc -l` output for all, train, eval and baseline JSONL;
3. several representative JSONL lines showing all three roles;
4. provenance counts showing 15 real examples;
5. the ten baseline responses and summary;
6. `evaluation-criteria.md`;
7. fine-tuning client dry-run proving that no job was launched.

## Official API references

- [OpenAI Fine-tuning API](https://platform.openai.com/docs/api-reference/fine-tuning/list-checkpoints)
- [OpenAI Files API](https://platform.openai.com/docs/api-reference/files)
