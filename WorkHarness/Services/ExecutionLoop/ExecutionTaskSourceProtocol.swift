//
// ExecutionTaskSourceProtocol.swift
// WorkHarness
//
// Created by Auto (Codex) on 26.07.2026.
//

import Foundation

protocol ExecutionTaskSourceProtocol {
    func loadTaskPool(at sourceURL: URL) throws -> ExecutionTaskPool
}

enum ExecutionTaskSourceError: LocalizedError, Equatable {
    case sourceUnavailable(String)
    case missingTargetRepository
    case missingBaseBranch
    case missingBuildCommand
    case missingTestCommand
    case noTasks
    case malformedTask(String)
    case unsupportedCategory(String)

    var errorDescription: String? {
        switch self {
        case .sourceUnavailable(let path):
            "Execution task source is unavailable: \(path)"
        case .missingTargetRepository:
            "The task pool does not define a target Repository."
        case .missingBaseBranch:
            "The task pool does not define a Base branch."
        case .missingBuildCommand:
            "The task pool does not define a Build command."
        case .missingTestCommand:
            "The task pool does not define a Test command."
        case .noTasks:
            "The task pool does not contain any tasks."
        case .malformedTask(let id):
            "Execution task is malformed: \(id)"
        case .unsupportedCategory(let category):
            "Unsupported execution task category: \(category)"
        }
    }
}

