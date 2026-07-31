//
// MemoryRepository.swift
// WorkHarness
//
// Created by Auto (Codex) on 10.07.2026.
//

import Foundation
import Observation

@MainActor
protocol MemoryRepositoryProtocol: BaseRepositoryProtocol {
    var items: [MemoryItem] { get }

    func insert(_ item: MemoryItem)
    func remove(id: UUID)
    func items(for projectId: UUID) -> [MemoryItem]
    func references(for projectId: UUID) -> [MemoryReference]
    func items(withIDs ids: [UUID], for projectId: UUID) -> [MemoryItem]
}

extension MemoryRepositoryProtocol {
    var repository: AppRepository { .memory }
}

@MainActor
@Observable
final class InMemoryMemoryRepository: MemoryRepositoryProtocol {
    private(set) var items: [MemoryItem] = []

    func insert(_ item: MemoryItem) {
        items.removeAll { $0.id == item.id }
        items.insert(item, at: 0)
    }

    func remove(id: UUID) {
        items.removeAll { $0.id == id }
    }

    func items(for projectId: UUID) -> [MemoryItem] {
        items.filter { $0.projectId == projectId }
    }

    func references(for projectId: UUID) -> [MemoryReference] {
        items(for: projectId).map {
            MemoryReference(
                id: $0.id,
                projectId: projectId,
                createdAt: $0.createdAt,
                contentCharacterCount: $0.content.count
            )
        }
    }

    func items(withIDs ids: [UUID], for projectId: UUID) -> [MemoryItem] {
        let itemsByID = Dictionary(uniqueKeysWithValues: items(for: projectId).map { ($0.id, $0) })
        return ids.compactMap { itemsByID[$0] }
    }
}
