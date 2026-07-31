//
// ContextObservation.swift
// WorkHarness
//
// Created by Auto (Codex) on 31.07.2026.
//

import CryptoKit
import Foundation

struct ContextSourceObservation: Codable, Equatable {
    var id: String
    var kind: ContextSourceKind
    var purpose: String
    var selectionReason: ContextInformationClass
    var priority: ContextPriority
    var freshness: ContextFreshness
    var estimatedTokenCount: Int
    var retentionPolicy: ContextRetentionPolicy
}

struct ContextSectionObservation: Codable, Equatable {
    var kind: ContextSectionKind
    var order: Int
    var estimatedTokenCount: Int
    var sourceCount: Int
}

struct ContextOmissionObservation: Codable, Equatable {
    var sourceId: String
    var sourceKind: ContextSourceKind?
    var sectionKind: ContextSectionKind?
    var reason: ContextOmissionReason
    var estimatedTokenCount: Int?
}

struct ContextObservationPolicy {
    var maxRecordedSources: Int = 128
    var maxRecordedOmissions: Int = 128

    func metadata(
        for snapshot: ContextSnapshot,
        buildDurationMilliseconds: Int
    ) -> [String: String] {
        let sources = ([snapshot.objectiveSource].compactMap { $0 } +
            snapshot.sections.flatMap(\.sources))
        let observedSources = sources.prefix(maxRecordedSources).map { source in
            ContextSourceObservation(
                id: Self.safeIdentifier(source.id, kind: source.kind.rawValue),
                kind: source.kind,
                purpose: source.purpose,
                selectionReason: source.informationClass,
                priority: source.priority,
                freshness: source.freshness,
                estimatedTokenCount: source.estimatedTokenCount,
                retentionPolicy: source.retentionPolicy
            )
        }
        let sections = snapshot.sections.map { section in
            ContextSectionObservation(
                kind: section.kind,
                order: section.order,
                estimatedTokenCount: section.estimatedTokenCount,
                sourceCount: section.sources.count
            )
        }
        let observedOmissions = snapshot.omissions.prefix(maxRecordedOmissions).map { omission in
            ContextOmissionObservation(
                sourceId: Self.safeIdentifier(
                    omission.sourceId,
                    kind: omission.sourceKind?.rawValue ?? "section"
                ),
                sourceKind: omission.sourceKind,
                sectionKind: omission.sectionKind,
                reason: omission.reason,
                estimatedTokenCount: omission.estimatedTokenCount
            )
        }

        return [
            "contextBuildDurationMs": "\(max(0, buildDurationMilliseconds))",
            "selectedSourcesJSON": encoded(observedSources),
            "sectionTokenEstimatesJSON": encoded(sections),
            "contextOmissionsJSON": encoded(observedOmissions),
            "selectedSourceObservationCount": "\(observedSources.count)",
            "unrecordedSelectedSourceCount": "\(max(0, sources.count - observedSources.count))",
            "omissionObservationCount": "\(observedOmissions.count)",
            "unrecordedOmissionCount": "\(max(0, snapshot.omissions.count - observedOmissions.count))",
            "truncationCount": "0"
        ]
    }

    func failureMetadata(
        error: Error,
        providerId: String,
        agentId: UUID,
        buildDurationMilliseconds: Int
    ) -> [String: String] {
        var metadata = [
            "providerId": providerId,
            "agentId": agentId.uuidString,
            "contextBuildDurationMs": "\(max(0, buildDurationMilliseconds))",
            "status": "failed"
        ]
        switch error {
        case let error as ContextBuildError:
            switch error {
            case let .mandatoryContentExceedsBudget(sourceId, requiredTokens, availableTokens):
                metadata["failureKind"] = "mandatoryContentExceedsBudget"
                metadata["sourceId"] = Self.safeIdentifier(sourceId, kind: "context")
                metadata["requiredTokens"] = "\(requiredTokens)"
                metadata["availableTokens"] = "\(availableTokens)"
            case let .tokenEstimationFailed(sourceId, _):
                metadata["failureKind"] = "tokenEstimationFailed"
                metadata["sourceId"] = Self.safeIdentifier(sourceId, kind: "context")
            }
        case is CancellationError:
            metadata["failureKind"] = "cancelled"
        default:
            metadata["failureKind"] = "unknown"
        }
        return metadata
    }

    static func safeIdentifier(_ value: String, kind: String) -> String {
        let digest = SHA256.hash(data: Data(value.utf8))
            .prefix(8)
            .map { String(format: "%02x", $0) }
            .joined()
        return "\(kind):\(digest)"
    }

    private func encoded<T: Encodable>(_ value: T) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(value),
              let string = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return string
    }
}

enum ContextUsageObservation {
    static func metadata(
        usage: TokenUsage,
        snapshot: ContextSnapshot?,
        providerId: String,
        source: String,
        additionalMetadata: [String: String] = [:]
    ) -> [String: String] {
        var metadata = additionalMetadata.merging([
            "providerId": providerId,
            "usageSource": source,
            "inputTokens": "\(usage.inputTokens)",
            "outputTokens": "\(usage.outputTokens)",
            "totalTokens": "\(usage.inputTokens + usage.outputTokens)",
            "costUSD": NSDecimalNumber(decimal: usage.totalCostUSD).stringValue,
            "usageAvailability": "reported"
        ]) { _, new in new }
        if let snapshot {
            metadata["contextSnapshotId"] = snapshot.id.uuidString
            metadata["estimatedInputTokenCount"] = "\(snapshot.estimatedInputTokenCount)"
            metadata["inputEstimateDelta"] = "\(usage.inputTokens - snapshot.estimatedInputTokenCount)"
        }
        return metadata
    }
}
