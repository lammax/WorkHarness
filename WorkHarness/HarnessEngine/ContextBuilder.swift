//
// ContextBuilder.swift
// WorkHarness
//
// Created by Auto (Codex) on 09.07.2026.
//

import Foundation

@MainActor
final class ContextBuilder: ContextBuilderProtocol {
    static let autoApprovalInstruction = """
    [WORKHARNESS_APPROVAL_MODE: AUTO_INSIDE_PROJECT]
    Auto-approval is enabled for eligible actions inside the current project. When the user's task requests or clearly implies a workspace change, invoke the appropriate WorkHarness MCP tool immediately. Do not ask for confirmation in prose and do not stop before the tool call: WorkHarness applies its approval policy automatically. This does not expand the user's requested scope or permit access outside the project root; the WorkHarness MCP gateway remains the authority for execution.
    """

    func buildSnapshot(from input: ContextBuildInput) -> ContextSnapshot {
        let project = input.currentProject
        let rootPath = input.rootPath ?? project?.rootPath
        var sections: [ContextSection] = []
        var includedSummaries: [String] = []

        func append(_ section: ContextSection?) {
            guard var section else { return }
            section.order = sections.count
            sections.append(section)
        }

        if let project {
            append(projectIdentitySection(for: project))
        }

        if let rootPath, !rootPath.isEmpty {
            append(projectRootSection(path: rootPath, projectId: project?.id))
        }

        if input.safetyMode == .autoInsideSandbox {
            append(safetyInstructionSection(mode: input.safetyMode))
        }

        if let recentRunSummary = input.recentRunSummary?.trimmingCharacters(in: .whitespacesAndNewlines),
           !recentRunSummary.isEmpty {
            append(recentRunSummarySection(summary: recentRunSummary, runId: input.runId))
            includedSummaries.append(recentRunSummary)
        }

        if let contextFoldSummary = input.contextFoldSummary {
            append(foldedContextSection(summary: contextFoldSummary, runId: input.runId))
            includedSummaries.append(contextFoldSummary.renderedText)
        }

        if !input.selectedFiles.isEmpty {
            append(selectedFilesSection(paths: input.selectedFiles))
        }

        for attachment in input.contextAttachments {
            append(attachmentSection(for: attachment))
        }

        if !input.memoryItems.isEmpty {
            append(projectMemorySection(items: input.memoryItems, projectId: project?.id))
        }

        if !input.ragResults.isEmpty {
            append(retrievalResultsSection(citations: input.ragResults))
        }

        let contextItems = sections.map(\.content)
        let summary = contextItems.isEmpty
            ? "No additional context was included."
            : contextItems.joined(separator: "\n")

        return ContextSnapshot(
            runId: input.runId,
            agentId: input.agent.id,
            providerId: input.providerId,
            userMessage: input.userMessage,
            objectiveSource: makeObjectiveSource(
                content: input.userMessage,
                runId: input.runId
            ),
            projectId: project?.id,
            projectName: project?.name,
            rootPath: rootPath,
            summary: summary,
            contextItems: contextItems,
            includedFiles: input.selectedFiles + input.contextAttachments.map(\.name),
            includedMemories: input.memoryItems,
            includedRAGResults: input.ragResults,
            includedSummaries: includedSummaries,
            sections: sections,
            omissions: [],
            windowConstraint: ContextWindowConstraint(
                configuredMaxInputTokens: input.tokenBudget?.maxInputTokens,
                reservedOutputTokens: input.tokenBudget?.maxOutputTokens,
                providerContextWindowTokens: input.providerContextWindowTokens
            ),
            deliveryMode: input.deliveryMode,
            tokenCount: estimateTokenCount(for: contextItems)
        )
    }

    func estimateTokenCount(for contextItems: [String]) -> Int {
        contextItems.reduce(0) { $0 + estimateTokenCount(for: $1) }
    }

    func estimateTokenCount(for content: String) -> Int {
        max(1, content.split(whereSeparator: \.isWhitespace).count)
    }
}
