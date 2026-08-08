//
// ExecutionLoopServiceProtocol.swift
// WorkHarness
//
// Created by Auto (Codex) on 26.07.2026.
//

import Foundation

@MainActor
protocol ExecutionLoopRunLaunchingProtocol: AnyObject {
    var selectedAgentRuntimeDescriptor: AgentRuntimeDescriptor? { get }

    func run(withId runId: UUID) -> Run?
    func startRun(
        goal: String,
        mode: RunMode,
        configuration: MultiAgentRunConfiguration,
        progressMirrorRunId: UUID,
        progressMirrorMetadata: [String: String]
    ) async -> UUID?
    func cancelRun(runId: UUID) async
}

@MainActor
protocol ExecutionLoopServiceProtocol: BaseServiceProtocol {
    var activeAttempt: ExecutionLoopAttempt? { get }

    func preview(sourcePath: String) throws -> ExecutionTaskPool
    func start(sourcePath: String) async throws -> UUID
    func pauseAfterCurrentTask()
    func resume() async throws -> UUID
    func stop() async
}

extension ExecutionLoopServiceProtocol {
    var service: AppService { .executionLoop }
}

struct ExecutionLoopCommand: Equatable {
    enum Action: Equatable {
        case start(sourcePath: String)
        case pause
        case resume
        case stop
        case status
    }

    var action: Action

    static func parse(_ message: String) -> ExecutionLoopCommand? {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        let command = "/loop"
        guard trimmed.lowercased().hasPrefix(command) else { return nil }
        let suffix = trimmed.dropFirst(command.count)
        guard suffix.isEmpty || suffix.first?.isWhitespace == true else {
            return nil
        }

        let argument = String(suffix)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if argument.caseInsensitiveCompare("stop") == .orderedSame {
            return ExecutionLoopCommand(action: .stop)
        }
        if argument.caseInsensitiveCompare("pause") == .orderedSame {
            return ExecutionLoopCommand(action: .pause)
        }
        if argument.caseInsensitiveCompare("resume") == .orderedSame {
            return ExecutionLoopCommand(action: .resume)
        }
        if argument.caseInsensitiveCompare("status") == .orderedSame {
            return ExecutionLoopCommand(action: .status)
        }
        return ExecutionLoopCommand(action: .start(sourcePath: argument))
    }
}

enum ExecutionLoopServiceError: LocalizedError, Equatable {
    case alreadyRunning
    case noAttempt
    case sourcePathRequired
    case targetRepositoryUnavailable(String)
    case targetIsNotGitRepository(String)
    case autoApproveRequired
    case targetRepositoryDirty
    case baseBranchUnavailable(String)
    case currentBranchUnavailable
    case projectSelectionFailed
    case agentRuntimeUnavailable
    case llmGatewayRuntimeRequired
    case dependencyNotPassed(taskId: String, dependencyId: String)
    case taskRunFailed(String)
    case taskChangedGitHistory
    case taskProducedNoChanges
    case validationFailed(String)
    case gitFailed(String)
    case reportFailed(String)
    case checkpointUnavailable
    case checkpointFailed(String)
    case repositoryMismatch(String)

    var errorDescription: String? {
        switch self {
        case .alreadyRunning:
            "An execution loop is already running."
        case .noAttempt:
            "No execution-loop attempt is available."
        case .sourcePathRequired:
            "Provide an absolute Markdown task-pool path after /loop."
        case .targetRepositoryUnavailable(let path):
            "The target repository is unavailable: \(path)"
        case .targetIsNotGitRepository(let path):
            "The execution-loop target is not a Git repository: \(path)"
        case .autoApproveRequired:
            "Enable and Save “Auto-approve actions” before starting an autonomous execution loop."
        case .targetRepositoryDirty:
            "The target repository has uncommitted changes."
        case .baseBranchUnavailable(let branch):
            "The configured base branch is unavailable: \(branch)"
        case .currentBranchUnavailable:
            "The target repository is in detached HEAD state. Select a branch before starting the execution loop."
        case .projectSelectionFailed:
            "WorkHarness could not select the execution-loop target project."
        case .agentRuntimeUnavailable:
            "Select an available Agent Runtime before starting the execution loop."
        case .llmGatewayRuntimeRequired:
            "Select LLM Gateway Agent before starting the execution loop so every model call passes the input/output guards."
        case .dependencyNotPassed(let taskId, let dependencyId):
            "Task \(taskId) is blocked because dependency \(dependencyId) did not pass."
        case .taskRunFailed(let taskId):
            "The agent Run for \(taskId) did not complete successfully."
        case .taskChangedGitHistory:
            "The task agent changed Git history. Commit and push are owned by the execution loop."
        case .taskProducedNoChanges:
            "The task Run completed without producing repository changes."
        case .validationFailed(let command):
            "Validation failed: \(command)"
        case .gitFailed(let command):
            "Git command failed: git \(command)"
        case .reportFailed(let message):
            "Execution report could not be written: \(message)"
        case .checkpointUnavailable:
            "The saved execution-loop task pool is unavailable. Start a new loop."
        case .checkpointFailed(let message):
            "Execution-loop recovery state could not be saved: \(message)"
        case .repositoryMismatch(let message):
            "Execution-loop repository reconciliation failed: \(message)"
        }
    }
}
