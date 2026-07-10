//
// ContextBuilder.swift
// WorkHarness
//
// Created by Auto (Codex) on 09.07.2026.
//

import Foundation

@MainActor
final class ContextBuilder: ContextBuilderProtocol {
    func buildSnapshot(from input: ContextBuildInput) -> ContextSnapshot {
        let project = input.currentProject
        let rootPath = input.rootPath ?? project?.rootPath
        var contextItems: [String] = []
        var includedSummaries: [String] = []

        if let project {
            contextItems.append("Current project: \(project.name)")
        }

        if let rootPath, !rootPath.isEmpty {
            contextItems.append("Project root: \(rootPath)")
        }

        if let recentRunSummary = input.recentRunSummary?.trimmingCharacters(in: .whitespacesAndNewlines),
           !recentRunSummary.isEmpty {
            contextItems.append("Recent run summary: \(recentRunSummary)")
            includedSummaries.append(recentRunSummary)
        }

        if let contextFoldSummary = input.contextFoldSummary {
            contextItems.append("Folded context:\n\(contextFoldSummary.renderedText)")
            includedSummaries.append(contextFoldSummary.renderedText)
        }

        if !input.selectedFiles.isEmpty {
            contextItems.append("Selected files: \(input.selectedFiles.joined(separator: ", "))")
        }

        if !input.memoryItems.isEmpty {
            contextItems.append("Project memory:\n\(input.memoryItems.joined(separator: "\n"))")
        }

        if !input.ragResults.isEmpty {
            let results = input.ragResults.map { citation in
                let quote = citation.quote.map { "\nQuote: \($0)" } ?? ""
                return "\(citation.displayText)\(quote)"
            }
            contextItems.append("RAG results:\n\(results.joined(separator: "\n"))")
        }

        let summary = contextItems.isEmpty
            ? "No additional context was included."
            : contextItems.joined(separator: "\n")

        return ContextSnapshot(
            runId: input.runId,
            agentId: input.agent.id,
            providerId: input.providerId,
            userMessage: input.userMessage,
            projectId: project?.id,
            projectName: project?.name,
            rootPath: rootPath,
            summary: summary,
            contextItems: contextItems,
            includedFiles: input.selectedFiles,
            includedMemories: input.memoryItems,
            includedRAGResults: input.ragResults,
            includedSummaries: includedSummaries,
            tokenCount: estimateTokenCount(for: contextItems)
        )
    }

    private func estimateTokenCount(for contextItems: [String]) -> Int {
        contextItems.reduce(0) { partialResult, item in
            partialResult + max(1, item.split(whereSeparator: \.isWhitespace).count)
        }
    }
}
