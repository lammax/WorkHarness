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

enum MemoryScope: String, Codable, CaseIterable, Equatable {
    case project
}

enum ContextDeliveryMode: String, Codable, CaseIterable, Equatable {
    case structuredMessages
    case renderedPrompt
    case runtimeManaged
    case unsupported
}

struct ContextSnapshot: Identifiable, Codable, Equatable {
    let id: UUID
    var runId: UUID
    var agentId: UUID?
    var providerId: String?
    var userMessage: String
    var objectiveSource: ContextSourceReference?
    var projectId: UUID?
    var projectName: String?
    var rootPath: String?
    var summary: String
    var contextItems: [String]
    var includedFiles: [String]
    var includedMemories: [String]
    var includedRAGResults: [RAGCitation]
    var includedSummaries: [String]
    var sections: [ContextSection]
    var omissions: [ContextOmission]
    var windowConstraint: ContextWindowConstraint
    var deliveryMode: ContextDeliveryMode
    var tokenCount: Int
    var createdAt: Date

    init(
        id: UUID = UUID(),
        runId: UUID,
        agentId: UUID? = nil,
        providerId: String? = nil,
        userMessage: String = "",
        objectiveSource: ContextSourceReference? = nil,
        projectId: UUID? = nil,
        projectName: String? = nil,
        rootPath: String? = nil,
        summary: String,
        contextItems: [String] = [],
        includedFiles: [String] = [],
        includedMemories: [String] = [],
        includedRAGResults: [RAGCitation] = [],
        includedSummaries: [String] = [],
        sections: [ContextSection] = [],
        omissions: [ContextOmission] = [],
        windowConstraint: ContextWindowConstraint = ContextWindowConstraint(
            configuredMaxInputTokens: nil,
            reservedOutputTokens: nil,
            providerContextWindowTokens: nil
        ),
        deliveryMode: ContextDeliveryMode = .unsupported,
        tokenCount: Int = 0,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.runId = runId
        self.agentId = agentId
        self.providerId = providerId
        self.userMessage = userMessage
        self.objectiveSource = objectiveSource
        self.projectId = projectId
        self.projectName = projectName
        self.rootPath = rootPath
        self.summary = summary
        self.contextItems = contextItems
        self.includedFiles = includedFiles
        self.includedMemories = includedMemories
        self.includedRAGResults = includedRAGResults
        self.includedSummaries = includedSummaries
        self.sections = sections
        self.omissions = omissions
        self.windowConstraint = windowConstraint
        self.deliveryMode = deliveryMode
        self.tokenCount = tokenCount
        self.createdAt = createdAt
    }

    var objective: String {
        userMessage
    }
}

extension ContextSnapshot {
    private enum CodingKeys: String, CodingKey {
        case id
        case runId
        case agentId
        case providerId
        case userMessage
        case objectiveSource
        case projectId
        case projectName
        case rootPath
        case summary
        case contextItems
        case includedFiles
        case includedMemories
        case includedRAGResults
        case includedSummaries
        case sections
        case omissions
        case windowConstraint
        case deliveryMode
        case tokenCount
        case createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        runId = try container.decode(UUID.self, forKey: .runId)
        agentId = try container.decodeIfPresent(UUID.self, forKey: .agentId)
        providerId = try container.decodeIfPresent(String.self, forKey: .providerId)
        userMessage = try container.decodeIfPresent(String.self, forKey: .userMessage) ?? ""
        objectiveSource = try container.decodeIfPresent(
            ContextSourceReference.self,
            forKey: .objectiveSource
        )
        projectId = try container.decodeIfPresent(UUID.self, forKey: .projectId)
        projectName = try container.decodeIfPresent(String.self, forKey: .projectName)
        rootPath = try container.decodeIfPresent(String.self, forKey: .rootPath)
        summary = try container.decode(String.self, forKey: .summary)
        contextItems = try container.decodeIfPresent([String].self, forKey: .contextItems) ?? []
        includedFiles = try container.decodeIfPresent([String].self, forKey: .includedFiles) ?? []
        includedMemories = try container.decodeIfPresent([String].self, forKey: .includedMemories) ?? []
        includedRAGResults = try container.decodeIfPresent([RAGCitation].self, forKey: .includedRAGResults) ?? []
        includedSummaries = try container.decodeIfPresent([String].self, forKey: .includedSummaries) ?? []
        sections = try container.decodeIfPresent([ContextSection].self, forKey: .sections) ?? []
        omissions = try container.decodeIfPresent([ContextOmission].self, forKey: .omissions) ?? []
        windowConstraint = try container.decodeIfPresent(
            ContextWindowConstraint.self,
            forKey: .windowConstraint
        ) ?? ContextWindowConstraint(
            configuredMaxInputTokens: nil,
            reservedOutputTokens: nil,
            providerContextWindowTokens: nil
        )
        deliveryMode = try container.decodeIfPresent(
            ContextDeliveryMode.self,
            forKey: .deliveryMode
        ) ?? .unsupported
        tokenCount = try container.decodeIfPresent(Int.self, forKey: .tokenCount) ?? 0
        createdAt = try container.decode(Date.self, forKey: .createdAt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(runId, forKey: .runId)
        try container.encodeIfPresent(agentId, forKey: .agentId)
        try container.encodeIfPresent(providerId, forKey: .providerId)
        try container.encode(userMessage, forKey: .userMessage)
        try container.encodeIfPresent(objectiveSource, forKey: .objectiveSource)
        try container.encodeIfPresent(projectId, forKey: .projectId)
        try container.encodeIfPresent(projectName, forKey: .projectName)
        try container.encodeIfPresent(rootPath, forKey: .rootPath)
        try container.encode(summary, forKey: .summary)
        try container.encode(contextItems, forKey: .contextItems)
        try container.encode(includedFiles, forKey: .includedFiles)
        try container.encode(includedMemories, forKey: .includedMemories)
        try container.encode(includedRAGResults, forKey: .includedRAGResults)
        try container.encode(includedSummaries, forKey: .includedSummaries)
        try container.encode(sections, forKey: .sections)
        try container.encode(omissions, forKey: .omissions)
        try container.encode(windowConstraint, forKey: .windowConstraint)
        try container.encode(deliveryMode, forKey: .deliveryMode)
        try container.encode(tokenCount, forKey: .tokenCount)
        try container.encode(createdAt, forKey: .createdAt)
    }
}

struct ContextFoldSummary: Codable, Equatable {
    var runSummary: String
    var conversationSummary: String
    var decisionLog: [String]
    var currentState: String
    var failedAttempts: [String]
    var nextActions: [String]
    var sourceEventCount: Int
    var createdAt: Date

    var renderedText: String {
        [
            "Run summary: \(runSummary)",
            "Conversation: \(conversationSummary)",
            "Decisions: \(decisionLog.joined(separator: "; "))",
            "Current state: \(currentState)",
            "Failed attempts: \(failedAttempts.joined(separator: "; "))",
            "Next actions: \(nextActions.joined(separator: "; "))"
        ].joined(separator: "\n")
    }

    init(
        runSummary: String,
        conversationSummary: String,
        decisionLog: [String] = [],
        currentState: String,
        failedAttempts: [String] = [],
        nextActions: [String] = [],
        sourceEventCount: Int,
        createdAt: Date = Date()
    ) {
        self.runSummary = runSummary
        self.conversationSummary = conversationSummary
        self.decisionLog = decisionLog
        self.currentState = currentState
        self.failedAttempts = failedAttempts
        self.nextActions = nextActions
        self.sourceEventCount = sourceEventCount
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
