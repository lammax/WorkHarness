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
    var mcpEndpointURL: String?

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
        mcpServerPath: MCPProviderConfiguration.defaultServerBasePath,
        mcpEndpointURL: nil
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
        mcpServerPath: MCPProviderConfiguration.defaultServerBasePath,
        mcpEndpointURL: nil
    )

    static let localLLM = MCPProviderDescriptor(
        id: "mcp.local.llm",
        displayName: "Local LLM",
        capabilities: ProviderCapabilities(
            supportsStreaming: true,
            supportsToolCalls: false,
            supportsFileEditing: false,
            supportsShellExecution: false,
            supportsLocalExecution: true,
            contextWindowTokens: 16_384,
            costModel: "local",
            supportsApprovals: false,
            supportsMCP: true,
            supportedModels: [AppSettingsDefaults.localLLMModel],
            supportsUsageReporting: true,
            supportsCancellation: false
        ),
        mcpServerPath: MCPProviderConfiguration.defaultServerBasePath,
        mcpEndpointURL: "http://127.0.0.1:3007/mcp"
    )

    static let llmGateway = MCPProviderDescriptor(
        id: "mcp.llm.gateway",
        displayName: "LLM Gateway",
        capabilities: ProviderCapabilities(
            supportsStreaming: false,
            supportsToolCalls: false,
            supportsFileEditing: false,
            supportsShellExecution: false,
            supportsLocalExecution: false,
            contextWindowTokens: nil,
            costModel: "gateway-estimated",
            supportsApprovals: false,
            supportsMCP: true,
            supportedModels: ["gpt-4.1-mini", "claude-sonnet-4-20250514"],
            supportsUsageReporting: true,
            supportsCancellation: false
        ),
        mcpServerPath: MCPProviderConfiguration.defaultServerBasePath,
        mcpEndpointURL: "http://127.0.0.1:3013/mcp"
    )
}

struct MCPProviderConfiguration: Equatable {
    nonisolated static let defaultServerBasePath = "/Users/lammax/Documents/ThisIsMy/Programming/AI/MCP_server"

    var serverBasePath: String
    var localLLMEndpointURL: String
    var localLLMModel: String
    var llmGatewayEndpointURL: String
    var providerDescriptors: [MCPProviderDescriptor]

    init(
        serverBasePath: String = Self.defaultServerBasePath,
        localLLMEndpointURL: String = AppSettingsDefaults.localLLMEndpoint,
        localLLMModel: String = AppSettingsDefaults.localLLMModel,
        llmGatewayEndpointURL: String = "http://127.0.0.1:3013/mcp",
        providerDescriptors: [MCPProviderDescriptor] = [.codexCLI, .cursorCLI, .localLLM, .llmGateway]
    ) {
        self.serverBasePath = serverBasePath
        self.localLLMEndpointURL = localLLMEndpointURL
        self.localLLMModel = localLLMModel
        self.llmGatewayEndpointURL = llmGatewayEndpointURL
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
    func listLocalLLMModels(endpointURL: String?) async throws -> [LocalLLMModelOption]
}

extension MCPProviderClientProtocol {
    func listLocalLLMModels(endpointURL: String?) async throws -> [LocalLLMModelOption] {
        throw MCPProviderClientError.modelDiscoveryUnavailable
    }
}

@MainActor
final class MCPProviderClient: MCPProviderClientProtocol {
    private let configurationProvider: () -> MCPProviderConfiguration

    convenience init() {
        self.init(configuration: MCPProviderConfiguration())
    }

    init(configuration: MCPProviderConfiguration) {
        self.configurationProvider = { configuration }
    }

    init(configurationProvider: @escaping () -> MCPProviderConfiguration) {
        self.configurationProvider = configurationProvider
    }

    func streamEvents(for request: MCPProviderRequest) async throws -> AsyncThrowingStream<MCPProviderEvent, Error> {
        if request.providerId == MCPProviderDescriptor.localLLM.id {
            return localLLMStream(for: request)
        }

        if request.providerId == MCPProviderDescriptor.llmGateway.id {
            return llmGatewayStream(for: request)
        }

        return AsyncThrowingStream<MCPProviderEvent, Error> { continuation in
            continuation.yield(.failed("MCP provider transport is not connected. Expected MCP server base: \(currentConfiguration.serverBasePath)"))
            continuation.finish()
        }
    }

    func listLocalLLMModels(endpointURL: String?) async throws -> [LocalLLMModelOption] {
        let text = try await callLocalLLMTool(
            named: "local_llm_list_models",
            arguments: EmptyMCPArguments(),
            endpointURL: endpointURL
        )
        return try JSONDecoder().decode([LocalLLMModelOption].self, from: Data(text.utf8))
    }

