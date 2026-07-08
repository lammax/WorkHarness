//
// ProjectServiceError.swift
// WorkHarness
//
// Created by Auto (Codex) on 08.07.2026.
//

import Foundation

enum ProjectServiceError: Error, Equatable, LocalizedError {
    case projectNotFound(UUID)

    var errorDescription: String? {
        switch self {
        case .projectNotFound(let projectId):
            "Project not found: \(projectId.uuidString)"
        }
    }
}
