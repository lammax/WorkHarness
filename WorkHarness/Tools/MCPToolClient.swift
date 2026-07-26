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

struct MCPToolTransportResponse: Equatable {
    var output: String
    var isError: Bool
    var artifacts: [RunArtifact] = []
}

@MainActor
protocol MCPToolTransportProtocol: AnyObject {
    func callTool(
        endpoint: URL,
        name: String,
        arguments: [String: Any]
    ) async throws -> MCPToolTransportResponse
}

@MainActor
protocol MCPToolClientProtocol: AnyObject {
    func invoke(_ invocation: MCPToolInvocation) async throws -> ToolResult
}

@MainActor
final class MCPToolClient: MCPToolClientProtocol {
    private struct Route {
        let endpoint: URL
        let toolName: String
        let arguments: [String: Any]
    }

    private let transport: MCPToolTransportProtocol

    convenience init() {
        self.init(transport: MCPHTTPToolTransport())
    }

    init(transport: MCPToolTransportProtocol) {
        self.transport = transport
    }

    func invoke(_ invocation: MCPToolInvocation) async throws -> ToolResult {
        let route = try route(for: invocation)
        let response = try await transport.callTool(
            endpoint: route.endpoint,
            name: route.toolName,
            arguments: route.arguments
        )

        return ToolResult(
            toolId: invocation.toolId,
            status: response.isError ? .failed : .succeeded,
            output: response.output,
            metadata: [
                "mcpEndpoint": route.endpoint.absoluteString,
                "mcpToolName": route.toolName
            ],
            artifacts: response.artifacts
        )
    }

    private func route(for invocation: MCPToolInvocation) throws -> Route {
        var arguments = invocation.arguments.reduce(into: [String: Any]()) {
            $0[$1.key] = $1.value
        }
        if let projectRootPath = invocation.projectRootPath {
            arguments["project_root"] = projectRootPath
        }

        switch invocation.toolId {
        case "file.read":
            return Route(endpoint: Self.fileOperationsEndpoint, toolName: "project_read_file", arguments: arguments)
        case "file.write":
            arguments["overwrite"] = true
            return Route(endpoint: Self.fileOperationsEndpoint, toolName: "project_write_file", arguments: arguments)
        case "shell.run":
            return Route(endpoint: Self.developerToolsEndpoint, toolName: "workspace_run_shell", arguments: arguments)
        case "git.run":
            return Route(endpoint: Self.developerToolsEndpoint, toolName: "workspace_run_git", arguments: arguments)
        case "rag.search":
            return Route(endpoint: Self.ragEndpoint, toolName: "rag_answer", arguments: arguments)
        case "mobile.health":
            return Route(
                endpoint: Self.mobileAutomationEndpoint,
                toolName: "workharness_health",
                arguments: [:]
            )
        case "mobile.wda":
            return Route(
                endpoint: Self.mobileAutomationEndpoint,
                toolName: "workharness_wda",
                arguments: arguments
            )
        case let toolId where toolId.hasPrefix(Self.mobileToolPrefix):
            let toolName = String(toolId.dropFirst(Self.mobileToolPrefix.count))
            guard !toolName.isEmpty else {
                throw MCPToolClientError.unsupportedTool(invocation.toolId)
            }
            if let argumentsJSON = invocation.arguments["argumentsJSON"] {
                arguments.merge(
                    try decodedJSONObject(argumentsJSON),
                    uniquingKeysWith: { current, _ in current }
                )
                arguments.removeValue(forKey: "argumentsJSON")
            }
            return Route(
                endpoint: Self.mobileAutomationEndpoint,
                toolName: toolName,
                arguments: arguments
            )
        default:
            throw MCPToolClientError.unsupportedTool(invocation.toolId)
        }
    }

    private func decodedJSONObject(_ value: String) throws -> [String: Any] {
        guard let data = value.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data),
              let dictionary = object as? [String: Any] else {
            throw MCPToolClientError.invalidArgumentsJSON
        }
        return dictionary
    }

    private nonisolated static let fileOperationsEndpoint = URL(string: "http://127.0.0.1:3005/mcp")!
    private nonisolated static let ragEndpoint = URL(string: "http://127.0.0.1:3003/mcp")!
    private nonisolated static let developerToolsEndpoint = URL(string: "http://127.0.0.1:3008/mcp")!
    private nonisolated static let mobileAutomationEndpoint = URL(string: "http://127.0.0.1:3009/mcp")!
    private nonisolated static let mobileToolPrefix = "mobile."
}

