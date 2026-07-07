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
        self.tokenUsage = tokenUsage
        self.costUsage = costUsage
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
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
    case completed
    case failed
    case cancelled

    var label: String {
        switch self {
        case .queued: "Queued"
        case .running: "Running"
        case .waitingForApproval: "Approval"
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
