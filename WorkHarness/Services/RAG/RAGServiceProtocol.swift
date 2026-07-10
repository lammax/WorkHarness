//
// RAGServiceProtocol.swift
// WorkHarness
//
// Created by Auto (Codex) on 10.07.2026.
//

import Foundation

@MainActor
protocol RAGServiceProtocol: BaseServiceProtocol {
    func index(zipURL: URL, strategy: RAGChunkingStrategy, replaceExisting: Bool) async throws -> RAGIndexingSummary
    func search(question: String, settings: RAGRetrievalSettings) async throws -> RAGSearchResult
    func clearIndex() async throws
}

extension RAGServiceProtocol {
    var service: AppService { .rag }
}
