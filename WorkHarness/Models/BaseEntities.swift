//
// BaseEntities.swift
// WorkHarness
//
// Created by Auto (Codex) on 07.07.2026.
//

import Foundation

struct Project: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var rootPath: String?

    init(id: UUID = UUID(), name: String, rootPath: String? = nil) {
        self.id = id
        self.name = name
        self.rootPath = rootPath
    }
}

struct AgentRun: Identifiable, Codable, Equatable {
    let id: UUID
    var runId: UUID
    var agentId: UUID
    var status: RunStatus
    var startedAt: Date
    var finishedAt: Date?

    init(id: UUID = UUID(), runId: UUID, agentId: UUID, status: RunStatus = .running, startedAt: Date = Date(), finishedAt: Date? = nil) {
        self.id = id
        self.runId = runId
        self.agentId = agentId
        self.status = status
        self.startedAt = startedAt
        self.finishedAt = finishedAt
    }
}

struct ProviderDefinition: Identifiable, Codable, Equatable {
    var id: String
    var displayName: String
    var capabilities: ProviderCapabilities
}

struct ToolDefinition: Identifiable, Codable, Equatable {
    var id: String
    var displayName: String
    var requiresApproval: Bool
}

struct MemoryItem: Identifiable, Codable, Equatable {
    let id: UUID
    var projectId: UUID?
    var content: String
    var createdAt: Date

    init(id: UUID = UUID(), projectId: UUID? = nil, content: String, createdAt: Date = Date()) {
        self.id = id
        self.projectId = projectId
        self.content = content
        self.createdAt = createdAt
    }
}

struct ContextSnapshot: Identifiable, Codable, Equatable {
    let id: UUID
    var runId: UUID
    var summary: String
    var tokenCount: Int
    var createdAt: Date

    init(id: UUID = UUID(), runId: UUID, summary: String, tokenCount: Int = 0, createdAt: Date = Date()) {
        self.id = id
        self.runId = runId
        self.summary = summary
        self.tokenCount = tokenCount
        self.createdAt = createdAt
    }
}

struct ApprovalRequest: Identifiable, Codable, Equatable {
    let id: UUID
    var runId: UUID
    var reason: String
    var requestedAction: String
    var status: ApprovalStatus
    var createdAt: Date

    init(id: UUID = UUID(), runId: UUID, reason: String, requestedAction: String, status: ApprovalStatus = .pending, createdAt: Date = Date()) {
        self.id = id
        self.runId = runId
        self.reason = reason
        self.requestedAction = requestedAction
        self.status = status
        self.createdAt = createdAt
    }
}

enum ApprovalStatus: String, Codable, Equatable {
    case pending
    case granted
    case rejected
}

struct SettingsProfile: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var defaultProviderId: String
    var requiresApprovalForShell: Bool
    var requiresApprovalForWrites: Bool

    init(
        id: UUID = UUID(),
        name: String = "Default",
        defaultProviderId: String = "mock.local",
        requiresApprovalForShell: Bool = true,
        requiresApprovalForWrites: Bool = true
    ) {
        self.id = id
        self.name = name
        self.defaultProviderId = defaultProviderId
        self.requiresApprovalForShell = requiresApprovalForShell
        self.requiresApprovalForWrites = requiresApprovalForWrites
    }
}
