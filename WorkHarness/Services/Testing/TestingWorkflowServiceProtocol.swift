//
// TestingWorkflowServiceProtocol.swift
// WorkHarness
//
// Created by Auto (Codex) on 24.07.2026.
//

import Foundation

@MainActor
protocol TestingWorkflowServiceProtocol: BaseServiceProtocol {
    func startFullRun(request: String?) async throws -> UUID
}

extension TestingWorkflowServiceProtocol {
    var service: AppService { .testing }
}

enum TestingWorkflowServiceError: LocalizedError, Equatable {
    case environmentUnavailable
    case noEnabledScenarios
    case testingProfileIncomplete
    case runStartFailed
    case completedRunUnavailable
    case reportDirectoryUnavailable

    var errorDescription: String? {
        switch self {
        case .environmentUnavailable:
            "Testing environment is not ready. Check the Testing settings and fix unavailable requirements."
        case .noEnabledScenarios:
            "Enable at least one smoke scenario before starting the full testing flow."
        case .testingProfileIncomplete:
            "The Testing profile must enable Coverage Analyst, Test Author, Code Test Runner, Smoke Runner, and Test Reporter."
        case .runStartFailed:
            "WorkHarness could not start the full testing Run."
        case .completedRunUnavailable:
            "The completed testing Run could not be loaded for reporting."
        case .reportDirectoryUnavailable:
            "Select a project root before creating the testing report."
        }
    }
}

struct TestingWorkflowCommand: Equatable {
    let request: String?

    static func parse(_ message: String) -> TestingWorkflowCommand? {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        let command = trimmed.prefix { !$0.isWhitespace }
        guard command.lowercased() == "/test" else { return nil }

        let argument = trimmed.dropFirst(command.count)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if argument.isEmpty || argument.lowercased() == "--all" {
            return TestingWorkflowCommand(request: nil)
        }
        return TestingWorkflowCommand(request: argument)
    }
}
