//
// ContextBuilder+Sections.swift
// WorkHarness
//
// Created by Auto (Codex) on 31.07.2026.
//

import Foundation

extension ContextBuilder {
    func makeObjectiveSource(content: String, runId: UUID) -> ContextSourceReference {
        makeSource(
            id: "run:\(runId.uuidString):objective",
            kind: .objective,
            purpose: "State the current agent objective.",
            informationClass: .requiredNow,
            priority: .critical,
            freshness: .current,
            content: content,
            retentionPolicy: .run,
            containsSensitiveData: true
        )
    }

    func projectIdentitySection(for project: Project) -> ContextSection {
        let content = "Current project: \(project.name)"
        return makeSection(
            id: "project-identity",
            kind: .projectIdentity,
            content: content,
            priority: .high,
            sources: [
                makeSource(
                    id: "project:\(project.id.uuidString)",
                    kind: .project,
                    purpose: "Identify the current workspace.",
                    informationClass: .persistentState,
                    priority: .high,
                    freshness: .current,
                    content: content,
                    retentionPolicy: .project,
                    containsSensitiveData: false
                )
            ]
        )
    }

    func projectRootSection(path: String, projectId: UUID?) -> ContextSection {
        let content = "Project root: \(path)"
        return makeSection(
            id: "project-root",
            kind: .projectRoot,
            content: content,
            priority: .high,
            sources: [
                makeSource(
                    id: "project-root:\(projectId?.uuidString ?? "unscoped")",
                    kind: .projectRoot,
                    purpose: "Locate the current workspace.",
                    informationClass: .persistentState,
                    priority: .high,
                    freshness: .current,
                    content: content,
                    retentionPolicy: .project,
                    containsSensitiveData: true
                )
            ]
        )
    }

    func safetyInstructionSection(mode: SafetyMode) -> ContextSection {
        makeSection(
            id: "safety-instruction",
            kind: .safetyInstruction,
            content: Self.autoApprovalInstruction,
            priority: .critical,
            sources: [
                makeSource(
                    id: "safety-policy:\(mode.rawValue)",
                    kind: .safetyPolicy,
                    purpose: "Apply the active WorkHarness approval policy.",
                    informationClass: .requiredNow,
                    priority: .critical,
                    freshness: .staticValue,
                    content: Self.autoApprovalInstruction,
                    retentionPolicy: .request,
                    containsSensitiveData: false
                )
            ]
        )
    }

    func recentRunSummarySection(summary: String, runId: UUID) -> ContextSection {
        let content = "Recent run summary: \(summary)"
        return makeSection(
            id: "recent-run-summary",
            kind: .recentRunSummary,
            content: content,
            priority: .high,
            sources: [
                makeSource(
                    id: "run:\(runId.uuidString):recent-summary",
                    kind: .recentRunSummary,
                    purpose: "Resume relevant prior run state.",
                    informationClass: .requiredNow,
                    priority: .high,
                    freshness: .current,
                    content: content,
                    retentionPolicy: .run,
                    containsSensitiveData: true
                )
            ]
        )
    }

    func foldedContextSection(
        summary: ContextFoldSummary,
        runId: UUID
    ) -> ContextSection {
        let content = "Folded context:\n\(summary.renderedText)"
        return makeSection(
            id: "folded-context",
            kind: .foldedContext,
            content: content,
            priority: .high,
            sources: [
                makeSource(
                    id: "run:\(runId.uuidString):folded-context",
                    kind: .foldedContext,
                    purpose: "Preserve compacted decisions and unfinished state.",
                    informationClass: .requiredNow,
                    priority: .high,
                    freshness: .current,
                    content: content,
                    retentionPolicy: .run,
                    containsSensitiveData: true
                )
            ]
        )
    }

