//
// MicroModelInference.swift
// WorkHarness
//
// Created by Auto (Codex) on 31.07.2026.
//

import Foundation

enum TaskIntentCategory: String, Codable, CaseIterable, Equatable {
    case bug
    case feature
    case refactoring
    case tests
    case documentation
    case research
    case security
}

enum MicroModelConfidenceStatus: String, Codable, CaseIterable, Equatable {
    case ok = "OK"
    case unsure = "UNSURE"
}

struct MicroModelClassification: Codable, Equatable {
    var category: TaskIntentCategory
    var confidence: Double
    var status: MicroModelConfidenceStatus
}

enum MicroModelFallbackReason: String, Codable, Equatable {
    case statusUnsure
    case lowConfidence
    case invalidFormat
    case invalidCategory
    case invalidConfidence
}

struct MicroModelEvaluationCase: Identifiable, Codable, Equatable {
    var id: String
    var group: String
    var input: String
    var expectedCategory: TaskIntentCategory
}

struct MicroModelAttemptResult: Codable, Equatable {
    var modelId: String
    var classification: MicroModelClassification?
    var validationError: String?
    var latencyMilliseconds: Int
    var tokenUsage: TokenUsage?
}

struct MicroModelCaseResult: Codable, Equatable {
    var id: String
    var group: String
    var expectedCategory: TaskIntentCategory
    var finalCategory: TaskIntentCategory?
    var handledByMicroModel: Bool
    var fallbackReason: MicroModelFallbackReason?
    var microAttempt: MicroModelAttemptResult
    var fallbackAttempt: MicroModelAttemptResult?

    var isCorrect: Bool {
        finalCategory == expectedCategory
    }

    var totalLatencyMilliseconds: Int {
        microAttempt.latencyMilliseconds + (fallbackAttempt?.latencyMilliseconds ?? 0)
    }
}

struct MicroModelEvaluationSummary: Codable, Equatable {
    var runtimeId: String
    var microModelId: String
    var fallbackModelId: String
    var confidenceThreshold: Double
    var results: [MicroModelCaseResult]

    var totalCases: Int { results.count }
    var microModelHandledCount: Int { results.count(where: \.handledByMicroModel) }
    var fallbackCount: Int { results.count { $0.fallbackAttempt != nil } }
    var largeModelCallCount: Int { fallbackCount }
    var unresolvedCount: Int { results.count { $0.finalCategory == nil } }
    var correctCount: Int { results.count(where: \.isCorrect) }
    var averageLatencyMilliseconds: Int {
        guard !results.isEmpty else { return 0 }
        return results.reduce(0) { $0 + $1.totalLatencyMilliseconds } / results.count
    }
    var totalTokenUsage: TokenUsage {
        results.reduce(into: TokenUsage()) { total, result in
            for usage in [result.microAttempt.tokenUsage, result.fallbackAttempt?.tokenUsage].compactMap({ $0 }) {
                total.inputTokens += usage.inputTokens
                total.outputTokens += usage.outputTokens
                total.totalCostUSD += usage.totalCostUSD
            }
        }
    }
}
