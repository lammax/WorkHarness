//
// ProviderError.swift
// WorkHarness
//
// Created by Auto (Codex) on 08.07.2026.
//

import Foundation

enum ProviderError: Error, Equatable, LocalizedError {
    case noActiveProvider
    case providerNotFound(String)

    var errorDescription: String? {
        switch self {
        case .noActiveProvider:
            "No active provider is selected."
        case .providerNotFound(let providerId):
            "Provider not found: \(providerId)"
        }
    }
}
