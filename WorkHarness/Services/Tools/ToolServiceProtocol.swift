//
// ToolServiceProtocol.swift
// WorkHarness
//
// Created by Auto (Codex) on 09.07.2026.
//

import Foundation

@MainActor
protocol ToolServiceProtocol: BaseServiceProtocol {
    var availableTools: [ToolDefinition] { get }

    func execute(_ request: ToolExecutionRequest) async throws -> ToolResult
    func executeAwaitingApproval(_ request: ToolExecutionRequest) async throws -> ToolResult
}

extension ToolServiceProtocol {
    var service: AppService { .tools }
}
