#!/usr/bin/env python3
"""Validate Day 6 source, train/eval split, provenance, and upload format."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
from collections import Counter
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
DEFAULT_DATASET_ROOT = ROOT / "Documentation/Course/Day6-DataSet"
ALLOWED_CATEGORIES = {
    "bug",
    "feature",
    "refactoring",
    "tests",
    "documentation",
    "research",
    "security",
}
EXPECTED_ROLES = ["system", "user", "assistant"]


def read_jsonl(path: Path) -> list[dict]:
    records: list[dict] = []
    with path.open(encoding="utf-8") as handle:
        for line_number, raw_line in enumerate(handle, start=1):
            if not raw_line.strip():
                raise ValueError(f"{path}:{line_number}: empty lines are not allowed")
            try:
                records.append(json.loads(raw_line))
            except json.JSONDecodeError as error:
                raise ValueError(f"{path}:{line_number}: invalid JSON: {error}") from error
    return records


def normalized(text: str) -> str:
    return re.sub(r"\s+", " ", text.strip().lower())


def messages(record: dict, location: str) -> list[dict]:
    if set(record) != {"messages"}:
        raise ValueError(f"{location}: upload record must contain only messages")
    value = record["messages"]
    if not isinstance(value, list) or len(value) != 3:
        raise ValueError(f"{location}: messages must contain exactly three items")
    if [message.get("role") for message in value] != EXPECTED_ROLES:
        raise ValueError(f"{location}: roles must be system, user, assistant")
    for message in value:
        content = message.get("content")
        if not isinstance(content, str) or not content.strip():
            raise ValueError(f"{location}: content must be a non-empty string")
    return value


def category_for(record: dict, location: str) -> str:
    assistant = messages(record, location)[2]["content"]
    try:
        payload = json.loads(assistant)
    except json.JSONDecodeError as error:
        raise ValueError(f"{location}: assistant content is not JSON") from error
    if set(payload) != {"category"} or payload["category"] not in ALLOWED_CATEGORIES:
        raise ValueError(f"{location}: invalid assistant category payload")
    canonical = json.dumps(payload, separators=(",", ":"))
    if assistant != canonical:
        raise ValueError(f"{location}: assistant JSON must use canonical compact format")
    return payload["category"]


def user_for(record: dict, location: str) -> str:
    value = messages(record, location)[1]["content"]
    if not 20 <= len(value) <= 2_000:
        raise ValueError(f"{location}: user content length is outside 20...2000")
    return value


def validate_file(path: Path) -> list[dict]:
    records = read_jsonl(path)
    seen: set[str] = set()
    for index, record in enumerate(records, start=1):
        location = f"{path}:{index}"
        category_for(record, location)
        normalized_user = normalized(user_for(record, location))
        if normalized_user in seen:
            raise ValueError(f"{location}: duplicate normalized user content")
        seen.add(normalized_user)
    return records


def hashes(records: list[dict], path: Path) -> set[str]:
    return {
        hashlib.sha256(user_for(record, str(path)).encode("utf-8")).hexdigest()
        for record in records
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--dataset-root", type=Path, default=DEFAULT_DATASET_ROOT)
    arguments = parser.parse_args()

    data = arguments.dataset_root / "data"
    all_records = validate_file(data / "all.jsonl")
    train_records = validate_file(data / "train.jsonl")
    eval_records = validate_file(data / "eval.jsonl")
    baseline_records = validate_file(data / "baseline-eval.jsonl")

    if len(all_records) < 50:
        raise ValueError("dataset must contain at least 50 examples")
    if (len(train_records), len(eval_records)) != (48, 12):
        raise ValueError("expected an exact 48/12 train/eval split")
    if len(baseline_records) != 10:
        raise ValueError("baseline-eval.jsonl must contain exactly 10 examples")

    train_hashes = hashes(train_records, data / "train.jsonl")
    eval_hashes = hashes(eval_records, data / "eval.jsonl")
    baseline_hashes = hashes(baseline_records, data / "baseline-eval.jsonl")
    if train_hashes & eval_hashes:
        raise ValueError("train and eval overlap")
    if not baseline_hashes <= eval_hashes:
        raise ValueError("baseline examples must be a subset of eval")
    if train_hashes | eval_hashes != hashes(all_records, data / "all.jsonl"):
        raise ValueError("train and eval do not reconstruct all.jsonl")

    provenance_path = arguments.dataset_root / "dataset-provenance.json"
    provenance = json.loads(provenance_path.read_text(encoding="utf-8"))
    counts = provenance.get("counts", {})
    expected_counts = {
        "total": 60,
        "train": 48,
        "eval": 12,
        "baseline": 10,
        "real": 15,
        "synthetic": 45,
    }
    if counts != expected_counts:
        raise ValueError(f"unexpected provenance counts: {counts}")
    if counts["real"] / counts["total"] < 0.20:
        raise ValueError("real-data share is below 20%")
    provenance_examples = provenance.get("examples")
    if not isinstance(provenance_examples, list) or len(provenance_examples) != 60:
        raise ValueError("provenance must describe every dataset example")
    if {item.get("user_sha256") for item in provenance_examples} != hashes(
        all_records, data / "all.jsonl"
    ):
        raise ValueError("provenance hashes do not match the complete dataset")
    if Counter(item.get("origin") for item in provenance_examples) != {
        "real": 15,
        "synthetic": 45,
    }:
        raise ValueError("provenance origin counts do not match the declared counts")
    if Counter(item.get("split") for item in provenance_examples) != {
        "train": 48,
        "eval": 12,
    }:
        raise ValueError("provenance split counts do not match the JSONL files")
    provenance_baseline_hashes = {
        item["user_sha256"]
        for item in provenance_examples
        if item.get("baseline") is True
    }
    if provenance_baseline_hashes != baseline_hashes:
        raise ValueError("provenance baseline selection does not match baseline-eval")

    categories = Counter(
        category_for(record, f"all:{index}")
        for index, record in enumerate(all_records, start=1)
    )
    if set(categories) != ALLOWED_CATEGORIES:
        raise ValueError("every allowed category must be represented")

    print("Dataset validation PASSED")
    print("Total: 60 | Train: 48 | Eval: 12 | Baseline: 10")
    print("Real: 15 (25%) | Synthetic: 45 (75%)")
    print(
        "Categories: "
        + ", ".join(f"{category}={categories[category]}" for category in sorted(categories))
    )
    print("JSONL, roles, content, labels, duplicates, split, and provenance: valid")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
