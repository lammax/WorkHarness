//
// ContextBuilder+Sections.swift
// WorkHarness
//
// Created by Auto (Codex) on 31.07.2026.
//

import Foundation

extension ContextBuilder {
    func makeObjectiveSource(content: String, runId: UUID) throws -> ContextSourceReference {
        try makeSource(
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

    func projectIdentitySection(for project: Project) throws -> ContextSection {
        let content = "Current project: \(project.name)"
        return try makeSection(
            id: "project-identity",
            kind: .projectIdentity,
            content: content,
            priority: .normal,
            sources: [
                try makeSource(
                    id: "project:\(project.id.uuidString)",
                    kind: .project,
                    purpose: "Identify the current workspace.",
                    informationClass: .persistentState,
                    priority: .normal,
                    freshness: .current,
                    content: content,
                    retentionPolicy: .project,
                    containsSensitiveData: false
                )
            ]
        )
    }

    func projectRootSection(path: String, projectId: UUID?) throws -> ContextSection {
        let content = "Project root: \(path)"
        return try makeSection(
            id: "project-root",
            kind: .projectRoot,
            content: content,
            priority: .normal,
            sources: [
                try makeSource(
                    id: "project-root:\(projectId?.uuidString ?? "unscoped")",
                    kind: .projectRoot,
                    purpose: "Locate the current workspace.",
                    informationClass: .persistentState,
                    priority: .normal,
                    freshness: .current,
                    content: content,
                    retentionPolicy: .project,
                    containsSensitiveData: true
                )
            ]
        )
    }

    func safetyInstructionSection(mode: SafetyMode) throws -> ContextSection {
        try makeSection(
            id: "safety-instruction",
            kind: .safetyInstruction,
            content: Self.autoApprovalInstruction,
            priority: .critical,
            sources: [
                try makeSource(
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

    func recentRunSummarySection(summary: String, runId: UUID) throws -> ContextSection {
        let content = "Recent run summary: \(summary)"
        return try makeSection(
            id: "recent-run-summary",
            kind: .recentRunSummary,
            content: content,
            priority: .high,
            sources: [
                try makeSource(
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
    ) throws -> ContextSection {
        let content = "Folded context:\n\(summary.renderedText)"
        return try makeSection(
            id: "folded-context",
            kind: .foldedContext,
            content: content,
            priority: .high,
            sources: [
                try makeSource(
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

    func selectedFilesSection(paths: [String]) throws -> ContextSection {
        let content = "Selected files: \(paths.joined(separator: ", "))"
        let sources = try paths.map { path in
            try makeSource(
                id: "file:\(path)",
                kind: .fileReference,
                purpose: "Identify evidence available for later retrieval.",
                informationClass: .retrievableLater,
                priority: .low,
                freshness: .unknown,
                content: path,
                retentionPolicy: .externalReference,
                containsSensitiveData: true
            )
        }
        return try makeSection(
            id: "selected-files",
            kind: .selectedFiles,
            content: content,
            priority: .low,
            sources: sources
        )
    }

    func attachmentSection(for attachment: RunContextAttachment) throws -> ContextSection {
        let content = """
        Attached read-only file "\(attachment.name)" (the original external path is intentionally unavailable):
        --- BEGIN ATTACHMENT \(attachment.name) ---
        \(attachment.content)
        --- END ATTACHMENT \(attachment.name) ---
        """
        return try makeSection(
            id: "attachment:\(attachment.id.uuidString)",
            kind: .attachment,
            content: content,
            priority: .critical,
            sources: [
                try makeSource(
                    id: "attachment:\(attachment.id.uuidString)",
                    kind: .attachment,
                    purpose: "Provide user-selected read-only evidence.",
                    informationClass: .requiredNow,
                    priority: .critical,
                    freshness: .current,
                    content: content,
                    retentionPolicy: .run,
                    containsSensitiveData: true
                )
            ]
        )
    }

    func projectMemorySection(items: [MemoryItem]) throws -> ContextSection {
        let content = "Project memory:\n\(items.map(\.content).joined(separator: "\n"))"
        let sources = try items.map { item in
            try makeSource(
                id: "memory:\(item.id.uuidString)",
                kind: .memory,
                purpose: "Apply a durable project fact.",
                informationClass: .persistentState,
                priority: .low,
                freshness: .unknown,
                content: item.content,
                retentionPolicy: .project,
                containsSensitiveData: true
            )
        }
        return try makeSection(
            id: "project-memory",
            kind: .projectMemory,
            content: content,
            priority: .low,
            sources: sources
        )
    }

    func retrievalResultsSection(citations: [RAGCitation]) throws -> ContextSection {
        let results = citations.map { citation in
            let quote = citation.quote.map { "\nQuote: \($0)" } ?? ""
            return "\(citation.displayText)\(quote)"
        }
        let content = "RAG results:\n\(results.joined(separator: "\n"))"
        let sources = try zip(citations, results).map { citation, result in
            try makeSource(
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
        return try makeSection(
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
    ) throws -> ContextSection {
        ContextSection(
            id: id,
            kind: kind,
            order: 0,
            content: content,
            priority: priority,
            estimatedTokenCount: try estimateTokenCount(for: content, sourceId: id),
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
    ) throws -> ContextSourceReference {
        ContextSourceReference(
            id: id,
            kind: kind,
            purpose: purpose,
            informationClass: informationClass,
            priority: priority,
            freshness: freshness,
            estimatedTokenCount: try estimateTokenCount(for: content, sourceId: id),
            retentionPolicy: retentionPolicy,
            containsSensitiveData: containsSensitiveData
        )
    }
}
