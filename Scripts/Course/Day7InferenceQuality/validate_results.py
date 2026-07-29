#!/usr/bin/env python3
"""Validate the real Day 7 inference artifacts and policy invariants."""

from __future__ import annotations

import argparse
import json
from collections import Counter
from pathlib import Path

from confidence_policy import ACCEPTED, REJECTED, UNSURE, decide, parse_vote
from run_quality_evaluation import read_jsonl, validate_cases


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


def close_enough(left: float, right: float, tolerance: float = 1e-9) -> bool:
    return abs(left - right) <= tolerance


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--cases", type=Path, default=DEFAULT_CASES)
    parser.add_argument("--results", type=Path, default=DEFAULT_RESULTS)
    parser.add_argument("--summary", type=Path, default=DEFAULT_SUMMARY)
    arguments = parser.parse_args()

    cases = read_jsonl(arguments.cases)
    validate_cases(cases)
    if not arguments.results.exists() or not arguments.summary.exists():
        raise SystemExit(
            "Day 7 live results are absent. Run run_quality_evaluation.py "
            "with OPENAI_API_KEY first."
        )

    results = read_jsonl(arguments.results)
    summary = json.loads(arguments.summary.read_text(encoding="utf-8"))
    if len(results) != len(cases):
        raise ValueError(f"expected {len(cases)} results; found {len(results)}")
    if [item["id"] for item in results] != [item["id"] for item in cases]:
        raise ValueError("result ids or ordering do not match the frozen cases")

    statuses = Counter()
    api_calls = 0
    tiebreakers = 0
    precheck_rejections = 0
    for result in results:
        status = result.get("status")
        if status not in {ACCEPTED, UNSURE, REJECTED}:
            raise ValueError(f"{result['id']}: invalid status")
        statuses[status] += 1
        attempts = result.get("attempts")
        if not isinstance(attempts, list):
            raise ValueError(f"{result['id']}: attempts must be a list")
        api_calls += len(attempts)

        if not result["input_check"]["accepted"]:
            precheck_rejections += 1
            if status != REJECTED or attempts:
                raise ValueError(
                    f"{result['id']}: precheck rejection must make zero API calls"
                )
            continue

        if len(attempts) not in {2, 3}:
            raise ValueError(f"{result['id']}: expected two or three attempts")
        if len(attempts) == 3:
            tiebreakers += 1
        for expected_number, attempt in enumerate(attempts, start=1):
            if attempt["attempt"] != expected_number:
                raise ValueError(f"{result['id']}: invalid attempt ordering")
            if attempt["latency_ms"] < 0 or attempt["total_tokens"] < 0:
                raise ValueError(f"{result['id']}: invalid usage metrics")
            if attempt["estimated_cost_usd"] < 0:
                raise ValueError(f"{result['id']}: invalid cost")
            reparsed = parse_vote(attempt["raw_response"])
            if reparsed.to_dict() != attempt["vote"]:
                raise ValueError(f"{result['id']}: stored vote does not match response")

        votes = [parse_vote(attempt["raw_response"]) for attempt in attempts]
        initial_decision = decide(votes[:2])
        if len(votes) == 2 and initial_decision.needs_tiebreaker:
            raise ValueError(f"{result['id']}: missing required tie-breaker")
        if len(votes) == 3 and not initial_decision.needs_tiebreaker:
            raise ValueError(f"{result['id']}: unnecessary tie-breaker")
        reconstructed = decide(votes)
        if (
            reconstructed.status != result["status"]
            or reconstructed.category != result["category"]
            or not close_enough(reconstructed.confidence, result["confidence"])
            or reconstructed.reason != result["reason"]
        ):
            raise ValueError(
                f"{result['id']}: stored decision does not match confidence policy"
            )

        if status == ACCEPTED:
            if len(attempts) != 2 or not close_enough(result["confidence"], 1.0):
                raise ValueError(
                    f"{result['id']}: automatic acceptance requires two unanimous votes"
                )
            categories = [item["vote"]["category"] for item in attempts]
            if (
                categories[0] != categories[1]
                or not all(item["vote"]["constraints_passed"] for item in attempts)
            ):
                raise ValueError(f"{result['id']}: accepted votes violate policy")
        elif status == UNSURE:
            if len(attempts) != 3 or not close_enough(
                result["confidence"], 2 / 3
            ):
                raise ValueError(
                    f"{result['id']}: unsure result must be a two-of-three vote"
                )
        elif len(attempts) != 3:
            raise ValueError(
                f"{result['id']}: inference rejection requires three attempts"
            )

    expected_summary_counts = {
        "cases": len(results),
        "accepted": statuses[ACCEPTED],
        "unsure": statuses[UNSURE],
        "rejected": statuses[REJECTED],
        "not_automatically_accepted": statuses[UNSURE] + statuses[REJECTED],
        "precheck_rejections": precheck_rejections,
        "total_api_calls": api_calls,
        "tiebreaker_cases": tiebreakers,
    }
    for key, expected in expected_summary_counts.items():
        if summary.get(key) != expected:
            raise ValueError(
                f"summary {key} is {summary.get(key)!r}; expected {expected!r}"
            )
    if summary.get("repeated_inference_cases") != len(results) - precheck_rejections:
        raise ValueError("every API-eligible case must use redundant inference")

    print("Day 7 result validation PASSED")
    print(
        f"Cases: {len(results)} | Accepted: {statuses[ACCEPTED]} | "
        f"Unsure: {statuses[UNSURE]} | Rejected: {statuses[REJECTED]}"
    )
    print(
        f"Repeated inference: {summary['repeated_inference_cases']} | "
        f"Tiebreakers: {tiebreakers} | API calls: {api_calls}"
    )
    print(
        f"Latency: {summary['controlled_inference_total_latency_ms']:.3f} ms | "
        f"Estimated cost: ${summary['controlled_inference_estimated_cost_usd']:.8f}"
    )
    print("Policy invariants, result ordering, usage, latency, and cost: valid")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