@MainActor
final class MCPHTTPToolTransport: MCPToolTransportProtocol {
    private nonisolated static let requestTimeout: TimeInterval = 15 * 60

    private let session: URLSession
    private let serverSupervisor: MCPServerProcessSupervisorProtocol?
    private var initializedEndpoints: Set<URL> = []

    init(
        session: URLSession = .shared,
        serverSupervisor: MCPServerProcessSupervisorProtocol? = nil
    ) {
        self.session = session
        self.serverSupervisor = serverSupervisor
    }

    func callTool(
        endpoint: URL,
        name: String,
        arguments: [String: Any]
    ) async throws -> MCPToolTransportResponse {
        try await serverSupervisor?.ensureRunning(endpoint: endpoint)
        try await initializeIfNeeded(endpoint: endpoint)
        let response = try await send(
            endpoint: endpoint,
            method: "tools/call",
            parameters: ["name": name, "arguments": arguments]
        )
        if let error = response["error"] as? [String: Any] {
            throw MCPToolClientError.server(error["message"] as? String ?? "Unknown MCP error")
        }
        guard let result = response["result"] as? [String: Any],
              let content = result["content"] as? [[String: Any]] else {
            throw MCPToolClientError.invalidResponse
        }

        var artifacts: [RunArtifact] = []
        let output = content.compactMap { item -> String? in
            guard let text = item["text"] as? String else { return nil }
            if let artifact = Self.decodeArtifactMarker(text) {
                artifacts.append(artifact)
                return nil
            }
            return text
        }.joined(separator: "\n")
        return MCPToolTransportResponse(
            output: output,
            isError: result["isError"] as? Bool ?? false,
            artifacts: artifacts
        )
    }

    private nonisolated static func decodeArtifactMarker(_ text: String) -> RunArtifact? {
        guard let data = text.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let marker = object["workharnessArtifact"] as? [String: Any],
              let name = marker["name"] as? String,
              let kind = marker["kind"] as? String,
              let path = marker["path"] as? String else {
            return nil
        }
        return RunArtifact(name: name, kind: kind, path: path)
    }

    private func initializeIfNeeded(endpoint: URL) async throws {
        guard !initializedEndpoints.contains(endpoint) else { return }
        let response = try await send(
            endpoint: endpoint,
            method: "initialize",
            parameters: [
                "protocolVersion": "2025-06-18",
                "capabilities": [:],
                "clientInfo": ["name": "WorkHarness", "version": "1.0.0"]
            ]
        )
        if let error = response["error"] as? [String: Any] {
            let message = error["message"] as? String ?? "Unknown MCP error"
            guard message.lowercased().contains("already initialized") else {
                throw MCPToolClientError.server(message)
            }
        }
        initializedEndpoints.insert(endpoint)
    }

    private func send(
        endpoint: URL,
        method: String,
        parameters: [String: Any]
    ) async throws -> [String: Any] {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = Self.requestTimeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json, text/event-stream", forHTTPHeaderField: "Accept")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "jsonrpc": "2.0",
            "id": UUID().uuidString,
            "method": method,
            "params": parameters
        ])

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw MCPToolClientError.httpStatus((response as? HTTPURLResponse)?.statusCode ?? -1)
        }
        return try decodeResponse(data)
    }

    private func decodeResponse(_ data: Data) throws -> [String: Any] {
        if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return object
        }

        let eventData = String(decoding: data, as: UTF8.self)
            .split(whereSeparator: \.isNewline)
            .compactMap { line -> String? in
                guard line.hasPrefix("data:") else { return nil }
                return String(line.dropFirst("data:".count)).trimmingCharacters(in: .whitespaces)
            }
            .joined()
        guard let payload = eventData.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: payload) as? [String: Any] else {
            throw MCPToolClientError.invalidResponse
        }
        return object
    }
}

private enum MCPToolClientError: LocalizedError {
    case unsupportedTool(String)
    case httpStatus(Int)
    case invalidResponse
    case invalidArgumentsJSON
    case server(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedTool(let toolId):
            "No MCP route is registered for tool: \(toolId)"
        case .httpStatus(let statusCode):
            "MCP tool server returned HTTP \(statusCode)."
        case .invalidResponse:
            "MCP tool server returned an invalid response."
        case .invalidArgumentsJSON:
            "Mobile automation argumentsJSON must be a JSON object."
        case .server(let message):
            "MCP tool server error: \(message)"
        }
    }
}
