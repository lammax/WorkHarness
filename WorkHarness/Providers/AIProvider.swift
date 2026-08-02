//
// AIProvider.swift
// WorkHarness
//
// Created by Auto (Codex) on 07.07.2026.
//

import Foundation

protocol AIProvider {
    var id: String { get }
    var displayName: String { get }
    var capabilities: ProviderCapabilities { get }

    func send(_ request: AIRequest) async throws -> AsyncThrowingStream<AIEvent, Error>
}

struct ProviderCapabilities: Codable, Equatable {
    var supportsStreaming: Bool
    var supportsToolCalls: Bool
    var supportsFileEditing: Bool
    var supportsShellExecution: Bool
    var supportsVision: Bool
    var supportsEmbeddings: Bool
    var supportsReasoningMode: Bool
    var supportsLocalExecution: Bool
    var contextWindowTokens: Int?
    var costModel: String?
    var supportsApprovals: Bool
    var supportsMCP: Bool
    var supportedModels: [String]
    var supportsUsageReporting: Bool?
    var supportsCancellation: Bool?

    init(
        supportsStreaming: Bool = true,
        supportsToolCalls: Bool = false,
        supportsFileEditing: Bool = false,
        supportsShellExecution: Bool = false,
        supportsVision: Bool = false,
        supportsEmbeddings: Bool = false,
        supportsReasoningMode: Bool = false,
        supportsLocalExecution: Bool = false,
        contextWindowTokens: Int? = nil,
        costModel: String? = nil,
        supportsApprovals: Bool = false,
        supportsMCP: Bool = false,
        supportedModels: [String] = [],
        supportsUsageReporting: Bool? = nil,
        supportsCancellation: Bool? = nil
    ) {
        self.supportsStreaming = supportsStreaming
        self.supportsToolCalls = supportsToolCalls
        self.supportsFileEditing = supportsFileEditing
        self.supportsShellExecution = supportsShellExecution
        self.supportsVision = supportsVision
        self.supportsEmbeddings = supportsEmbeddings
        self.supportsReasoningMode = supportsReasoningMode
        self.supportsLocalExecution = supportsLocalExecution
        self.contextWindowTokens = contextWindowTokens
        self.costModel = costModel
        self.supportsApprovals = supportsApprovals
        self.supportsMCP = supportsMCP
        self.supportedModels = supportedModels
        self.supportsUsageReporting = supportsUsageReporting
        self.supportsCancellation = supportsCancellation
    }

    func contextDeliveryPlan(reservedOutputTokens: Int?) -> ContextDeliveryPlan {
        ContextDeliveryPlan(
            mode: .structuredMessages,
            capabilities: ContextBoundaryCapabilities(
                contextWindowTokens: contextWindowTokens,
                reservedOutputTokens: reservedOutputTokens,
                streaming: InferenceCapabilitySupport(supportsStreaming),
                tools: InferenceCapabilitySupport(supportsToolCalls),
                usageReporting: InferenceCapabilitySupport(supportsUsageReporting),
                cancellation: InferenceCapabilitySupport(supportsCancellation)
            )
        )
    }
}

struct AIRequest: Identifiable, Codable, Equatable {
    let id: UUID
    let runId: UUID
    let agentId: UUID
    var messages: [ProviderMessage]
    var context: [String]
    var tools: [String]
    var model: String
    var temperature: Double?
    var budget: TokenBudget?
    var workingDirectory: String?
    var metadata: [String: String]
    var createdAt: Date

    init(
        id: UUID = UUID(),
        runId: UUID,
        agent: Agent,
        messages: [ProviderMessage],
        context: [String] = [],
        tools: [String] = [],
        model: String? = nil,
        temperature: Double? = nil,
        budget: TokenBudget? = nil,
        workingDirectory: String? = nil,
        metadata: [String: String] = [:],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.runId = runId
        self.agentId = agent.id
        self.messages = messages
        self.context = context
        self.tools = tools
        self.model = model ?? agent.model
        self.temperature = temperature
        self.budget = budget
        self.workingDirectory = workingDirectory
        self.metadata = metadata
        self.createdAt = createdAt
    }
}

struct ProviderMessage: Identifiable, Codable, Equatable {
    let id: UUID
    var role: ProviderMessageRole
    var content: String

    init(id: UUID = UUID(), role: ProviderMessageRole, content: String) {
        self.id = id
        self.role = role
        self.content = content
    }
}

enum ProviderMessageRole: String, Codable, Equatable {
    case system
    case user
    case assistant
    case tool
}

struct TokenBudget: Codable, Equatable {
    var maxInputTokens: Int?
    var maxOutputTokens: Int?
}

enum AIEvent: Codable, Equatable {
    case started
    case messageDelta(String)
    case messageCompleted(String)
    case toolCall(name: String, input: String)
    case tokenUsage(TokenUsage)
    case finished
    case error(String)
}
