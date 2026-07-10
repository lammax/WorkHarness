//
// RAGMCPClient.swift
// WorkHarness
//
// Created by Auto (Codex) on 10.07.2026.
//

import Foundation

@MainActor
protocol RAGMCPClientProtocol: AnyObject {
    func index(zipURL: URL, strategy: RAGChunkingStrategy, replaceExisting: Bool) async throws -> RAGIndexingSummary
    func answer(question: String, settings: RAGRetrievalSettings) async throws -> RAGSearchResult
    func clearIndex() async throws
}

@MainActor
final class RAGMCPClient: RAGMCPClientProtocol {
    private let endpoint: URL
    private var isInitialized = false

    init(endpoint: URL = URL(string: "http://127.0.0.1:3003/mcp")!) {
        self.endpoint = endpoint
    }

    func index(zipURL: URL, strategy: RAGChunkingStrategy, replaceExisting: Bool) async throws -> RAGIndexingSummary {
        let text = try await callTool(name: "rag_index_zip", arguments: [
            "zip_path": zipURL.path,
            "strategy": strategy.rawValue,
            "replace_existing": replaceExisting
        ])
        return try decode(RAGIndexingSummary.self, from: text)
    }

    func answer(question: String, settings: RAGRetrievalSettings) async throws -> RAGSearchResult {
        let text = try await callTool(name: "rag_answer", arguments: [
            "question": question,
            "strategy": settings.chunkingStrategy.rawValue,
            "retrieval_mode": settings.retrievalMode.rawValue,
            "top_k_before_filtering": settings.topKBeforeFiltering,
            "top_k_after_filtering": settings.topKAfterFiltering,
            "similarity_threshold": settings.similarityThreshold,
            "relevance_filter_mode": settings.relevanceFilterMode.rawValue,
            "include_chunks": true,
            "max_quote_characters": 240
        ])

        let run = try decode(RAGMCPAnswerRun.self, from: text)
        return RAGSearchResult(
            answer: run.contract.answer,
            citations: run.contract.sources.map { source in
                let quote = run.contract.quotes.first { $0.source == source.source && $0.chunkID == source.chunkID }
                return RAGCitation(source: source.source, section: source.section, chunkID: source.chunkID, quote: quote?.text, score: run.chunks?.first { $0.chunkID == source.chunkID }?.score)
            },
            isUnknown: run.contract.isUnknown,
            retrieval: run.retrieval
        )
    }

    func clearIndex() async throws {
        _ = try await callTool(name: "rag_clear_index", arguments: [:])
    }

    private func callTool(name: String, arguments: [String: Any]) async throws -> String {
        try await initializeIfNeeded()
        let response = try await sendJSONRPC(method: "tools/call", params: ["name": name, "arguments": arguments])
        if let error = response.error { throw RAGMCPClientError.server(error.message) }
        guard let content = response.result?["content"] as? [[String: Any]] else { throw RAGMCPClientError.invalidResponse }
        let text = content.compactMap { $0["text"] as? String }.joined(separator: "\n")
        guard !text.isEmpty else { throw RAGMCPClientError.emptyResult(name) }
        return text
    }

    private func initializeIfNeeded() async throws {
        guard !isInitialized else { return }
        let response = try await sendJSONRPC(method: "initialize", params: [
            "protocolVersion": "2024-11-05",
            "capabilities": [:],
            "clientInfo": ["name": "WorkHarness", "version": "1.0.0"]
        ])
        if let error = response.error, !error.message.lowercased().contains("already initialized") {
            throw RAGMCPClientError.server(error.message)
        }
        isInitialized = true
    }

    private func sendJSONRPC(method: String, params: [String: Any]) async throws -> RAGMCPResponse {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 120
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json, text/event-stream", forHTTPHeaderField: "Accept")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["jsonrpc": "2.0", "id": UUID().uuidString, "method": method, "params": params])
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw RAGMCPClientError.httpStatus((response as? HTTPURLResponse)?.statusCode ?? -1)
        }
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw RAGMCPClientError.invalidResponse }
        return RAGMCPResponse(dictionary: object)
    }

    private func decode<T: Decodable>(_ type: T.Type, from text: String) throws -> T {
        guard let data = text.data(using: .utf8) else { throw RAGMCPClientError.invalidResponse }
        return try JSONDecoder().decode(type, from: data)
    }
}

private struct RAGMCPResponse {
    let result: [String: Any]?
    let error: RAGMCPError?

    init(dictionary: [String: Any]) {
        result = dictionary["result"] as? [String: Any]
        if let error = dictionary["error"] as? [String: Any] {
            self.error = RAGMCPError(message: error["message"] as? String ?? "Unknown MCP error")
        } else {
            error = nil
        }
    }
}

private struct RAGMCPError {
    let message: String
}

private enum RAGMCPClientError: LocalizedError {
    case server(String)
    case httpStatus(Int)
    case invalidResponse
    case emptyResult(String)

    var errorDescription: String? {
        switch self {
        case .server(let message): "RAG MCP server error: \(message)"
        case .httpStatus(let status): "RAG MCP returned HTTP \(status)."
        case .invalidResponse: "RAG MCP returned an invalid response."
        case .emptyResult(let tool): "RAG MCP tool \(tool) returned no result."
        }
    }
}

private struct RAGMCPAnswerRun: Decodable {
    let contract: RAGAnswerContract
    let retrieval: RAGRetrievalSummary
    let chunks: [RAGAnswerChunk]?
}

private struct RAGAnswerContract: Decodable {
    let answer: String
    let sources: [RAGAnswerSource]
    let quotes: [RAGAnswerQuote]
    let isUnknown: Bool

    enum CodingKeys: String, CodingKey { case answer, sources, quotes, isUnknown = "is_unknown" }
}

private struct RAGAnswerSource: Decodable { let source: String; let section: String?; let chunkID: Int; enum CodingKeys: String, CodingKey { case source, section, chunkID = "chunk_id" } }
private struct RAGAnswerQuote: Decodable { let source: String; let chunkID: Int; let text: String; enum CodingKeys: String, CodingKey { case source, chunkID = "chunk_id", text } }
private struct RAGAnswerChunk: Decodable { let chunkID: Int; let score: Double; enum CodingKeys: String, CodingKey { case chunkID = "chunk_id", score } }
