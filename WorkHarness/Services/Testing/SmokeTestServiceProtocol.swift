//
// SmokeTestServiceProtocol.swift
// WorkHarness
//
// Created by Auto (Codex) on 24.07.2026.
//

import Foundation

enum SmokeTestSelection: Equatable {
    case enabled
    case all
    case matching(String)
}

@MainActor
protocol SmokeTestServiceProtocol: BaseServiceProtocol {
    func startScenarios(_ selection: SmokeTestSelection) async throws -> UUID
}

extension SmokeTestServiceProtocol {
    var service: AppService { .testing }

    func startEnabledScenarios() async throws -> UUID {
        try await startScenarios(.enabled)
    }
}

enum SmokeTestServiceError: LocalizedError, Equatable {
    case environmentUnavailable
    case noEnabledScenarios
    case scenarioNotFound(String)
    case smokeRunnerUnavailable
    case runStartFailed
    case completedRunUnavailable
    case reportDirectoryUnavailable

    var errorDescription: String? {
        switch self {
        case .environmentUnavailable:
            "Smoke environment is not ready. Run Check Environment and fix unavailable requirements."
        case .noEnabledScenarios:
            "Enable at least one smoke scenario before starting."
        case .scenarioNotFound(let selector):
            "No smoke scenario matches “\(selector)”."
        case .smokeRunnerUnavailable:
            "The Testing profile has no enabled Smoke Runner."
        case .runStartFailed:
            "WorkHarness could not start the smoke-test Run."
        case .completedRunUnavailable:
            "The completed smoke-test Run could not be loaded for reporting."
        case .reportDirectoryUnavailable:
            "Select a project root before creating a smoke-test report."
        }
    }
}

enum SmokeTestCommand {
    static func selection(from message: String) -> SmokeTestSelection? {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        let command = trimmed.prefix { !$0.isWhitespace }
        guard command.lowercased() == "/smoke" else { return nil }

        let argument = trimmed.dropFirst(command.count)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if argument.isEmpty {
            return .enabled
        }
        if argument.lowercased() == "--all" {
            return .all
        }
        return .matching(argument)
    }
}