    func selectedFilesSection(paths: [String]) -> ContextSection {
        let content = "Selected files: \(paths.joined(separator: ", "))"
        let sources = paths.map { path in
            makeSource(
                id: "file:\(path)",
                kind: .fileReference,
                purpose: "Identify evidence available for later retrieval.",
                informationClass: .retrievableLater,
                priority: .normal,
                freshness: .unknown,
                content: path,
                retentionPolicy: .externalReference,
                containsSensitiveData: true
            )
        }
        return makeSection(
            id: "selected-files",
            kind: .selectedFiles,
            content: content,
            priority: .normal,
            sources: sources
        )
    }

    func attachmentSection(for attachment: RunContextAttachment) -> ContextSection {
        let content = """
        Attached read-only file "\(attachment.name)" (the original external path is intentionally unavailable):
        --- BEGIN ATTACHMENT \(attachment.name) ---
        \(attachment.content)
        --- END ATTACHMENT \(attachment.name) ---
        """
        return makeSection(
            id: "attachment:\(attachment.id.uuidString)",
            kind: .attachment,
            content: content,
            priority: .high,
            sources: [
                makeSource(
                    id: "attachment:\(attachment.id.uuidString)",
                    kind: .attachment,
                    purpose: "Provide user-selected read-only evidence.",
                    informationClass: .requiredNow,
                    priority: .high,
                    freshness: .current,
                    content: content,
                    retentionPolicy: .run,
                    containsSensitiveData: true
                )
            ]
        )
    }

    func projectMemorySection(items: [String], projectId: UUID?) -> ContextSection {
        let content = "Project memory:\n\(items.joined(separator: "\n"))"
        let stableProjectId = projectId?.uuidString ?? "unscoped"
        let sources = items.enumerated().map { index, item in
            makeSource(
                id: "memory:\(stableProjectId):\(index)",
                kind: .memory,
                purpose: "Apply a durable project fact.",
                informationClass: .persistentState,
                priority: .normal,
                freshness: .unknown,
                content: item,
                retentionPolicy: .project,
                containsSensitiveData: true
            )
        }
        return makeSection(
            id: "project-memory",
            kind: .projectMemory,
            content: content,
            priority: .normal,
            sources: sources
        )
    }

    func retrievalResultsSection(citations: [RAGCitation]) -> ContextSection {
        let results = citations.map { citation in
            let quote = citation.quote.map { "\nQuote: \($0)" } ?? ""
            return "\(citation.displayText)\(quote)"
        }
        let content = "RAG results:\n\(results.joined(separator: "\n"))"
        let sources = zip(citations, results).map { citation, result in
            makeSource(
                id: "rag:\(citation.id)",
                kind: .ragCitation,
                purpose: "Ground the current decision in retrieved project evidence.",
                informationClass: .requiredNow,
                priority: .high,
                freshness: .current,
                content: result,
                retentionPolicy: .externalReference,
                containsSensitiveData: true
            )
        }
        return makeSection(
            id: "retrieval-results",
            kind: .retrievalResults,
            content: content,
            priority: .high,
            sources: sources
        )
    }

    private func makeSection(
        id: String,
        kind: ContextSectionKind,
        content: String,
        priority: ContextPriority,
        sources: [ContextSourceReference]
    ) -> ContextSection {
        ContextSection(
            id: id,
            kind: kind,
            order: 0,
            content: content,
            priority: priority,
            estimatedTokenCount: estimateTokenCount(for: content),
            sources: sources
        )
    }

    private func makeSource(
        id: String,
        kind: ContextSourceKind,
        purpose: String,
        informationClass: ContextInformationClass,
        priority: ContextPriority,
        freshness: ContextFreshness,
        content: String,
        retentionPolicy: ContextRetentionPolicy,
        containsSensitiveData: Bool
    ) -> ContextSourceReference {
        ContextSourceReference(
            id: id,
            kind: kind,
            purpose: purpose,
            informationClass: informationClass,
            priority: priority,
            freshness: freshness,
            estimatedTokenCount: estimateTokenCount(for: content),
            retentionPolicy: retentionPolicy,
            containsSensitiveData: containsSensitiveData
        )
    }
}
