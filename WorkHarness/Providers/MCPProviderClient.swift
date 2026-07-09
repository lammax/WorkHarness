//
// MCPProviderClient.swift
// WorkHarness
//
// Created by Auto (Codex) on 09.07.2026.
//

import Foundation

struct MCPProviderDescriptor: Equatable {
    var id: String
    var displayName: String
    var capabilities: ProviderCapabilities
    var mcpServerPath: String

    static let codexCLI = MCPProviderDescriptor(
        id: "mcp.codex.cli",
        displayName: "Codex CLI",
        capabilities: ProviderCapabilities(
            supportsStreaming: true,
            supportsToolCalls: false,
            supportsFileEditing: true,
            supportsShellExecution: true,
            supportsLocalExecution: true,
            contextWindowTokens: nil,
            costModel: "codex-cli-account",
            supportsApprovals: true,
            supportsMCP: true,
            supportedModels: ["codex-cli"]
        ),
        mcpServerPath: MCPProviderConfiguration.defaultServerBasePath
    )

    static let cursorCLI = MCPProviderDescriptor(
        id: "mcp.cursor.cli",
        displayName: "Cursor CLI",
        capabilities: ProviderCapabilities(
            supportsStreaming: true,
            supportsToolCalls: false,
            supportsFileEditing: true,
            supportsShellExecution: true,
            supportsLocalExecution: true,
            contextWindowTokens: nil,
            costModel: "cursor-cli-account",
            supportsApprovals: true,
            supportsMCP: true,
            supportedModels: ["cursor-agent"]
        ),
        mcpServerPath: MCPProviderConfiguration.defaultServerBasePath
    )
}

struct MCPProviderConfiguration: Equatable {
    static let defaultServerBasePath = "/Users/lammax/Documents/ThisIsMy/Programming/AI/MCP_server"

    var serverBasePath: String
    var providerDescriptors: [MCPProviderDescriptor]

    init(
        serverBasePath: String = Self.defaultServerBasePath,
        providerDescriptors: [MCPProviderDescriptor] = [.codexCLI, .cursorCLI]
    ) {
        self.serverBasePath = serverBasePath
        self.providerDescriptors = providerDescriptors
    }
}

struct MCPProviderRequest: Equatable {
    var providerId: String
    var aiRequest: AIRequest
}

enum MCPProviderEvent: Equatable {
    case started
    case messageDelta(String)
    case messageCompleted(String)
    case tokenUsage(TokenUsage)
    case finished
    case failed(String)
}

@MainActor
protocol MCPProviderClientProtocol: AnyObject {
    func streamEvents(for request: MCPProviderRequest) async throws -> AsyncThrowingStream<MCPProviderEvent, Error>
}

@MainActor
final class MCPProviderClient: MCPProviderClientProtocol {
    private let configuration: MCPProviderConfiguration

    convenience init() {
        self.init(configuration: MCPProviderConfiguration())
    }

    init(configuration: MCPProviderConfiguration) {
        self.configuration = configuration
    }

    func streamEvents(for request: MCPProviderRequest) async throws -> AsyncThrowingStream<MCPProviderEvent, Error> {
        AsyncThrowingStream { continuation in
            continuation.yield(.failed("MCP provider transport is not connected. Expected MCP server base: \(configuration.serverBasePath)"))
            continuation.finish()
        }
    }
}
