//
// ContextTokenEstimator.swift
// WorkHarness
//
// Created by Auto (Codex) on 31.07.2026.
//

import Foundation

protocol ContextTokenEstimatorProtocol {
    func estimateTokenCount(for content: String) throws -> Int
}

struct ApproximateContextTokenEstimator: ContextTokenEstimatorProtocol {
    func estimateTokenCount(for content: String) throws -> Int {
        max(1, content.split(whereSeparator: \.isWhitespace).count)
    }
}
