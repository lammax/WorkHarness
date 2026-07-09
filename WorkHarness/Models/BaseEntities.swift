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
    var description: String
    var permission: ToolPermission
    var inputSchema: [ToolInputField]
    var requiresApproval: Bool

    init(
        id: String,
        displayName: String,
        description: String = "",
        permission: ToolPermission = .readOnly,
        inputSchema: [ToolInputField] = [],
        requiresApproval: Bool = false
    ) {
        self.id = id
        self.displayName = displayName
        self.description = description
        self.permission = permission
        self.inputSchema = inputSchema
        self.requiresApproval = requiresApproval
    }
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
    var agentId: UUID?
    var providerId: String?
    var userMessage: String
    var projectId: UUID?
    var projectName: String?
    var rootPath: String?
    var summary: String
    var contextItems: [String]
    var includedFiles: [String]
    var includedMemories: [String]
    var includedSummaries: [String]
    var tokenCount: Int
    var createdAt: Date

    init(
        id: UUID = UUID(),
        runId: UUID,
        agentId: UUID? = nil,
        providerId: String? = nil,
        userMessage: String = "",
        projectId: UUID? = nil,
        projectName: String? = nil,
        rootPath: String? = nil,
        summary: String,
        contextItems: [String] = [],
        includedFiles: [String] = [],
        includedMemories: [String] = [],
        includedSummaries: [String] = [],
        tokenCount: Int = 0,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.runId = runId
        self.agentId = agentId
        self.providerId = providerId
        self.userMessage = userMessage
        self.projectId = projectId
        self.projectName = projectName
        self.rootPath = rootPath
        self.summary = summary
        self.contextItems = contextItems
        self.includedFiles = includedFiles
        self.includedMemories = includedMemories
        self.includedSummaries = includedSummaries
        self.tokenCount = tokenCount
        self.createdAt = createdAt
    }
}

struct ApprovalRequest: Identifiable, Codable, Equatable {
    let id: UUID
    var runId: UUID
    var title: String
    var summary: String
    var mode: SafetyMode
    var status: ApprovalStatus
    var createdAt: Date
    var decidedAt: Date?

    init(
        id: UUID = UUID(),
        runId: UUID,
        title: String,
        summary: String,
        mode: SafetyMode,
        status: ApprovalStatus = .pending,
        createdAt: Date = Date(),
        decidedAt: Date? = nil
    ) {
        self.id = id
        self.runId = runId
        self.title = title
        self.summary = summary
        self.mode = mode
        self.status = status
        self.createdAt = createdAt
        self.decidedAt = decidedAt
    }
}

enum ApprovalStatus: String, Codable, CaseIterable, Equatable {
    case pending
    case granted
    case rejected

    var label: String {
        switch self {
        case .pending: "Pending"
        case .granted: "Granted"
        case .rejected: "Rejected"
        }
    }
}

enum SafetyMode: String, Codable, CaseIterable, Equatable {
    case readOnly
    case askBeforeWrite
    case askBeforeShell
    case autoInsideSandbox

    var label: String {
        switch self {
        case .readOnly: "Read Only"
        case .askBeforeWrite: "Ask Before Write"
        case .askBeforeShell: "Ask Before Shell"
        case .autoInsideSandbox: "Auto Inside Sandbox"
        }
    }
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
