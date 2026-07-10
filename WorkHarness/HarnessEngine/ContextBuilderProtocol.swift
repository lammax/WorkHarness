//
// ContextBuilderProtocol.swift
// WorkHarness
//
// Created by Auto (Codex) on 09.07.2026.
//

import Foundation

@MainActor
protocol ContextBuilderProtocol: AnyObject {
    func buildSnapshot(from input: ContextBuildInput) -> ContextSnapshot
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
    var memoryItems: [String]
    var tokenBudget: TokenBudget?

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
        memoryItems: [String] = [],
        tokenBudget: TokenBudget? = nil
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
        self.memoryItems = memoryItems
        self.tokenBudget = tokenBudget
    }
}
