//
// RunContextAttachment.swift
// WorkHarness
//
// Created by Auto (Codex) on 23.07.2026.
//

import Foundation

struct RunContextAttachment: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var content: String
    var byteCount: Int

    init(
        id: UUID = UUID(),
        name: String,
        content: String,
        byteCount: Int? = nil
    ) {
        self.id = id
        self.name = name
        self.content = content
        self.byteCount = byteCount ?? content.lengthOfBytes(using: .utf8)
    }
}
