//
// RAGService.swift
// WorkHarness
//
// Created by Auto (Codex) on 10.07.2026.
//

import Foundation

@MainActor
final class RAGService: RAGServiceProtocol {
    private let client: RAGMCPClientProtocol

    init(client: RAGMCPClientProtocol) {
        self.client = client
    }

    func index(zipURL: URL, strategy: RAGChunkingStrategy, replaceExisting: Bool = true) async throws -> RAGIndexingSummary {
        try await client.index(zipURL: zipURL, strategy: strategy, replaceExisting: replaceExisting)
    }

    func search(question: String, settings: RAGRetrievalSettings) async throws -> RAGSearchResult {
        try await client.answer(question: question, settings: settings)
    }

    func clearIndex() async throws {
        try await client.clearIndex()
    }
}
