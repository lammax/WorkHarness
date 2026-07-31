//
// MicroModelEvaluationServiceProtocol.swift
// WorkHarness
//
// Created by Auto (Codex) on 31.07.2026.
//

import Foundation

struct MicroModelEvaluationConfiguration: Equatable {
    var runtimeId: String = "claude.cli"
    var microModelId: String = "haiku"
    var fallbackModelId: String = "sonnet"
    var confidenceThreshold: Double = 0.8
    var maximumResponseCharacters: Int = 4_000
}

struct MicroModelEvaluationCommand: Equatable {
    static func parse(_ message: String) -> MicroModelEvaluationCommand? {
        let components = message
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(whereSeparator: \.isWhitespace)
            .map { $0.lowercased() }
        guard components == ["/micro-model", "evaluate"] else { return nil }
        return MicroModelEvaluationCommand()
    }
}

@MainActor
protocol MicroModelEvaluationServiceProtocol: BaseServiceProtocol {
    func startEvaluation() throws -> UUID
    func waitForCompletion(runId: UUID) async
}

extension MicroModelEvaluationServiceProtocol {
    var service: AppService { .runs }
}

enum MicroModelEvaluationServiceError: LocalizedError, Equatable {
    case runtimeUnavailable(String)
    case modelUnavailable(String)
    case toolUseNotAllowed
    case runtimeFailed(String)
    case missingResponse

    var errorDescription: String? {
        switch self {
        case .runtimeUnavailable(let runtimeId):
            "The inference runtime is unavailable: \(runtimeId)."
        case .modelUnavailable(let modelId):
            "The inference model is unavailable: \(modelId)."
        case .toolUseNotAllowed:
            "The classification-only inference attempted to use a tool."
        case .runtimeFailed(let message):
            "The inference runtime failed: \(message)"
        case .missingResponse:
            "The inference runtime completed without a response."
        }
    }
}
