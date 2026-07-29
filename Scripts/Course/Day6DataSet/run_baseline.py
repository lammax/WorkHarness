#!/usr/bin/env python3
"""Run the frozen ten-example Day 6 baseline through gpt-4o-mini."""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
DEFAULT_INPUT = ROOT / "Documentation/Course/Day6-DataSet/data/baseline-eval.jsonl"
DEFAULT_OUTPUT = ROOT / "Documentation/Course/Day6-DataSet/baseline/baseline-results.jsonl"
DEFAULT_SUMMARY = ROOT / "Documentation/Course/Day6-DataSet/baseline/baseline-summary.json"


def load_jsonl(path: Path) -> list[dict]:
    return [
        json.loads(line)
        for line in path.read_text(encoding="utf-8").splitlines()
        if line.strip()
    ]


def parse_category(content: str) -> tuple[str | None, bool]:
    try:
        payload = json.loads(content)
    except json.JSONDecodeError:
        return None, False
    if set(payload) != {"category"} or not isinstance(payload["category"], str):
        return None, True
    return payload["category"], True


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", type=Path, default=DEFAULT_INPUT)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--summary", type=Path, default=DEFAULT_SUMMARY)
    parser.add_argument("--model", default="gpt-4o-mini")
    arguments = parser.parse_args()

    if not os.environ.get("OPENAI_API_KEY"):
        raise SystemExit(
            "OPENAI_API_KEY is not set. Export it locally; never commit the key."
        )

    from openai import OpenAI

    examples = load_jsonl(arguments.input)
    if len(examples) != 10:
        raise SystemExit(f"Expected exactly 10 baseline examples; found {len(examples)}")

    client = OpenAI()
    results: list[dict] = []
    for index, example in enumerate(examples, start=1):
        source_messages = example["messages"]
        expected_content = source_messages[2]["content"]
        expected_category = json.loads(expected_content)["category"]
        response = client.chat.completions.create(
            model=arguments.model,
            messages=source_messages[:2],
            temperature=0,
            max_tokens=40,
        )
        actual_content = response.choices[0].message.content or ""
        actual_category, valid_json = parse_category(actual_content)
        results.append(
            {
                "example": index,
                "model": arguments.model,
                "user": source_messages[1]["content"],
                "expected": expected_content,
                "response": actual_content,
                "parsed_category": actual_category,
                "valid_json": valid_json,
                "allowed_category": actual_category
                in {
                    "bug",
                    "feature",
                    "refactoring",
                    "tests",
                    "documentation",
                    "research",
                    "security",
                },
                "exact_format": actual_content == expected_content
                if actual_category == expected_category
                else False,
                "correct_category": actual_category == expected_category,
                "response_id": response.id,
            }
        )

    arguments.output.parent.mkdir(parents=True, exist_ok=True)
    with arguments.output.open("w", encoding="utf-8") as handle:
        for result in results:
            json.dump(result, handle, ensure_ascii=False, separators=(",", ":"))
            handle.write("\n")

    total = len(results)
    summary = {
        "model": arguments.model,
        "examples": total,
        "category_accuracy": sum(item["correct_category"] for item in results) / total,
        "valid_json_rate": sum(item["valid_json"] for item in results) / total,
        "allowed_category_rate": sum(item["allowed_category"] for item in results) / total,
        "exact_format_rate": sum(item["exact_format"] for item in results) / total,
    }
    arguments.summary.write_text(
        json.dumps(summary, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(json.dumps(summary, ensure_ascii=False, indent=2))
    print(f"Saved baseline responses to {arguments.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
