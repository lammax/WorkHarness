//
// MemoryServiceProtocol.swift
// WorkHarness
//
// Created by Auto (Codex) on 10.07.2026.
//

import Foundation

@MainActor
protocol MemoryServiceProtocol: BaseServiceProtocol {
    func items(for projectId: UUID) -> [MemoryItem]
    func saveProjectMemory(content: String, projectId: UUID, runId: UUID?) throws -> MemoryItem
    func removeMemory(id: UUID)
}

extension MemoryServiceProtocol {
    var service: AppService { .memory }
}
