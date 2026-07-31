//
// MCPApprovalGateway.swift
// WorkHarness
//
// Created by Auto (Codex) on 23.07.2026.
//

import Foundation

struct MCPGatewayHTTPResponse: Equatable {
    var statusCode: Int
    var contentType: String
    var body: Data
}

@MainActor
protocol MCPApprovalGatewayProtocol: AnyObject {
    func handle(
        requestBody: Data,
        runId: UUID,
        projectRootPath: String?
    ) async -> MCPGatewayHTTPResponse
}

@MainActor
final class MCPApprovalGateway: MCPApprovalGatewayProtocol {
    private let toolService: ToolServiceProtocol

    init(toolService: ToolServiceProtocol) {
        self.toolService = toolService
    }

    func handle(
        requestBody: Data,
        runId: UUID,
        projectRootPath: String?
    ) async -> MCPGatewayHTTPResponse {
        do {
            let request = try JSONDecoder().decode(JSONRPCRequest.self, from: requestBody)
            guard request.jsonrpc == "2.0" else {
                return response(id: request.id, errorCode: -32600, message: "Invalid JSON-RPC version.")
            }

            switch request.method {
            case "initialize":
                return response(id: request.id, result: .object([
                    "protocolVersion": .string("2025-06-18"),
                    "capabilities": .object([
                        "tools": .object(["listChanged": .bool(false)])
                    ]),
                    "serverInfo": .object([
                        "name": .string("workharness-approval-gateway"),
                        "version": .string("0.1.0")
                    ])
                ]))
            case "notifications/initialized":
                return MCPGatewayHTTPResponse(statusCode: 202, contentType: "application/json", body: Data())
            case "ping":
                return response(id: request.id, result: .object([:]))
            case "tools/list":
                return response(id: request.id, result: .object([
                    "tools": .array(toolService.availableTools.map(toolJSON))
                ]))
            case "tools/call":
                return await callTool(
                    request: request,
                    runId: runId,
                    projectRootPath: projectRootPath
                )
            default:
                return response(id: request.id, errorCode: -32601, message: "Method not found.")
            }
        } catch {
            return response(id: nil, errorCode: -32700, message: "Invalid JSON-RPC payload.")
        }
    }

    private func callTool(
        request: JSONRPCRequest,
        runId: UUID,
        projectRootPath: String?
    ) async -> MCPGatewayHTTPResponse {
        guard case .object(let parameters) = request.params,
              case .string(let toolName) = parameters["name"] else {
            return response(id: request.id, errorCode: -32602, message: "Tool name is required.")
        }

        var arguments: [String: String]
        if case .object(let rawArguments) = parameters["arguments"] {
            arguments = rawArguments.mapValues(\.stringValue)
        } else {
            arguments = [:]
        }
        let outputWindow = outputWindow(from: &arguments)

        do {
            let result = try await toolService.executeAwaitingApproval(.init(
                runId: runId,
                toolId: toolName,
                arguments: arguments,
                projectRootPath: projectRootPath,
                outputWindow: outputWindow
            ))
            return response(id: request.id, result: .object([
                "content": .array([
                    .object([
                        "type": .string("text"),
                        "text": .string(result.output)
                    ])
                ]),
                "isError": .bool(result.status == .failed)
            ]))
        } catch {
            return response(id: request.id, result: .object([
                "content": .array([
                    .object([
                        "type": .string("text"),
                        "text": .string(error.localizedDescription)
                    ])
                ]),
                "isError": .bool(true)
            ]))
        }
    }

    private func toolJSON(_ tool: ToolDefinition) -> JSONValue {
        var properties = Dictionary(uniqueKeysWithValues: tool.inputSchema.map { field in
            (
                field.name,
                JSONValue.object([
                    "type": .string("string"),
                    "description": .string(field.description)
                ])
            )
        })
        properties["_output_offset"] = .object([
            "type": .string("string"),
            "description": .string("Optional zero-based character offset for bounded output retrieval.")
        ])
        properties["_output_limit"] = .object([
            "type": .string("string"),
            "description": .string("Optional maximum characters to return; capped by WorkHarness.")
        ])
        let required = tool.inputSchema
            .filter(\.required)
            .map { JSONValue.string($0.name) }

        return .object([
            "name": .string(tool.id),
            "description": .string(tool.description),
            "inputSchema": .object([
                "type": .string("object"),
                "properties": .object(properties),
                "required": .array(required)
            ])
        ])
    }

    private func outputWindow(from arguments: inout [String: String]) -> ToolOutputWindow? {
        let rawOffset = arguments.removeValue(forKey: "_output_offset")
        let rawLimit = arguments.removeValue(forKey: "_output_limit")
        guard let rawLimit, let limit = Int(rawLimit), limit > 0 else { return nil }
        return ToolOutputWindow(offset: Int(rawOffset ?? "") ?? 0, limit: limit)
    }

    private func response(id: JSONValue?, result: JSONValue) -> MCPGatewayHTTPResponse {
        encode(JSONRPCResponse(jsonrpc: "2.0", id: id, result: result, error: nil))
    }

    private func response(id: JSONValue?, errorCode: Int, message: String) -> MCPGatewayHTTPResponse {
        encode(JSONRPCResponse(
            jsonrpc: "2.0",
            id: id,
            result: nil,
            error: JSONRPCError(code: errorCode, message: message)
        ))
    }

    private func encode(_ value: JSONRPCResponse) -> MCPGatewayHTTPResponse {
        let body = (try? JSONEncoder().encode(value)) ?? Data()
        return MCPGatewayHTTPResponse(statusCode: 200, contentType: "application/json", body: body)
    }
}

private struct JSONRPCRequest: Decodable {
    let jsonrpc: String
    let id: JSONValue?
    let method: String
    let params: JSONValue?
}

private struct JSONRPCResponse: Encodable {
    let jsonrpc: String
    let id: JSONValue?
    let result: JSONValue?
    let error: JSONRPCError?
}

private struct JSONRPCError: Encodable {
    let code: Int
    let message: String
}

private enum JSONValue: Codable, Equatable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([String: JSONValue].self) {
            self = .object(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSON value.")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value):
            try container.encode(value)
        case .number(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }

    var stringValue: String {
        switch self {
        case .string(let value):
            return value
        case .number(let value):
            return String(value)
        case .bool(let value):
            return String(value)
        case .object, .array:
            guard let data = try? JSONEncoder().encode(self),
                  let value = String(data: data, encoding: .utf8) else { return "" }
            return value
        case .null:
            return ""
        }
    }
}
