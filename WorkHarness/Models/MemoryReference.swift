//
// MemoryReference.swift
// WorkHarness
//
// Created by Auto (Codex) on 31.07.2026.
//

import Foundation

struct MemoryReference: Identifiable, Codable, Equatable {
    let id: UUID
    var projectId: UUID
    var createdAt: Date
    var contentCharacterCount: Int
}
