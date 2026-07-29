#!/usr/bin/env python3
"""Run the Day 7 redundant classifier and record quality-control metrics."""

from __future__ import annotations

import argparse
import json
import os
import time
from collections import Counter
from pathlib import Path

from confidence_policy import ACCEPTED, REJECTED, UNSURE, decide, parse_vote, validate_input


ROOT = Path(__file__).resolve().parents[3]
DEFAULT_CASES = (
    ROOT / "Documentation/Course/Day7-Inference-Quality/test-cases.jsonl"
)
DEFAULT_RESULTS = (
    ROOT
    / "Documentation/Course/Day7-Inference-Quality/results/inference-results.jsonl"
)
DEFAULT_SUMMARY = (
    ROOT / "Documentation/Course/Day7-Inference-Quality/results/summary.json"
)
SYSTEM_PROMPT = (
    "You classify software-development tasks for WorkHarness. "
    "Return exactly one compact JSON object and no other text: "
    '{"category":"<label>"}. '
    "Allowed labels: bug, feature, refactoring, tests, documentation, "
    "research, security. Choose the task's primary intent."
)


def read_jsonl(path: Path) -> list[dict]:
    records: list[dict] = []
    with path.open(encoding="utf-8") as handle:
        for line_number, raw_line in enumerate(handle, start=1):
            if not raw_line.strip():
                raise ValueError(f"{path}:{line_number}: empty line")
            try:
                records.append(json.loads(raw_line))
            except json.JSONDecodeError as error:
                raise ValueError(
                    f"{path}:{line_number}: invalid JSON: {error}"
                ) from error
    return records


def validate_cases(cases: list[dict]) -> None:
    expected_groups = {"correct": 4, "boundary": 4, "noisy": 4}
    groups = Counter()
    identifiers: set[str] = set()
    allowed_fields = {
        "id",
        "group",
        "input",
        "expected_category",
        "expected_precheck",
    }
    for index, case in enumerate(cases, start=1):
        location = f"case {index}"
        if set(case) != allowed_fields:
            raise ValueError(f"{location}: unexpected fields")
        identifier = case["id"]
        if not isinstance(identifier, str) or identifier in identifiers:
            raise ValueError(f"{location}: id must be a unique string")
        identifiers.add(identifier)
        group = case["group"]
        if group not in expected_groups:
            raise ValueError(f"{location}: invalid group")
        groups[group] += 1
        expected_category = case["expected_category"]
        if expected_category is not None and expected_category not in {
            "bug",
            "feature",
            "refactoring",
            "tests",
            "documentation",
            "research",
            "security",
        }:
            raise ValueError(f"{location}: invalid expected category")
        check = validate_input(case["input"])
        expected_precheck = "PASS" if check.accepted else "REJECT"
        if case["expected_precheck"] != expected_precheck:
            raise ValueError(
                f"{location}: expected precheck {case['expected_precheck']} "
                f"but policy produced {expected_precheck}"
            )
        if not check.accepted and expected_category is not None:
            raise ValueError(f"{location}: rejected input cannot have a gold category")
    if dict(groups) != expected_groups:
        raise ValueError(f"expected four cases per group; found {dict(groups)}")


def estimated_cost(
    prompt_tokens: int,
    completion_tokens: int,
    input_price_per_million: float,
    output_price_per_million: float,
) -> float:
    return (
        prompt_tokens * input_price_per_million
        + completion_tokens * output_price_per_million
    ) / 1_000_000


def perform_attempt(
    client: object,
    *,
    attempt_number: int,
    case_input: str,
    model: str,
    temperature: float,
    max_tokens: int,
    input_price_per_million: float,
    output_price_per_million: float,
) -> tuple[dict, object]:
    started = time.perf_counter()
    response = client.chat.completions.create(
        model=model,
        messages=[
            {"role": "system", "content": SYSTEM_PROMPT},
            {"role": "user", "content": case_input},
        ],
        temperature=temperature,
        max_tokens=max_tokens,
    )
    latency_ms = (time.perf_counter() - started) * 1_000
    raw = response.choices[0].message.content or ""
    vote = parse_vote(raw)
    usage = response.usage
    prompt_tokens = int(usage.prompt_tokens or 0)
    completion_tokens = int(usage.completion_tokens or 0)
    total_tokens = int(usage.total_tokens or prompt_tokens + completion_tokens)
    attempt = {
        "attempt": attempt_number,
        "response_id": response.id,
        "raw_response": raw,
        "vote": vote.to_dict(),
        "latency_ms": round(latency_ms, 3),
        "prompt_tokens": prompt_tokens,
        "completion_tokens": completion_tokens,
        "total_tokens": total_tokens,
        "estimated_cost_usd": estimated_cost(
            prompt_tokens,
            completion_tokens,
            input_price_per_million,
            output_price_per_million,
        ),
    }
    return attempt, vote


