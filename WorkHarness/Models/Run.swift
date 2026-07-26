//
// Run.swift
// WorkHarness
//
// Created by Auto (Codex) on 07.07.2026.
//

import Foundation

struct Run: Identifiable, Codable, Equatable {
    let id: UUID
    let projectId: UUID?
    var goal: String
    var mode: RunMode
    var status: RunStatus
    var agents: [Agent]
    var events: [RunEvent]
    var artifacts: [RunArtifact]
    var contextAttachments: [RunContextAttachment]
    var multiAgentConfiguration: MultiAgentRunConfiguration?
    var executionBackend: RunExecutionBackendSnapshot?
    var tokenUsage: TokenUsage
    var costUsage: CostUsage
    let createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        projectId: UUID? = nil,
        goal: String,
        mode: RunMode = .simpleChat,
        status: RunStatus = .running,
        agents: [Agent] = [],
        events: [RunEvent] = [],
        artifacts: [RunArtifact] = [],
        contextAttachments: [RunContextAttachment] = [],
        multiAgentConfiguration: MultiAgentRunConfiguration? = nil,
        executionBackend: RunExecutionBackendSnapshot? = nil,
        tokenUsage: TokenUsage = TokenUsage(),
        costUsage: CostUsage = CostUsage(),
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.projectId = projectId
        self.goal = goal
        self.mode = mode
        self.status = status
        self.agents = agents
        self.events = events
        self.artifacts = artifacts
        self.contextAttachments = contextAttachments
        self.multiAgentConfiguration = multiAgentConfiguration
        self.executionBackend = executionBackend
        self.tokenUsage = tokenUsage
        self.costUsage = costUsage
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        projectId = try container.decodeIfPresent(UUID.self, forKey: .projectId)
        goal = try container.decode(String.self, forKey: .goal)
        mode = try container.decode(RunMode.self, forKey: .mode)
        status = try container.decode(RunStatus.self, forKey: .status)
        agents = try container.decode([Agent].self, forKey: .agents)
        events = try container.decode([RunEvent].self, forKey: .events)
        artifacts = try container.decode([RunArtifact].self, forKey: .artifacts)
        contextAttachments = try container.decodeIfPresent(
            [RunContextAttachment].self,
            forKey: .contextAttachments
        ) ?? []
        multiAgentConfiguration = try container.decodeIfPresent(
            MultiAgentRunConfiguration.self,
            forKey: .multiAgentConfiguration
        )
        executionBackend = try container.decodeIfPresent(
            RunExecutionBackendSnapshot.self,
            forKey: .executionBackend
        )
        tokenUsage = try container.decode(TokenUsage.self, forKey: .tokenUsage)
        costUsage = try container.decode(CostUsage.self, forKey: .costUsage)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }
}

struct RunExecutionBackendSnapshot: Codable, Equatable {
    enum Kind: String, Codable, Equatable {
        case agentRuntime
        case provider
    }

    var kind: Kind
    var id: String
    var displayName: String
    var modelId: String?
}

enum RunMode: String, Codable, CaseIterable, Equatable {
    case simpleChat
    case reactToolLoop
    case codingLoop
    case multiAgent
    case remoteTask

    var label: String {
        switch self {
        case .simpleChat: "Simple Chat"
        case .reactToolLoop: "ReAct"
        case .codingLoop: "Coding"
        case .multiAgent: "Multi-Agent"
        case .remoteTask: "Remote"
        }
    }
}

enum RunStatus: String, Codable, CaseIterable, Equatable {
    case queued
    case running
    case waitingForApproval
    case interrupted
    case completed
    case failed
    case cancelled

    var label: String {
        switch self {
        case .queued: "Queued"
        case .running: "Running"
        case .waitingForApproval: "Approval"
        case .interrupted: "Interrupted"
        case .completed: "Completed"
        case .failed: "Failed"
        case .cancelled: "Cancelled"
        }
    }
}

struct TokenUsage: Codable, Equatable {
    var inputTokens: Int
    var outputTokens: Int
    var totalCostUSD: Decimal

    init(inputTokens: Int = 0, outputTokens: Int = 0, totalCostUSD: Decimal = 0) {
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.totalCostUSD = totalCostUSD
    }
}

struct CostUsage: Codable, Equatable {
    var totalUSD: Decimal

    init(totalUSD: Decimal = 0) {
        self.totalUSD = totalUSD
    }
}

struct RunArtifact: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var kind: String
    var path: String?
    var createdAt: Date

    init(id: UUID = UUID(), name: String, kind: String, path: String? = nil, createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.kind = kind
        self.path = path
        self.createdAt = createdAt
    }
}