    private func localLLMStream(for request: MCPProviderRequest) -> AsyncThrowingStream<MCPProviderEvent, Error> {
        AsyncThrowingStream<MCPProviderEvent, Error> { continuation in
            Task {
                continuation.yield(.started)

                do {
                    let result = try await callLocalLLMGenerate(request.aiRequest)
                    if !result.content.isEmpty {
                        continuation.yield(.messageDelta(result.content))
                    }
                    continuation.yield(.messageCompleted(result.content))

                    if let usage = result.usage {
                        continuation.yield(.tokenUsage(TokenUsage(
                            inputTokens: usage.promptTokens ?? 0,
                            outputTokens: usage.completionTokens ?? 0
                        )))
                    }

                    continuation.yield(.finished)
                } catch {
                    continuation.yield(.failed(error.localizedDescription))
                }

                continuation.finish()
            }
        }
    }

    private func callLocalLLMGenerate(_ request: AIRequest) async throws -> LocalLLMGenerateResult {
        let messages = localLLMMessages(from: request)
        let text = try await callLocalLLMTool(
            named: "local_llm_generate",
            arguments: LocalLLMGenerateArguments(
                messages: messages,
                model: request.model.isEmpty ? currentConfiguration.localLLMModel : request.model,
                temperature: request.temperature ?? 0.1,
                topP: 0.9,
                maxTokens: request.budget?.maxOutputTokens
            ),
            endpointURL: nil
        )
        return try JSONDecoder().decode(LocalLLMGenerateResult.self, from: Data(text.utf8))
    }

    private func llmGatewayStream(for request: MCPProviderRequest) -> AsyncThrowingStream<MCPProviderEvent, Error> {
        AsyncThrowingStream<MCPProviderEvent, Error> { continuation in
            Task {
                continuation.yield(.started)
                do {
                    let result = try await callLLMGatewayGenerate(request.aiRequest)
                    guard result.status == "completed", let content = result.content else {
                        continuation.yield(.failed(result.warning ?? "LLM Gateway blocked the request."))
                        continuation.finish()
                        return
                    }
                    if !content.isEmpty {
                        continuation.yield(.messageDelta(content))
                    }
                    continuation.yield(.messageCompleted(content))
                    if let usage = result.usage {
                        continuation.yield(.tokenUsage(TokenUsage(
                            inputTokens: usage.promptTokens,
                            outputTokens: usage.completionTokens,
                            totalCostUSD: usage.estimatedCostUSD
                        )))
                    }
                    continuation.yield(.finished)
                } catch {
                    continuation.yield(.failed(error.localizedDescription))
                }
                continuation.finish()
            }
        }
    }

    private func callLLMGatewayGenerate(_ request: AIRequest) async throws -> LLMGatewayGenerateResult {
        let provider = request.metadata["llmGatewayProvider"]
            ?? (request.model.hasPrefix("claude-") ? "anthropic" : "openai")
        let guardMode = request.metadata["llmGatewayGuardMode"] == "mask" ? "mask" : "block"
        let text = try await callMCPTool(
            named: "llm_gateway_generate",
            arguments: LLMGatewayGenerateArguments(
                provider: provider,
                model: request.model,
                messages: localLLMMessages(from: request),
                guardMode: guardMode,
                temperature: request.temperature,
                maxTokens: request.budget?.maxOutputTokens
            ),
            endpointURL: currentConfiguration.llmGatewayEndpointURL,
            providerId: MCPProviderDescriptor.llmGateway.id
        )
        return try JSONDecoder().decode(LLMGatewayGenerateResult.self, from: Data(text.utf8))
    }

    private func callLocalLLMTool<Arguments: Encodable>(
        named name: String,
        arguments: Arguments,
        endpointURL: String?
    ) async throws -> String {
        try await callMCPTool(
            named: name,
            arguments: arguments,
            endpointURL: endpointURL ?? currentConfiguration.localLLMEndpointURL,
            providerId: MCPProviderDescriptor.localLLM.id
        )
    }

