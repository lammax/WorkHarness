#!/usr/bin/env python3
"""Pure confidence and constraint policy for the Day 7 classifier."""

from __future__ import annotations

import json
import re
from collections import Counter
from dataclasses import asdict, dataclass


ALLOWED_CATEGORIES = frozenset(
    {
        "bug",
        "feature",
        "refactoring",
        "tests",
        "documentation",
        "research",
        "security",
    }
)
ACCEPTED = "ACCEPTED"
UNSURE = "UNSURE"
REJECTED = "REJECTED"


@dataclass(frozen=True)
class InputCheck:
    accepted: bool
    reasons: tuple[str, ...]

    def to_dict(self) -> dict:
        return {"accepted": self.accepted, "reasons": list(self.reasons)}


@dataclass(frozen=True)
class ParsedVote:
    raw: str
    category: str | None
    valid_json: bool
    exact_schema: bool
    allowed_category: bool
    canonical_format: bool

    @property
    def constraints_passed(self) -> bool:
        return (
            self.valid_json
            and self.exact_schema
            and self.allowed_category
            and self.canonical_format
        )

    def to_dict(self) -> dict:
        payload = asdict(self)
        payload["constraints_passed"] = self.constraints_passed
        return payload


@dataclass(frozen=True)
class ConfidenceDecision:
    status: str
    category: str | None
    confidence: float
    needs_tiebreaker: bool
    reason: str

    def to_dict(self) -> dict:
        return asdict(self)


def validate_input(text: object) -> InputCheck:
    reasons: list[str] = []
    if not isinstance(text, str):
        return InputCheck(False, ("input_must_be_string",))

    stripped = text.strip()
    if not stripped:
        reasons.append("input_must_not_be_empty")
    if len(text) > 2_000:
        reasons.append("input_exceeds_2000_characters")
    if len(re.findall(r"[A-Za-zА-Яа-яЁё]", stripped)) < 3:
        reasons.append("input_has_insufficient_text")
    return InputCheck(not reasons, tuple(reasons))


def parse_vote(raw: object) -> ParsedVote:
    if not isinstance(raw, str):
        return ParsedVote(str(raw), None, False, False, False, False)

    try:
        payload = json.loads(raw)
    except json.JSONDecodeError:
        return ParsedVote(raw, None, False, False, False, False)

    valid_json = True
    exact_schema = (
        isinstance(payload, dict)
        and set(payload) == {"category"}
        and isinstance(payload.get("category"), str)
    )
    category = payload["category"] if exact_schema else None
    allowed_category = category in ALLOWED_CATEGORIES
    canonical_format = (
        exact_schema
        and raw == json.dumps(payload, ensure_ascii=False, separators=(",", ":"))
    )
    return ParsedVote(
        raw=raw,
        category=category,
        valid_json=valid_json,
        exact_schema=exact_schema,
        allowed_category=allowed_category,
        canonical_format=canonical_format,
    )


def decide(votes: list[ParsedVote]) -> ConfidenceDecision:
    if len(votes) not in {2, 3}:
        raise ValueError("confidence policy requires exactly two or three votes")

    valid_categories = [
        vote.category
        for vote in votes
        if vote.constraints_passed and vote.category is not None
    ]
    counts = Counter(valid_categories)

    if len(votes) == 2:
        if len(valid_categories) == 2 and valid_categories[0] == valid_categories[1]:
            return ConfidenceDecision(
                status=ACCEPTED,
                category=valid_categories[0],
                confidence=1.0,
                needs_tiebreaker=False,
                reason="two_valid_votes_agree",
            )
        return ConfidenceDecision(
            status=UNSURE,
            category=None,
            confidence=max(counts.values(), default=0) / 2,
            needs_tiebreaker=True,
            reason="initial_votes_disagree_or_violate_constraints",
        )

    winner, winner_count = counts.most_common(1)[0] if counts else (None, 0)
    confidence = winner_count / 3
    if winner_count >= 2:
        return ConfidenceDecision(
            status=UNSURE,
            category=winner,
            confidence=confidence,
            needs_tiebreaker=False,
            reason="two_of_three_votes_agree_manual_review_required",
        )
    return ConfidenceDecision(
        status=REJECTED,
        category=None,
        confidence=confidence,
        needs_tiebreaker=False,
        reason="no_valid_majority_after_three_votes",
    )
