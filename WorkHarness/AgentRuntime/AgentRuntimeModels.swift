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
    func configure(modelId: String?)
    func connect() async throws -> AgentSession
    func disconnect(sessionId: UUID) async
    func capabilities(sessionId: UUID) -> AgentCapabilities?
    func run(task: AgentTask, sessionId: UUID) async throws -> AgentExecution
    func cancel(sessionId: UUID) async
    func pause(sessionId: UUID) async throws
    func resume(sessionId: UUID) async throws
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
