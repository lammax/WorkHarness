#!/usr/bin/env python3
"""Offline unit tests for Day 7 confidence and constraint behavior."""

from __future__ import annotations

import unittest

from confidence_policy import ACCEPTED, REJECTED, UNSURE, decide, parse_vote, validate_input


class InputConstraintTests(unittest.TestCase):
    def test_accepts_actionable_text(self) -> None:
        result = validate_input("Fix the crash in the Runs screen.")
        self.assertTrue(result.accepted)
        self.assertEqual(result.reasons, ())

    def test_rejects_empty_or_punctuation_only_text(self) -> None:
        self.assertFalse(validate_input("   ").accepted)
        self.assertFalse(validate_input("### ??? 123").accepted)

    def test_rejects_oversized_text(self) -> None:
        result = validate_input("a" * 2_001)
        self.assertFalse(result.accepted)
        self.assertIn("input_exceeds_2000_characters", result.reasons)


class ResponseConstraintTests(unittest.TestCase):
    def test_accepts_only_canonical_allowed_payload(self) -> None:
        vote = parse_vote('{"category":"bug"}')
        self.assertTrue(vote.constraints_passed)
        self.assertEqual(vote.category, "bug")

    def test_rejects_markdown_extra_fields_and_unknown_categories(self) -> None:
        self.assertFalse(parse_vote('```json\n{"category":"bug"}\n```').constraints_passed)
        self.assertFalse(
            parse_vote('{"category":"bug","confidence":0.9}').constraints_passed
        )
        self.assertFalse(parse_vote('{"category":"other"}').constraints_passed)

    def test_rejects_noncanonical_whitespace(self) -> None:
        vote = parse_vote('{"category": "bug"}')
        self.assertTrue(vote.allowed_category)
        self.assertFalse(vote.canonical_format)
        self.assertFalse(vote.constraints_passed)


class ConfidenceDecisionTests(unittest.TestCase):
    def test_accepts_two_matching_valid_votes(self) -> None:
        decision = decide(
            [parse_vote('{"category":"tests"}'), parse_vote('{"category":"tests"}')]
        )
        self.assertEqual(decision.status, ACCEPTED)
        self.assertEqual(decision.category, "tests")
        self.assertEqual(decision.confidence, 1.0)
        self.assertFalse(decision.needs_tiebreaker)

    def test_requests_tiebreaker_for_disagreement(self) -> None:
        decision = decide(
            [parse_vote('{"category":"feature"}'), parse_vote('{"category":"security"}')]
        )
        self.assertEqual(decision.status, UNSURE)
        self.assertTrue(decision.needs_tiebreaker)

    def test_marks_two_of_three_as_unsure(self) -> None:
        decision = decide(
            [
                parse_vote('{"category":"security"}'),
                parse_vote('{"category":"feature"}'),
                parse_vote('{"category":"security"}'),
            ]
        )
        self.assertEqual(decision.status, UNSURE)
        self.assertEqual(decision.category, "security")
        self.assertAlmostEqual(decision.confidence, 2 / 3)

    def test_rejects_three_way_split(self) -> None:
        decision = decide(
            [
                parse_vote('{"category":"bug"}'),
                parse_vote('{"category":"feature"}'),
                parse_vote('{"category":"tests"}'),
            ]
        )
        self.assertEqual(decision.status, REJECTED)
        self.assertIsNone(decision.category)
        self.assertAlmostEqual(decision.confidence, 1 / 3)

    def test_invalid_vote_prevents_automatic_acceptance(self) -> None:
        decision = decide(
            [parse_vote('{"category":"bug"}'), parse_vote("bug")]
        )
        self.assertEqual(decision.status, UNSURE)
        self.assertTrue(decision.needs_tiebreaker)


if __name__ == "__main__":
    unittest.main()
