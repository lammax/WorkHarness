#!/usr/bin/env python3
"""Upload Day 6 files, create a fine-tuning job, and poll it when explicitly enabled."""

from __future__ import annotations

import argparse
import json
import os
import time
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
DEFAULT_TRAIN = ROOT / "Documentation/Course/Day6-DataSet/data/train.jsonl"
DEFAULT_EVAL = ROOT / "Documentation/Course/Day6-DataSet/data/eval.jsonl"
DEFAULT_RESULT = ROOT / "Documentation/Course/Day6-DataSet/fine-tuning-job.json"
CONFIRMATION = "I_UNDERSTAND_THIS_CREATES_COSTS"
TERMINAL_STATUSES = {"succeeded", "failed", "cancelled"}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--train", type=Path, default=DEFAULT_TRAIN)
    parser.add_argument("--eval", type=Path, default=DEFAULT_EVAL)
    parser.add_argument("--model", default="gpt-4o-mini-2024-07-18")
    parser.add_argument("--suffix", default="workharness-task-category-v1")
    parser.add_argument("--poll-seconds", type=int, default=30)
    parser.add_argument("--result", type=Path, default=DEFAULT_RESULT)
    parser.add_argument("--execute", action="store_true")
    parser.add_argument("--confirm-start-job")
    arguments = parser.parse_args()

    plan = {
        "mode": "execute" if arguments.execute else "dry-run",
        "train": str(arguments.train),
        "validation": str(arguments.eval),
        "model": arguments.model,
        "suffix": arguments.suffix,
        "steps": [
            "upload train with purpose=fine-tune",
            "upload eval with purpose=fine-tune",
            "create supervised fine-tuning job",
            "poll job until terminal status",
            f"save job metadata to {arguments.result}",
        ],
    }
    print(json.dumps(plan, ensure_ascii=False, indent=2))
    if not arguments.execute:
        print("Dry-run only. No network request, upload, job, or cost was created.")
        return 0

    if arguments.confirm_start_job != CONFIRMATION:
        raise SystemExit(
            "Refusing to create a paid job. Pass "
            f"--confirm-start-job {CONFIRMATION}"
        )
    if not os.environ.get("OPENAI_API_KEY"):
        raise SystemExit(
            "OPENAI_API_KEY is not set. Export it locally; never commit the key."
        )

    from openai import OpenAI

    client = OpenAI()
    with arguments.train.open("rb") as train_handle:
        train_file = client.files.create(file=train_handle, purpose="fine-tune")
    with arguments.eval.open("rb") as eval_handle:
        eval_file = client.files.create(file=eval_handle, purpose="fine-tune")

    job = client.fine_tuning.jobs.create(
        training_file=train_file.id,
        validation_file=eval_file.id,
        model=arguments.model,
        suffix=arguments.suffix,
        method={"type": "supervised"},
    )
    print(f"Created fine-tuning job {job.id} with status {job.status}")

    while job.status not in TERMINAL_STATUSES:
        time.sleep(arguments.poll_seconds)
        job = client.fine_tuning.jobs.retrieve(job.id)
        print(f"{job.id}: {job.status}")

    payload = job.model_dump(mode="json")
    arguments.result.parent.mkdir(parents=True, exist_ok=True)
    arguments.result.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(f"Final status: {job.status}")
    print(f"Saved metadata to {arguments.result}")
    return 0 if job.status == "succeeded" else 1


if __name__ == "__main__":
    raise SystemExit(main())
