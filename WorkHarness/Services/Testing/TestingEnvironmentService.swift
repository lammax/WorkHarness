//
// TestingEnvironmentService.swift
// WorkHarness
//
// Created by Auto (Codex) on 24.07.2026.
//

import Foundation

@MainActor
final class TestingEnvironmentService: TestingEnvironmentServiceProtocol {
    private let mcpClient: MCPToolClientProtocol

    init(mcpClient: MCPToolClientProtocol) {
        self.mcpClient = mcpClient
    }

    func checkEnvironment() async throws -> TestingEnvironmentDiagnostics {
        let result = try await mcpClient.invoke(.init(
            toolId: "mobile.health",
            arguments: [:],
            projectRootPath: nil
        ))
        guard result.status == .succeeded else {
            throw TestingEnvironmentServiceError.diagnosticFailed(result.output)
        }
        guard let data = result.output.data(using: .utf8) else {
            throw TestingEnvironmentServiceError.invalidResponse
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let diagnostics = try? decoder.decode(
            TestingEnvironmentDiagnostics.self,
            from: data
        ) else {
            throw TestingEnvironmentServiceError.invalidResponse
        }
        return diagnostics
    }
}
