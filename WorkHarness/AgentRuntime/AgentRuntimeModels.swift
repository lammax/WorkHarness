//
// AgentRuntimeModels.swift
// WorkHarness
//
// Created by Auto (Codex) on 10.07.2026.
//

import Foundation

enum AgentCapability: String, Codable, CaseIterable, Equatable {
    case canEditFiles
    case canSearch
    case canPlan
    case canUseTools
    case canStreamTokens
    case canExecuteTerminal
    case canSpawnAgents
    case canApproveChanges
    case canReadGit
    case canRunTests
    case canOpenDiff
    case canIndexWorkspace
    case canGenerateImages
}

struct AgentCapabilities: Codable, Equatable {
    var values: Set<AgentCapability>

    init(_ values: Set<AgentCapability> = []) {
        self.values = values
    }

    func supports(_ capability: AgentCapability) -> Bool {
        values.contains(capability)
    }
}

enum AgentRuntimeTransportKind: String, Codable, Equatable {
    case acp
    case cli

    var label: String {
        switch self {
        case .acp:
            "ACP"
        case .cli:
            "CLI"
        }
    }
}

enum AgentRuntimeAuthenticationKind: String, Codable, Equatable {
    case notRequired
    case runtimeManaged

    var label: String {
        switch self {
        case .notRequired:
            "No sign-in required"
        case .runtimeManaged:
            "Sign-in managed by runtime"
        }
    }
}

struct AgentRuntimeModelOption: Identifiable, Codable, Equatable {
    let id: String
    let title: String
}

struct AgentModelRoutingDescriptor: Equatable {
    let defaultFastModelId: String
    let defaultFallbackModelId: String
    let defaultPromptLengthThreshold: Int
    let fallbackKeywords: [String]
    let multipleRequirementsThreshold: Int
}

struct AgentRuntimeDescriptor: Equatable {
    let id: String
    let displayName: String
    let transport: AgentRuntimeTransportKind
    let authentication: AgentRuntimeAuthenticationKind
    let modelOptions: [AgentRuntimeModelOption]
    let defaultModelId: String?
    let modelRouting: AgentModelRoutingDescriptor?
    let contextDeliveryMode: ContextDeliveryMode
    let capabilities: AgentCapabilities
    let contextWindowTokens: Int?
    let supportsUsageReporting: Bool?
    let supportsCancellation: Bool?

    init(
        id: String,
        displayName: String,
        transport: AgentRuntimeTransportKind,
        authentication: AgentRuntimeAuthenticationKind = .notRequired,
        modelOptions: [AgentRuntimeModelOption] = [],
        defaultModelId: String? = nil,
        modelRouting: AgentModelRoutingDescriptor? = nil,
        contextDeliveryMode: ContextDeliveryMode = .unsupported,
        capabilities: AgentCapabilities = AgentCapabilities(),
        contextWindowTokens: Int? = nil,
        supportsUsageReporting: Bool? = nil,
        supportsCancellation: Bool? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.transport = transport
        self.authentication = authentication
        self.modelOptions = modelOptions
        self.defaultModelId = defaultModelId
        self.modelRouting = modelRouting
        self.contextDeliveryMode = contextDeliveryMode
        self.capabilities = capabilities
        self.contextWindowTokens = contextWindowTokens
        self.supportsUsageReporting = supportsUsageReporting
        self.supportsCancellation = supportsCancellation
    }

    func contextDeliveryPlan(reservedOutputTokens: Int?) -> ContextDeliveryPlan {
        ContextDeliveryPlan(
            mode: contextDeliveryMode,
            capabilities: ContextBoundaryCapabilities(
                contextWindowTokens: contextWindowTokens,
                reservedOutputTokens: reservedOutputTokens,
                streaming: InferenceCapabilitySupport(
                    capabilities.supports(.canStreamTokens)
                ),
                tools: InferenceCapabilitySupport(
                    capabilities.supports(.canUseTools)
                ),
                usageReporting: InferenceCapabilitySupport(supportsUsageReporting),
                cancellation: InferenceCapabilitySupport(supportsCancellation)
            )
        )
    }
}

