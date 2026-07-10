//
// MemoryService.swift
// WorkHarness
//
// Created by Auto (Codex) on 10.07.2026.
//

import Foundation

@MainActor
final class MemoryService: MemoryServiceProtocol {
    private let repository: MemoryRepositoryProtocol
    private let recorder: RunRecorder
    private let writePolicy: MemoryWritePolicyProtocol

    init(
        repository: MemoryRepositoryProtocol,
        recorder: RunRecorder,
        writePolicy: MemoryWritePolicyProtocol
    ) {
        self.repository = repository
        self.recorder = recorder
        self.writePolicy = writePolicy
    }

    convenience init(repository: MemoryRepositoryProtocol, recorder: RunRecorder) {
        self.init(repository: repository, recorder: recorder, writePolicy: MemoryWritePolicy())
    }

    func items(for projectId: UUID) -> [MemoryItem] {
        repository.items(for: projectId)
    }

    func saveProjectMemory(content: String, projectId: UUID, runId: UUID? = nil) throws -> MemoryItem {
        let normalizedContent = try writePolicy.normalizedContent(from: content)
        let item = MemoryItem(projectId: projectId, content: normalizedContent)
        repository.insert(item)

        if let runId {
            recorder.record(
                runId: runId,
                type: .memorySaved,
                message: normalizedContent,
                metadata: ["memoryId": item.id.uuidString, "projectId": projectId.uuidString]
            )
        }

        return item
    }

    func removeMemory(id: UUID) {
        repository.remove(id: id)
    }
}

protocol MemoryWritePolicyProtocol {
    func normalizedContent(from content: String) throws -> String
}

struct MemoryWritePolicy: MemoryWritePolicyProtocol {
    func normalizedContent(from content: String) throws -> String {
        let normalized = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { throw MemoryServiceError.emptyContent }
        guard normalized.count <= 20_000 else { throw MemoryServiceError.contentTooLong }

        let sensitiveMarkers = [
            "api_key", "apikey", "api key", "access_token", "access token",
            "password", "secret", "private key", "BEGIN PRIVATE KEY"
        ]
        let lowercased = normalized.lowercased()
        guard !sensitiveMarkers.contains(where: lowercased.contains) else {
            throw MemoryServiceError.sensitiveContent
        }

        return normalized
    }
}

enum MemoryServiceError: LocalizedError, Equatable {
    case emptyContent
    case contentTooLong
    case sensitiveContent

    var errorDescription: String? {
        switch self {
        case .emptyContent: "Memory content cannot be empty."
        case .contentTooLong: "Memory content is too long."
        case .sensitiveContent: "Sensitive content cannot be saved to memory."
        }
    }
}
