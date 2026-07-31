//
// ContextBuilderProtocol.swift
// WorkHarness
//
// Created by Auto (Codex) on 09.07.2026.
//

import Foundation

@MainActor
protocol ContextBuilderProtocol: AnyObject {
    func buildSnapshot(from input: ContextBuildInput) throws -> ContextSnapshot
}

struct ContextBuildInput: Equatable {
    var runId: UUID
    var agent: Agent
    var providerId: String
    var userMessage: String
    var currentProject: Project?
    var rootPath: String?
    var recentRunSummary: String?
    var contextFoldSummary: ContextFoldSummary?
    var selectedFiles: [String]
    var contextAttachments: [RunContextAttachment]
    var memoryItems: [MemoryItem]
    var ragResults: [RAGCitation]
    var tokenBudget: TokenBudget?
    var providerContextWindowTokens: Int?
    var safetyMode: SafetyMode
    var deliveryMode: ContextDeliveryMode

    init(
        runId: UUID,
        agent: Agent,
        providerId: String,
        userMessage: String,
        currentProject: Project? = nil,
        rootPath: String? = nil,
        recentRunSummary: String? = nil,
        contextFoldSummary: ContextFoldSummary? = nil,
        selectedFiles: [String] = [],
        contextAttachments: [RunContextAttachment] = [],
        memoryItems: [MemoryItem] = [],
        ragResults: [RAGCitation] = [],
        tokenBudget: TokenBudget? = nil,
        providerContextWindowTokens: Int? = nil,
        safetyMode: SafetyMode = AppSettingsDefaults.defaultSafetyMode,
        deliveryMode: ContextDeliveryMode = .unsupported
    ) {
        self.runId = runId
        self.agent = agent
        self.providerId = providerId
        self.userMessage = userMessage
        self.currentProject = currentProject
        self.rootPath = rootPath
        self.recentRunSummary = recentRunSummary
        self.contextFoldSummary = contextFoldSummary
        self.selectedFiles = selectedFiles
        self.contextAttachments = contextAttachments
        self.memoryItems = memoryItems
        self.ragResults = ragResults
        self.tokenBudget = tokenBudget
        self.providerContextWindowTokens = providerContextWindowTokens
        self.safetyMode = safetyMode
        self.deliveryMode = deliveryMode
    }
}