struct AgentTask: Identifiable, Codable, Equatable {
    let id: UUID
    var runId: UUID
    var prompt: String
    var context: ContextSnapshot?
    var workingDirectory: String?

    init(
        id: UUID = UUID(),
        runId: UUID,
        prompt: String,
        context: ContextSnapshot? = nil,
        workingDirectory: String? = nil
    ) {
        self.id = id
        self.runId = runId
        self.prompt = prompt
        self.context = context
        self.workingDirectory = workingDirectory
    }
}

extension AgentTask {
    var renderedPrompt: String {
        guard let context, !context.contextItems.isEmpty else {
            return prompt
        }
        return """
        Run context:
        \(context.contextItems.joined(separator: "\n\n"))

        Task:
        \(prompt)
        """
    }
}

struct AgentResponse: Codable, Equatable {
    var message: String
    var tokenUsage: TokenUsage?
    var artifacts: [RunArtifact]
}

enum AgentEvent: Equatable {
    case started
    case thinking(String)
    case textDelta(String)
    case messageCompleted(String)
    case toolCallRequested(name: String, input: String)
    case fileChanged(path: String)
    case approvalRequested(summary: String)
    case tokenUsage(TokenUsage)
    case artifactCreated(RunArtifact)
    case finished(AgentResponse)
    case failed(String)
}

enum AgentSessionState: String, Codable, Equatable {
    case connecting
    case connected
    case running
    case paused
    case completed
    case failed
    case cancelled
}

struct AgentSession: Identifiable, Codable, Equatable {
    let id: UUID
    var agentId: String
    var state: AgentSessionState
    var capabilities: AgentCapabilities
    var startedAt: Date
    var finishedAt: Date?
    var tokenUsage: TokenUsage
    var artifacts: [RunArtifact]

    init(
        id: UUID = UUID(),
        agentId: String,
        state: AgentSessionState = .connecting,
        capabilities: AgentCapabilities = AgentCapabilities(),
        startedAt: Date = Date(),
        finishedAt: Date? = nil,
        tokenUsage: TokenUsage = TokenUsage(),
        artifacts: [RunArtifact] = []
    ) {
        self.id = id
        self.agentId = agentId
        self.state = state
        self.capabilities = capabilities
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        self.tokenUsage = tokenUsage
        self.artifacts = artifacts
    }
}

struct AgentExecution {
    let session: AgentSession
    let events: AsyncThrowingStream<AgentEvent, Error>
}

@MainActor
protocol AgentRuntime: AnyObject {
    var id: String { get }
    var displayName: String { get }
    var descriptor: AgentRuntimeDescriptor { get }
    func configure(modelId: String?)
    func configure(modelId: String?, runId: UUID?, workingDirectory: String?)
    func connect() async throws -> AgentSession
    func disconnect(sessionId: UUID) async
    func capabilities(sessionId: UUID) -> AgentCapabilities?
    func run(task: AgentTask, sessionId: UUID) async throws -> AgentExecution
    func cancel(sessionId: UUID) async
    func pause(sessionId: UUID) async throws
    func resume(sessionId: UUID) async throws
}

extension AgentRuntime {
    var descriptor: AgentRuntimeDescriptor {
        AgentRuntimeDescriptor(
            id: id,
            displayName: displayName,
            transport: .cli
        )
    }

    func configure(modelId: String?, runId: UUID?) {
        configure(modelId: modelId)
    }

    func configure(modelId: String?, runId: UUID?, workingDirectory: String?) {
        configure(modelId: modelId, runId: runId)
    }
}

@MainActor
final class AgentRuntimeRegistry {
    private var runtimesById: [String: AgentRuntime] = [:]

    var runtimes: [AgentRuntime] {
        runtimesById.values.sorted { $0.id < $1.id }
    }

    func register(_ runtime: AgentRuntime) {
        runtimesById[runtime.id] = runtime
    }

    func runtime(id: String) -> AgentRuntime? {
        runtimesById[id]
    }
}

@MainActor
protocol AgentFactory {
    func makeRuntime() -> AgentRuntime
}
