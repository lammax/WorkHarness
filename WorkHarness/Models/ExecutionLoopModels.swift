//
// ExecutionLoopModels.swift
// WorkHarness
//
// Created by Auto (Codex) on 26.07.2026.
//

import Foundation

enum ExecutionTaskCategory: String, Codable, Equatable {
    case bug
    case documentation
    case feature
    case refactoring
    case research
    case security
    case tests
}

struct ExecutionTask: Identifiable, Codable, Equatable {
    var id: String
    var title: String
    var category: ExecutionTaskCategory
    var dependencies: [String]
    var goal: String
    var definition: String
}

struct ExecutionTaskPool: Codable, Equatable {
    var sourcePath: String
    var targetRepositoryPath: String
    var baseBranch: String
    var buildCommand: String
    var testCommand: String
    var tasks: [ExecutionTask]
}

enum ExecutionTaskResultStatus: String, Codable, Equatable {
    case passed
    case failed
    case blocked
    case cancelled
    case interrupted
}

enum ExecutionTaskFailureKind: String, Codable, Equatable {
    case tokenExhausted
    case runtimeCrash
    case validationFailure
    case repositoryMismatch
    case cancelled
    case unknown
}

struct ExecutionTaskResult: Identifiable, Codable, Equatable {
    var id: String { taskId }
    var taskId: String
    var title: String
    var category: ExecutionTaskCategory
    var status: ExecutionTaskResultStatus
    var profileId: String
    var runtimeId: String?
    var runtimeName: String?
    var modelId: String?
    var runId: UUID?
    var startedAt: Date
    var finishedAt: Date
    var buildPassed: Bool
    var testsPassed: Bool
    var commitSHA: String?
    var pushSucceeded: Bool
    var failureReason: String?
    var attemptNumber: Int? = nil
    var failureKind: ExecutionTaskFailureKind? = nil

    var duration: TimeInterval {
        max(0, finishedAt.timeIntervalSince(startedAt))
    }

    var firstPassSucceeded: Bool {
        status == .passed && (attemptNumber ?? 1) == 1
    }
}

enum ExecutionLoopAttemptStatus: String, Codable, Equatable {
    case preparing
    case running
    case paused
    case passed
    case failed
    case blocked
    case cancelled
}

struct ExecutionLoopAttempt: Identifiable, Codable, Equatable {
    var id: UUID
    var controllerRunId: UUID
    var sourcePath: String
    var targetRepositoryPath: String
    var baseBranch: String
    var baseCommitSHA: String?
    var executionBranch: String?
    var status: ExecutionLoopAttemptStatus
    var startedAt: Date
    var finishedAt: Date?
    var taskResults: [ExecutionTaskResult]
    var reportPath: String?
    var stopReason: String?

    var duration: TimeInterval {
        max(0, (finishedAt ?? Date()).timeIntervalSince(startedAt))
    }

    var consecutivePassedTaskCount: Int {
        taskResults.prefix { $0.status == .passed }.count
    }

    var attemptedTaskCount: Int {
        taskResults.count
    }

    var passedTaskCount: Int {
        taskResults.filter { $0.status == .passed }.count
    }

    var averageAttemptedTaskDuration: TimeInterval {
        guard !taskResults.isEmpty else { return 0 }
        return taskResults.map(\.duration).reduce(0, +) / Double(taskResults.count)
    }

    var averagePassedTaskDuration: TimeInterval {
        let passed = taskResults.filter { $0.status == .passed }
        guard !passed.isEmpty else { return 0 }
        return passed.map(\.duration).reduce(0, +) / Double(passed.count)
    }

    var firstPassSuccessRate: Double {
        guard !taskResults.isEmpty else { return 0 }
        return Double(taskResults.filter(\.firstPassSucceeded).count) / Double(taskResults.count)
    }
}
