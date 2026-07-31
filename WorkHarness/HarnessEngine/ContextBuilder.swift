//
// ContextBuilder.swift
// WorkHarness
//
// Created by Auto (Codex) on 09.07.2026.
//

import Foundation

@MainActor
final class ContextBuilder: ContextBuilderProtocol {
    let tokenEstimator: any ContextTokenEstimatorProtocol
    let budgetPolicy: ContextBudgetPolicy

    static let autoApprovalInstruction = """
    [WORKHARNESS_APPROVAL_MODE: AUTO_INSIDE_PROJECT]
    Auto-approval is enabled for eligible actions inside the current project. When the user's task requests or clearly implies a workspace change, invoke the appropriate WorkHarness MCP tool immediately. Do not ask for confirmation in prose and do not stop before the tool call: WorkHarness applies its approval policy automatically. This does not expand the user's requested scope or permit access outside the project root; the WorkHarness MCP gateway remains the authority for execution.
    """

    init() {
        self.tokenEstimator = ApproximateContextTokenEstimator()
        self.budgetPolicy = ContextBudgetPolicy()
    }

    init(tokenEstimator: any ContextTokenEstimatorProtocol) {
        self.tokenEstimator = tokenEstimator
        self.budgetPolicy = ContextBudgetPolicy()
    }

    init(
        tokenEstimator: any ContextTokenEstimatorProtocol,
        budgetPolicy: ContextBudgetPolicy
    ) {
        self.tokenEstimator = tokenEstimator
        self.budgetPolicy = budgetPolicy
    }

    func buildSnapshot(from input: ContextBuildInput) throws -> ContextSnapshot {
        try Task.checkCancellation()
        let project = input.currentProject
        let rootPath = input.rootPath ?? project?.rootPath
        var sections: [ContextSection] = []

        func append(_ section: ContextSection?) {
            guard var section else { return }
            section.order = sections.count
            sections.append(section)
        }

        if let project {
            append(try projectIdentitySection(for: project))
        }

        if let rootPath, !rootPath.isEmpty {
            append(try projectRootSection(path: rootPath, projectId: project?.id))
        }

        if input.safetyMode == .autoInsideSandbox {
            append(try safetyInstructionSection(mode: input.safetyMode))
        }

        if let recentRunSummary = input.recentRunSummary?.trimmingCharacters(in: .whitespacesAndNewlines),
           !recentRunSummary.isEmpty {
            append(try recentRunSummarySection(summary: recentRunSummary, runId: input.runId))
        }

        if let contextFoldSummary = input.contextFoldSummary {
            append(try foldedContextSection(summary: contextFoldSummary, runId: input.runId))
        }

        if !input.selectedFiles.isEmpty {
            append(try selectedFilesSection(paths: input.selectedFiles))
        }

        for attachment in input.contextAttachments {
            append(try attachmentSection(for: attachment))
        }

        if !input.memoryItems.isEmpty {
            append(try projectMemorySection(items: input.memoryItems, projectId: project?.id))
        }

        if !input.ragResults.isEmpty {
            append(try retrievalResultsSection(citations: input.ragResults))
        }

        let objectiveSource = try makeObjectiveSource(
            content: input.userMessage,
            runId: input.runId
        )
        let windowConstraint = ContextWindowConstraint(
            configuredMaxInputTokens: input.tokenBudget?.maxInputTokens,
            reservedOutputTokens: input.tokenBudget?.maxOutputTokens,
            providerContextWindowTokens: input.providerContextWindowTokens
        )
        let budgetResult = try budgetPolicy.apply(
            objective: objectiveSource,
            sections: sections,
            constraint: windowConstraint
        )
        let includedKinds = Set(budgetResult.sections.map(\.kind))
        let includedSectionIds = Set(budgetResult.sections.map(\.id))
        let contextItems = budgetResult.sections.map(\.content)
        let summary = contextItems.isEmpty
            ? "No additional context was included."
            : contextItems.joined(separator: "\n")
        let includedSummaries = [
            includedKinds.contains(.recentRunSummary) ? input.recentRunSummary : nil,
            includedKinds.contains(.foldedContext) ? input.contextFoldSummary?.renderedText : nil
        ].compactMap { $0 }
        let includedFiles = (
            includedKinds.contains(.selectedFiles) ? input.selectedFiles : []
        ) + input.contextAttachments.compactMap { attachment in
            includedSectionIds.contains("attachment:\(attachment.id.uuidString)")
                ? attachment.name
                : nil
        }

        return ContextSnapshot(
            runId: input.runId,
            agentId: input.agent.id,
            providerId: input.providerId,
            userMessage: input.userMessage,
            objectiveSource: objectiveSource,
            projectId: project?.id,
            projectName: project?.name,
            rootPath: rootPath,
            summary: summary,
            contextItems: contextItems,
            includedFiles: includedFiles,
            includedMemories: includedKinds.contains(.projectMemory) ? input.memoryItems : [],
            includedRAGResults: includedKinds.contains(.retrievalResults) ? input.ragResults : [],
            includedSummaries: includedSummaries,
            sections: budgetResult.sections,
            omissions: budgetResult.omissions,
            windowConstraint: windowConstraint,
            deliveryMode: input.deliveryMode,
            tokenCount: budgetResult.sections.reduce(0) { $0 + $1.estimatedTokenCount },
            estimatedInputTokenCount: budgetResult.estimatedInputTokenCount
        )
    }

    func estimateTokenCount(for content: String, sourceId: String) throws -> Int {
        do {
            return try tokenEstimator.estimateTokenCount(for: content)
        } catch {
            throw ContextBuildError.tokenEstimationFailed(
                sourceId: sourceId,
                message: error.localizedDescription
            )
        }
    }
}
