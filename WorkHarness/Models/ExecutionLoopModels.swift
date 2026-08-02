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
    var routingRoute: String? = nil
    var routingReason: String? = nil
    var escalationReason: String? = nil
    var routingLatencyMilliseconds: Int? = nil
    var routingCostUSD: Double? = nil
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

    init(
        taskId: String,
        title: String,
        category: ExecutionTaskCategory,
        status: ExecutionTaskResultStatus,
        profileId: String,
        runtimeId: String? = nil,
        runtimeName: String? = nil,
        modelId: String? = nil,
        routingRoute: String? = nil,
        routingReason: String? = nil,
        escalationReason: String? = nil,
        routingLatencyMilliseconds: Int? = nil,
        routingCostUSD: Double? = nil,
        runId: UUID? = nil,
        startedAt: Date,
        finishedAt: Date,
        buildPassed: Bool,
        testsPassed: Bool,
        commitSHA: String? = nil,
        pushSucceeded: Bool,
        failureReason: String? = nil,
        attemptNumber: Int? = nil,
        failureKind: ExecutionTaskFailureKind? = nil
    ) {
        self.taskId = taskId
        self.title = title
        self.category = category
        self.status = status
        self.profileId = profileId
        self.runtimeId = runtimeId
        self.runtimeName = runtimeName
        self.modelId = modelId
        self.routingRoute = routingRoute
        self.routingReason = routingReason
        self.escalationReason = escalationReason
        self.routingLatencyMilliseconds = routingLatencyMilliseconds
        self.routingCostUSD = routingCostUSD
        self.runId = runId
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        self.buildPassed = buildPassed
        self.testsPassed = testsPassed
        self.commitSHA = commitSHA
        self.pushSucceeded = pushSucceeded
        self.failureReason = failureReason
        self.attemptNumber = attemptNumber
        self.failureKind = failureKind
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        taskId = try container.decode(String.self, forKey: .taskId)
        title = try container.decode(String.self, forKey: .title)
        category = try container.decode(ExecutionTaskCategory.self, forKey: .category)
        status = try container.decode(ExecutionTaskResultStatus.self, forKey: .status)
        profileId = try container.decode(String.self, forKey: .profileId)
        runtimeId = try container.decodeIfPresent(String.self, forKey: .runtimeId)
        runtimeName = try container.decodeIfPresent(String.self, forKey: .runtimeName)
        modelId = try container.decodeIfPresent(String.self, forKey: .modelId)
        routingRoute = try container.decodeIfPresent(String.self, forKey: .routingRoute)
        routingReason = try container.decodeIfPresent(String.self, forKey: .routingReason)
        escalationReason = try container.decodeIfPresent(String.self, forKey: .escalationReason)
        routingLatencyMilliseconds = try container.decodeIfPresent(Int.self, forKey: .routingLatencyMilliseconds)
        routingCostUSD = try container.decodeIfPresent(Double.self, forKey: .routingCostUSD)
        runId = try container.decodeIfPresent(UUID.self, forKey: .runId)
        startedAt = try container.decode(Date.self, forKey: .startedAt)
        finishedAt = try container.decode(Date.self, forKey: .finishedAt)
        buildPassed = try container.decode(Bool.self, forKey: .buildPassed)
        testsPassed = try container.decode(Bool.self, forKey: .testsPassed)
        commitSHA = try container.decodeIfPresent(String.self, forKey: .commitSHA)
        pushSucceeded = try container.decode(Bool.self, forKey: .pushSucceeded)
        failureReason = try container.decodeIfPresent(String.self, forKey: .failureReason)
        attemptNumber = try container.decodeIfPresent(Int.self, forKey: .attemptNumber)
        failureKind = try container.decodeIfPresent(ExecutionTaskFailureKind.self, forKey: .failureKind)
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
