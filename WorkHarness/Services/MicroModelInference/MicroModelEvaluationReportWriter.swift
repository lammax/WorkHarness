//
// MicroModelEvaluationReportWriter.swift
// WorkHarness
//
// Created by Auto (Codex) on 31.07.2026.
//

import Foundation

struct MicroModelEvaluationReportWriter {
    func markdown(for summary: MicroModelEvaluationSummary) -> String {
        let usage = summary.totalTokenUsage
        let rows = summary.results.map { result in
            let route = result.handledByMicroModel ? "micro" : "fallback"
            let category = result.finalCategory?.rawValue ?? "unresolved"
            let reason = result.fallbackReason?.rawValue ?? "none"
            return "| \(result.id) | \(result.group) | \(result.expectedCategory.rawValue) | \(category) | \(route) | \(reason) | \(result.totalLatencyMilliseconds) |"
        }.joined(separator: "\n")
        return """
        # Day 10 — Micro-model First Evaluation

        - Runtime: `\(summary.runtimeId)`
        - Micro-model: `\(summary.microModelId)`
        - Fallback model: `\(summary.fallbackModelId)`
        - Confidence threshold: `\(summary.confidenceThreshold)`
        - Total cases: \(summary.totalCases)
        - Handled by micro-model: \(summary.microModelHandledCount)
        - Fallbacks / large-model calls: \(summary.fallbackCount)
        - Unresolved: \(summary.unresolvedCount)
        - Correct: \(summary.correctCount)/\(summary.totalCases)
        - Average end-to-end latency: \(summary.averageLatencyMilliseconds) ms
        - Tokens: \(usage.inputTokens) input / \(usage.outputTokens) output
        - Reported cost: $\(NSDecimalNumber(decimal: usage.totalCostUSD).stringValue)

        | Case | Group | Expected | Result | Route | Fallback reason | Latency ms |
        | --- | --- | --- | --- | --- | --- | ---: |
        \(rows)
        """
    }

    func json(for summary: MicroModelEvaluationSummary) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(summary)
        return String(decoding: data, as: UTF8.self)
    }
}
