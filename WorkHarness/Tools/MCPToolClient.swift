//
// MCPToolClient.swift
// WorkHarness
//
// Created by Auto (Codex) on 09.07.2026.
//

import Foundation

struct MCPToolInvocation: Equatable {
    var toolId: String
    var arguments: [String: String]
    var projectRootPath: String?
}

@MainActor
protocol MCPToolClientProtocol: AnyObject {
    func invoke(_ invocation: MCPToolInvocation) async throws -> ToolResult
}

@MainActor
final class MCPToolClient: MCPToolClientProtocol {
    private let serverBasePath: String

    init(serverBasePath: String = MCPProviderConfiguration.defaultServerBasePath) {
        self.serverBasePath = serverBasePath
    }

    func invoke(_ invocation: MCPToolInvocation) async throws -> ToolResult {
        throw ToolError.mcpTransportNotConnected(serverBasePath)
    }
}
