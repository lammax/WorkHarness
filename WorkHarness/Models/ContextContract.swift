//
// ContextContract.swift
// WorkHarness
//
// Created by Auto (Codex) on 31.07.2026.
//

import Foundation

enum ContextInformationClass: String, Codable, CaseIterable, Equatable {
    case requiredNow
    case retrievableLater
    case persistentState
    case discardable
}

enum ContextPriority: Int, Codable, CaseIterable, Equatable {
    case critical
    case high
    case normal
    case low
}

enum ContextFreshness: String, Codable, CaseIterable, Equatable {
    case current
    case staticValue
    case unknown
}

enum ContextRetentionPolicy: String, Codable, CaseIterable, Equatable {
    case request
    case run
    case project
    case externalReference
}

enum ContextSectionKind: String, Codable, CaseIterable, Equatable {
    case projectIdentity
    case projectRoot
    case safetyInstruction
    case recentRunSummary
    case foldedContext
    case selectedFiles
    case attachment
    case projectMemory
    case retrievalResults
}

enum ContextSourceKind: String, Codable, CaseIterable, Equatable {
    case objective
    case project
    case projectRoot
    case safetyPolicy
    case recentRunSummary
    case foldedContext
    case fileReference
    case attachment
    case memory
    case ragCitation
}

struct ContextSourceReference: Codable, Equatable {
    var id: String
    var kind: ContextSourceKind
    var purpose: String
    var informationClass: ContextInformationClass
    var priority: ContextPriority
    var freshness: ContextFreshness
    var estimatedTokenCount: Int
    var retentionPolicy: ContextRetentionPolicy
    var containsSensitiveData: Bool
}

struct ContextSection: Codable, Equatable {
    var id: String
    var kind: ContextSectionKind
    var order: Int
    var content: String
    var priority: ContextPriority
    var estimatedTokenCount: Int
    var sources: [ContextSourceReference]
}

enum ContextOmissionReason: String, Codable, CaseIterable, Equatable {
    case notSelected
    case budgetExceeded
    case invalidReference
    case unauthorized
    case stale
    case empty
}

struct ContextOmission: Codable, Equatable {
    var sourceId: String
    var sourceKind: ContextSourceKind?
    var sectionKind: ContextSectionKind?
    var reason: ContextOmissionReason
    var estimatedTokenCount: Int?
}

struct ContextWindowConstraint: Codable, Equatable {
    var configuredMaxInputTokens: Int?
    var reservedOutputTokens: Int?
    var providerContextWindowTokens: Int?

    var effectiveMaxInputTokens: Int? {
        let configuredLimit = configuredMaxInputTokens.map { max(0, $0) }
        let providerLimit = providerContextWindowTokens.map {
            max(0, $0 - max(0, reservedOutputTokens ?? 0))
        }

        switch (configuredLimit, providerLimit) {
        case let (.some(configured), .some(provider)):
            return min(configured, provider)
        case let (.some(configured), .none):
            return configured
        case let (.none, .some(provider)):
            return provider
        case (.none, .none):
            return nil
        }
    }
}
