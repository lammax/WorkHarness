//
// LocalLLMModelOption.swift
// WorkHarness
//
// Created by Auto (Codex) on 26.07.2026.
//

import Foundation

struct LocalLLMModelOption: Identifiable, Codable, Equatable {
    let id: String
    let displayName: String
    let provider: String
    let contextWindowTokens: Int
    let maxOutputTokens: Int
    let supportsStreaming: Bool
}
