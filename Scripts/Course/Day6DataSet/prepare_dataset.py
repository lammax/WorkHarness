#!/usr/bin/env python3
"""Build immutable OpenAI-compatible Day 6 JSONL files from the source catalog."""

from __future__ import annotations

import argparse
import hashlib
import json
from collections import Counter
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
DEFAULT_SOURCE = ROOT / "Documentation/Course/Day6-DataSet/source/examples.jsonl"
DEFAULT_OUTPUT = ROOT / "Documentation/Course/Day6-DataSet/data"
DEFAULT_PROVENANCE = ROOT / "Documentation/Course/Day6-DataSet/dataset-provenance.json"
ALLOWED_SPLITS = {"train", "eval"}
ALLOWED_ORIGINS = {"real", "synthetic"}


def load_jsonl(path: Path) -> list[dict]:
    records: list[dict] = []
    with path.open(encoding="utf-8") as handle:
        for line_number, raw_line in enumerate(handle, start=1):
            if not raw_line.strip():
                continue
            try:
                records.append(json.loads(raw_line))
            except json.JSONDecodeError as error:
                raise ValueError(f"{path}:{line_number}: invalid JSON: {error}") from error
    return records


def user_content(record: dict) -> str:
    return next(
        message["content"]
        for message in record["messages"]
        if message["role"] == "user"
    )


def assistant_category(record: dict) -> str:
    content = next(
        message["content"]
        for message in record["messages"]
        if message["role"] == "assistant"
    )
    return json.loads(content)["category"]


def validate_source(records: list[dict]) -> None:
    if len(records) < 50:
        raise ValueError(f"source must contain at least 50 examples; found {len(records)}")

    ids = [record.get("id") for record in records]
    if any(not isinstance(example_id, str) or not example_id for example_id in ids):
        raise ValueError("every source example must have a non-empty string id")
    if len(ids) != len(set(ids)):
        raise ValueError("source example ids must be unique")

    for record in records:
        if record.get("origin") not in ALLOWED_ORIGINS:
            raise ValueError(f"{record['id']}: unsupported origin")
        if record.get("split") not in ALLOWED_SPLITS:
            raise ValueError(f"{record['id']}: unsupported split")
        if not isinstance(record.get("source"), str) or not record["source"].strip():
            raise ValueError(f"{record['id']}: source is required")
        if not isinstance(record.get("group"), str) or not record["group"].strip():
            raise ValueError(f"{record['id']}: group is required")

        messages = record.get("messages")
        if not isinstance(messages, list) or [item.get("role") for item in messages] != [
            "system",
            "user",
            "assistant",
        ]:
            raise ValueError(f"{record['id']}: messages must be system, user, assistant")
        if any(
            not isinstance(item.get("content"), str) or not item["content"].strip()
            for item in messages
        ):
            raise ValueError(f"{record['id']}: message content must not be empty")
        assistant_category(record)

    split_by_group: dict[str, str] = {}
    for record in records:
        existing = split_by_group.setdefault(record["group"], record["split"])
        if existing != record["split"]:
            raise ValueError(
                f"group {record['group']} leaks across train and eval"
            )

    eval_records = [record for record in records if record["split"] == "eval"]
    baseline_records = [record for record in eval_records if record.get("baseline") is True]
    if len(baseline_records) != 10:
        raise ValueError(
            f"exactly 10 eval examples must be marked baseline; found {len(baseline_records)}"
        )


def write_jsonl(path: Path, records: list[dict]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as handle:
        for record in records:
            json.dump(record, handle, ensure_ascii=False, separators=(",", ":"))
            handle.write("\n")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", type=Path, default=DEFAULT_SOURCE)
    parser.add_argument("--output-directory", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--provenance", type=Path, default=DEFAULT_PROVENANCE)
    arguments = parser.parse_args()

    records = load_jsonl(arguments.source)
    validate_source(records)

    upload_records = [{"messages": record["messages"]} for record in records]
    train_records = [
        {"messages": record["messages"]}
        for record in records
        if record["split"] == "train"
    ]
    eval_records = [
        {"messages": record["messages"]}
        for record in records
        if record["split"] == "eval"
    ]
    baseline_records = [
        {"messages": record["messages"]}
        for record in records
        if record["split"] == "eval" and record.get("baseline") is True
    ]

    write_jsonl(arguments.output_directory / "all.jsonl", upload_records)
    write_jsonl(arguments.output_directory / "train.jsonl", train_records)
    write_jsonl(arguments.output_directory / "eval.jsonl", eval_records)
    write_jsonl(arguments.output_directory / "baseline-eval.jsonl", baseline_records)

    provenance = {
        "dataset_version": "1.0.0",
        "task": "WorkHarness software-development task classification",
        "counts": {
            "total": len(records),
            "train": len(train_records),
            "eval": len(eval_records),
            "baseline": len(baseline_records),
            "real": sum(record["origin"] == "real" for record in records),
            "synthetic": sum(record["origin"] == "synthetic" for record in records),
        },
        "category_distribution": dict(
            sorted(Counter(assistant_category(record) for record in records).items())
        ),
        "examples": [
            {
                "id": record["id"],
                "origin": record["origin"],
                "source": record["source"],
                "group": record["group"],
                "split": record["split"],
                "baseline": record.get("baseline", False),
                "category": assistant_category(record),
                "user_sha256": hashlib.sha256(
                    user_content(record).encode("utf-8")
                ).hexdigest(),
            }
            for record in records
        ],
    }
    arguments.provenance.parent.mkdir(parents=True, exist_ok=True)
    arguments.provenance.write_text(
        json.dumps(provenance, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )

    print(
        f"Prepared {len(records)} examples: "
        f"{len(train_records)} train, {len(eval_records)} eval, "
        f"{len(baseline_records)} baseline."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
