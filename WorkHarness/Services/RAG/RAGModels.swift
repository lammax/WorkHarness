//
// RAGModels.swift
// WorkHarness
//
// Created by Auto (Codex) on 10.07.2026.
//

import Foundation

enum RAGChunkingStrategy: String, Codable, CaseIterable, Equatable {
    case fixedTokens
    case structure

    var title: String {
        switch self {
        case .fixedTokens: "Fixed tokens"
        case .structure: "Structure"
        }
    }
}

enum RAGRetrievalMode: String, Codable, CaseIterable, Equatable {
    case basic
    case enhanced

    var title: String {
        switch self {
        case .basic: "Basic"
        case .enhanced: "Enhanced"
        }
    }
}

enum RAGRelevanceFilterMode: String, Codable, CaseIterable, Equatable {
    case disabled
    case similarityThreshold
    case heuristic

    var title: String {
        switch self {
        case .disabled: "Off"
        case .similarityThreshold: "Similarity"
        case .heuristic: "Heuristic"
        }
    }
}

struct RAGRetrievalSettings: Codable, Equatable {
    var chunkingStrategy: RAGChunkingStrategy = .fixedTokens
    var retrievalMode: RAGRetrievalMode = .enhanced
    var topKBeforeFiltering: Int = 12
    var topKAfterFiltering: Int = 5
    var similarityThreshold: Double = 0.25
    var relevanceFilterMode: RAGRelevanceFilterMode = .similarityThreshold

    nonisolated static let `default` = RAGRetrievalSettings()
}

enum RAGAnswerMode: String, Codable, CaseIterable, Equatable {
    case disabled
    case enabled

    var title: String {
        switch self {
        case .disabled: "Off"
        case .enabled: "Use RAG"
        }
    }
}

struct RAGCitation: Codable, Equatable, Hashable, Identifiable {
    var id: String { "\(source)#\(chunkID)" }
    var source: String
    var section: String?
    var chunkID: Int
    var quote: String?
    var score: Double?

    init(source: String, section: String?, chunkID: Int, quote: String? = nil, score: Double? = nil) {
        self.source = source
        self.section = section
        self.chunkID = chunkID
        self.quote = quote
        self.score = score
    }

    var displayText: String {
        let location = section.map { "\(source) · \($0)" } ?? source
        return "[\(chunkID)] \(location)"
    }
}

struct RAGSearchResult: Codable, Equatable {
    var answer: String
    var citations: [RAGCitation]
    var isUnknown: Bool
    var retrieval: RAGRetrievalSummary
}

struct RAGRetrievalSummary: Codable, Equatable {
    var originalQuestion: String
    var searchQuery: String
    var candidatesBeforeFiltering: Int
    var chunksAfterFiltering: Int
    var bestScore: Double?
}

struct RAGIndexingSummary: Codable, Equatable {
    var strategy: RAGChunkingStrategy
    var documentCount: Int
    var chunkCount: Int
    var averageTokens: Double
    var minTokens: Int
    var maxTokens: Int
    var embeddingModel: String
    var databasePath: String
    var duration: TimeInterval
}
