//
// TestingEnvironmentServiceProtocol.swift
// WorkHarness
//
// Created by Auto (Codex) on 24.07.2026.
//

import Foundation

@MainActor
protocol TestingEnvironmentServiceProtocol: BaseServiceProtocol {
    func checkEnvironment() async throws -> TestingEnvironmentDiagnostics
}

extension TestingEnvironmentServiceProtocol {
    var service: AppService { .testing }
}

enum TestingEnvironmentServiceError: LocalizedError {
    case diagnosticFailed(String)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .diagnosticFailed(let message):
            message
        case .invalidResponse:
            "Mobile automation diagnostics returned an invalid response."
        }
    }
}