    private func callMCPTool<Arguments: Encodable>(
        named name: String,
        arguments: Arguments,
        endpointURL: String,
        providerId: String
    ) async throws -> String {
        guard let url = URL(string: endpointURL) else {
            throw MCPProviderClientError.missingEndpoint(providerId)
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("application/json, text/event-stream", forHTTPHeaderField: "Accept")
        urlRequest.httpBody = try JSONEncoder().encode(MCPJSONRPCRequest(
            id: 1,
            method: "tools/call",
            params: MCPToolCallParams(name: name, arguments: arguments)
        ))

        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw MCPProviderClientError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw MCPProviderClientError.httpStatus(httpResponse.statusCode)
        }

        let decoded = try JSONDecoder().decode(MCPToolCallResponse.self, from: data)
        if let error = decoded.error {
            throw MCPProviderClientError.jsonRPCError(error.message)
        }
        guard decoded.result?.isError != true,
              let text = decoded.result?.content.first(where: { $0.text != nil })?.text else {
            throw MCPProviderClientError.missingToolResult
        }
        return text
    }

    var currentConfiguration: MCPProviderConfiguration {
        configurationProvider()
    }

    func localLLMMessages(from request: AIRequest) -> [LocalLLMMessage] {
        var messages: [LocalLLMMessage] = []

        if !request.context.isEmpty {
            messages.append(LocalLLMMessage(
                role: ProviderMessageRole.system.rawValue,
                content: request.context.joined(separator: "\n\n")
            ))
        }

        messages.append(contentsOf: request.messages.map {
            LocalLLMMessage(role: $0.role.rawValue, content: $0.content)
        })

        return messages
    }
}

enum MCPProviderClientError: LocalizedError, Equatable {
    case missingEndpoint(String)
    case invalidResponse
    case httpStatus(Int)
    case jsonRPCError(String)
    case missingToolResult
    case modelDiscoveryUnavailable

    var errorDescription: String? {
        switch self {
        case .missingEndpoint(let providerId):
            return "MCP endpoint is not configured for provider \(providerId)."
        case .invalidResponse:
            return "MCP provider returned an invalid HTTP response."
        case .httpStatus(let statusCode):
            return "MCP provider request failed with HTTP \(statusCode)."
        case .jsonRPCError(let message):
            return "MCP provider request failed: \(message)"
        case .missingToolResult:
            return "MCP provider response did not include a text tool result."
        case .modelDiscoveryUnavailable:
            return "Local LLM model discovery is unavailable."
        }
    }
}

private struct EmptyMCPArguments: Encodable {}

private struct MCPJSONRPCRequest<Params: Encodable>: Encodable {
    let jsonrpc = "2.0"
    let id: Int
    let method: String
    let params: Params
}

private struct MCPToolCallParams<Arguments: Encodable>: Encodable {
    let name: String
    let arguments: Arguments
}

private struct LocalLLMGenerateArguments: Encodable {
    let messages: [LocalLLMMessage]
    let model: String
    let temperature: Double?
    let topP: Double?
    let maxTokens: Int?

    enum CodingKeys: String, CodingKey {
        case messages
        case model
        case temperature
        case topP = "top_p"
        case maxTokens = "max_tokens"
    }
}

private struct LLMGatewayGenerateArguments: Encodable {
    let provider: String
    let model: String
    let messages: [LocalLLMMessage]
    let guardMode: String
    let temperature: Double?
    let maxTokens: Int?

    enum CodingKeys: String, CodingKey {
        case provider, model, messages, temperature
        case guardMode = "guard_mode"
        case maxTokens = "max_tokens"
    }
}

struct LocalLLMMessage: Codable, Equatable {
    let role: String
    let content: String
}

private struct MCPToolCallResponse: Decodable {
    let result: MCPToolCallResult?
    let error: MCPJSONRPCError?
}

private struct MCPToolCallResult: Decodable {
    let content: [MCPContentItem]
    let isError: Bool?
}

private struct MCPContentItem: Decodable {
    let text: String?
}

private struct MCPJSONRPCError: Decodable {
    let message: String
}

private struct LocalLLMGenerateResult: Decodable, Equatable {
    let model: String
    let content: String
    let finishReason: String?
    let usage: LocalLLMUsage?
}

private struct LocalLLMUsage: Decodable, Equatable {
    let promptTokens: Int?
    let completionTokens: Int?
    let totalTokens: Int?
}

private struct LLMGatewayGenerateResult: Decodable, Equatable {
    let status: String
    let content: String?
    let warning: String?
    let usage: LLMGatewayUsageResult?
}

private struct LLMGatewayUsageResult: Decodable, Equatable {
    let promptTokens: Int
    let completionTokens: Int
    let estimatedCostUSD: Decimal

    enum CodingKeys: String, CodingKey {
        case promptTokens = "prompt_tokens"
        case completionTokens = "completion_tokens"
        case estimatedCostUSD = "estimated_cost_usd"
    }
}