def aggregate_summary(
    results: list[dict],
    *,
    model: str,
    temperature: float,
    input_price_per_million: float,
    output_price_per_million: float,
) -> dict:
    inferred = [item for item in results if item["attempts"]]
    accepted = [item for item in results if item["status"] == ACCEPTED]
    unsure = [item for item in results if item["status"] == UNSURE]
    rejected = [item for item in results if item["status"] == REJECTED]
    first_attempts = [item["attempts"][0] for item in inferred]
    attempts = [attempt for item in inferred for attempt in item["attempts"]]

    first_correct = [
        item["attempts"][0]["vote"]["category"] == item["expected_category"]
        for item in inferred
        if item["attempts"][0]["vote"]["constraints_passed"]
        and item["expected_category"] is not None
    ]
    accepted_labeled = [
        item for item in accepted if item["expected_category"] is not None
    ]
    decided_labeled = [
        item
        for item in results
        if item["category"] is not None and item["expected_category"] is not None
    ]

    single_latency = sum(item["latency_ms"] for item in first_attempts)
    controlled_latency = sum(item["latency_ms"] for item in attempts)
    single_cost = sum(item["estimated_cost_usd"] for item in first_attempts)
    controlled_cost = sum(item["estimated_cost_usd"] for item in attempts)
    total_prompt_tokens = sum(item["prompt_tokens"] for item in attempts)
    total_completion_tokens = sum(item["completion_tokens"] for item in attempts)

    return {
        "model": model,
        "temperature": temperature,
        "input_price_per_million_usd": input_price_per_million,
        "output_price_per_million_usd": output_price_per_million,
        "cases": len(results),
        "groups": dict(Counter(item["group"] for item in results)),
        "precheck_rejections": sum(not item["input_check"]["accepted"] for item in results),
        "inference_cases": len(inferred),
        "accepted": len(accepted),
        "unsure": len(unsure),
        "rejected": len(rejected),
        "not_automatically_accepted": len(unsure) + len(rejected),
        "repeated_inference_cases": sum(len(item["attempts"]) >= 2 for item in inferred),
        "tiebreaker_cases": sum(len(item["attempts"]) == 3 for item in inferred),
        "total_api_calls": len(attempts),
        "single_inference_accuracy": (
            sum(first_correct) / len(first_correct) if first_correct else None
        ),
        "automatically_accepted_accuracy": (
            sum(item["correct_category"] is True for item in accepted_labeled)
            / len(accepted_labeled)
            if accepted_labeled
            else None
        ),
        "decided_category_accuracy": (
            sum(item["correct_category"] is True for item in decided_labeled)
            / len(decided_labeled)
            if decided_labeled
            else None
        ),
        "single_inference_total_latency_ms": round(single_latency, 3),
        "controlled_inference_total_latency_ms": round(controlled_latency, 3),
        "latency_overhead_ms": round(controlled_latency - single_latency, 3),
        "latency_multiplier": (
            controlled_latency / single_latency if single_latency else None
        ),
        "single_inference_estimated_cost_usd": single_cost,
        "controlled_inference_estimated_cost_usd": controlled_cost,
        "cost_overhead_usd": controlled_cost - single_cost,
        "cost_multiplier": controlled_cost / single_cost if single_cost else None,
        "prompt_tokens": total_prompt_tokens,
        "completion_tokens": total_completion_tokens,
        "total_tokens": total_prompt_tokens + total_completion_tokens,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--cases", type=Path, default=DEFAULT_CASES)
    parser.add_argument("--output", type=Path, default=DEFAULT_RESULTS)
    parser.add_argument("--summary", type=Path, default=DEFAULT_SUMMARY)
    parser.add_argument("--model", default="gpt-4o-mini")
    parser.add_argument("--temperature", type=float, default=0.2)
    parser.add_argument("--max-tokens", type=int, default=40)
    parser.add_argument("--input-price-per-million", type=float, default=0.15)
    parser.add_argument("--output-price-per-million", type=float, default=0.60)
    parser.add_argument("--dry-run", action="store_true")
    arguments = parser.parse_args()

    cases = read_jsonl(arguments.cases)
    validate_cases(cases)
    if arguments.dry_run:
        inference_cases = sum(validate_input(case["input"]).accepted for case in cases)
        print("Day 7 dry-run PASSED")
        print(f"Cases: {len(cases)} | API-eligible: {inference_cases}")
        print(
            f"Planned API calls: {inference_cases * 2} minimum, "
            f"{inference_cases * 3} maximum"
        )
        print("No network request or cost was created.")
        return 0

    if not os.environ.get("OPENAI_API_KEY"):
        raise SystemExit(
            "OPENAI_API_KEY is not set. Export it locally; never commit the key."
        )

    from openai import OpenAI

    client = OpenAI()
    results: list[dict] = []
    for case_index, case in enumerate(cases, start=1):
        input_check = validate_input(case["input"])
        if not input_check.accepted:
            result = {
                **case,
                "input_check": input_check.to_dict(),
                "status": REJECTED,
                "category": None,
                "confidence": 0.0,
                "reason": "input_constraints_failed",
                "correct_category": None,
                "expected_rejection_met": case["expected_category"] is None,
                "attempts": [],
                "total_latency_ms": 0.0,
                "total_tokens": 0,
                "estimated_cost_usd": 0.0,
            }
            results.append(result)
            print(f"[{case_index:02d}/{len(cases)}] {case['id']}: REJECTED precheck")
            continue

        attempts: list[dict] = []
        votes: list[object] = []
        for attempt_number in (1, 2):
            attempt, vote = perform_attempt(
                client,
                attempt_number=attempt_number,
                case_input=case["input"],
                model=arguments.model,
                temperature=arguments.temperature,
                max_tokens=arguments.max_tokens,
                input_price_per_million=arguments.input_price_per_million,
                output_price_per_million=arguments.output_price_per_million,
            )
            attempts.append(attempt)
            votes.append(vote)

        decision = decide(votes)
        if decision.needs_tiebreaker:
            attempt, vote = perform_attempt(
                client,
                attempt_number=3,
                case_input=case["input"],
                model=arguments.model,
                temperature=arguments.temperature,
                max_tokens=arguments.max_tokens,
                input_price_per_million=arguments.input_price_per_million,
                output_price_per_million=arguments.output_price_per_million,
            )
            attempts.append(attempt)
            votes.append(vote)
            decision = decide(votes)

        total_latency = sum(item["latency_ms"] for item in attempts)
        total_tokens = sum(item["total_tokens"] for item in attempts)
        total_cost = sum(item["estimated_cost_usd"] for item in attempts)
        result = {
            **case,
            "input_check": input_check.to_dict(),
            "status": decision.status,
            "category": decision.category,
            "confidence": decision.confidence,
            "reason": decision.reason,
            "correct_category": (
                decision.category == case["expected_category"]
                if decision.category is not None
                and case["expected_category"] is not None
                else None
            ),
            "expected_rejection_met": None,
            "attempts": attempts,
            "total_latency_ms": round(total_latency, 3),
            "total_tokens": total_tokens,
            "estimated_cost_usd": total_cost,
        }
        results.append(result)
        print(
            f"[{case_index:02d}/{len(cases)}] {case['id']}: "
            f"{decision.status} category={decision.category} "
            f"confidence={decision.confidence:.3f} calls={len(attempts)}"
        )

    summary = aggregate_summary(
        results,
        model=arguments.model,
        temperature=arguments.temperature,
        input_price_per_million=arguments.input_price_per_million,
        output_price_per_million=arguments.output_price_per_million,
    )
    arguments.output.parent.mkdir(parents=True, exist_ok=True)
    with arguments.output.open("w", encoding="utf-8") as handle:
        for result in results:
            json.dump(result, handle, ensure_ascii=False, separators=(",", ":"))
            handle.write("\n")
    arguments.summary.write_text(
        json.dumps(summary, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(json.dumps(summary, ensure_ascii=False, indent=2))
    print(f"Saved inference results to {arguments.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
