//
// ApprovalServiceError.swift
// WorkHarness
//
// Created by Auto (Codex) on 08.07.2026.
//

import Foundation

enum ApprovalServiceError: LocalizedError, Equatable {
    case requestNotFound(UUID)
    case requestAlreadyDecided(UUID)

    var errorDescription: String? {
        switch self {
        case .requestNotFound:
            "Approval request was not found."
        case .requestAlreadyDecided:
            "Approval request was already decided."
        }
    }
}
