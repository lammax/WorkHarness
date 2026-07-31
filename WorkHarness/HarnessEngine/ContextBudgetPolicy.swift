//
// ContextBudgetPolicy.swift
// WorkHarness
//
// Created by Auto (Codex) on 31.07.2026.
//

import Foundation

enum ContextBuildError: LocalizedError, Equatable {
    case mandatoryContentExceedsBudget(
        sourceId: String,
        requiredTokens: Int,
        availableTokens: Int
    )
    case tokenEstimationFailed(sourceId: String, message: String)

    var errorDescription: String? {
        switch self {
        case let .mandatoryContentExceedsBudget(sourceId, requiredTokens, availableTokens):
            return "Mandatory context source \(sourceId) requires \(requiredTokens) tokens, but only \(availableTokens) input tokens are available."
        case let .tokenEstimationFailed(sourceId, message):
            return "Could not estimate context source \(sourceId): \(message)"
        }
    }
}

struct ContextBudgetResult: Equatable {
    var sections: [ContextSection]
    var omissions: [ContextOmission]
    var estimatedInputTokenCount: Int
}

struct ContextBudgetPolicy {
    func apply(
        objective: ContextSourceReference,
        sections: [ContextSection],
        constraint: ContextWindowConstraint
    ) throws -> ContextBudgetResult {
        try Task.checkCancellation()

        guard let limit = constraint.effectiveMaxInputTokens else {
            return ContextBudgetResult(
                sections: sections,
                omissions: [],
                estimatedInputTokenCount: objective.estimatedTokenCount +
                    sections.reduce(0) { $0 + $1.estimatedTokenCount }
            )
        }

        guard objective.estimatedTokenCount <= limit else {
            throw ContextBuildError.mandatoryContentExceedsBudget(
                sourceId: objective.id,
                requiredTokens: objective.estimatedTokenCount,
                availableTokens: limit
            )
        }

        var usedTokens = objective.estimatedTokenCount
        var includedSections: [ContextSection] = []
        var omissions: [ContextOmission] = []
        let prioritizedSections = sections.sorted {
            if $0.priority == $1.priority {
                return $0.order < $1.order
            }
            return $0.priority.rawValue < $1.priority.rawValue
        }

        for section in prioritizedSections {
            try Task.checkCancellation()
            let availableTokens = max(0, limit - usedTokens)

            if section.estimatedTokenCount <= availableTokens {
                includedSections.append(section)
                usedTokens += section.estimatedTokenCount
                continue
            }

            if section.priority == .critical {
                throw ContextBuildError.mandatoryContentExceedsBudget(
                    sourceId: section.id,
                    requiredTokens: section.estimatedTokenCount,
                    availableTokens: availableTokens
                )
            }

            omissions.append(contentsOf: omissionsForSection(section))
        }

        return ContextBudgetResult(
            sections: includedSections.sorted { $0.order < $1.order },
            omissions: omissions,
            estimatedInputTokenCount: usedTokens
        )
    }

    private func omissionsForSection(_ section: ContextSection) -> [ContextOmission] {
        guard !section.sources.isEmpty else {
            return [
                ContextOmission(
                    sourceId: section.id,
                    sourceKind: nil,
                    sectionKind: section.kind,
                    reason: .budgetExceeded,
                    estimatedTokenCount: section.estimatedTokenCount
                )
            ]
        }

        return section.sources.map { source in
            ContextOmission(
                sourceId: source.id,
                sourceKind: source.kind,
                sectionKind: section.kind,
                reason: .budgetExceeded,
                estimatedTokenCount: source.estimatedTokenCount
            )
        }
    }
}
