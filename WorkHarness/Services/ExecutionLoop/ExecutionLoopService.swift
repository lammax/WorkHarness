//
// ExecutionLoopService.swift
// WorkHarness
//
// Created by Auto (Codex) on 26.07.2026.
//

import Foundation

@MainActor
final class ExecutionLoopService: ExecutionLoopServiceProtocol {
    private struct CommandPayload: Decodable {
        var exitCode: Int32
        var standardOutput: String
        var standardError: String
    }

    private let taskSource: ExecutionTaskSourceProtocol
    private let profileSelector: ExecutionProfileSelector
    private let runLauncher: ExecutionLoopRunLaunchingProtocol
    private let runRepository: RunRepository
    private let recorder: RunRecorder
    private let toolService: ToolServiceProtocol
    private let projectService: ProjectServiceProtocol
    private let agentProfileService: AgentProfileServiceProtocol
    private let appSettingsService: AppSettingsServiceProtocol
    private let reportWriter: ExecutionLoopReportWriter
    private let stateStore: any ExecutionLoopStateStoreProtocol
    private let fileManager: FileManager
    private let now: () -> Date

    private var loopTask: Task<Void, Never>?
    private var activeTaskRunId: UUID?
    private var originalProjectId: UUID?
    private var preexistingCompletedTaskIds: Set<String> = []
    private var pauseRequested = false
    private var activePool: ExecutionTaskPool?
    private var activeTaskCheckpoint: ExecutionLoopTaskCheckpoint?
    private var recoveryTaskId: String?

    private(set) var activeAttempt: ExecutionLoopAttempt?

    func preview(sourcePath: String) throws -> ExecutionTaskPool {
        let trimmedPath = sourcePath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPath.isEmpty else {
            throw ExecutionLoopServiceError.sourcePathRequired
        }
        return try taskSource.loadTaskPool(at: URL(fileURLWithPath: trimmedPath))
    }

    init(
        taskSource: ExecutionTaskSourceProtocol,
        profileSelector: ExecutionProfileSelector,
        runLauncher: ExecutionLoopRunLaunchingProtocol,
        runRepository: RunRepository,
        recorder: RunRecorder,
        toolService: ToolServiceProtocol,
        projectService: ProjectServiceProtocol,
        agentProfileService: AgentProfileServiceProtocol,
        appSettingsService: AppSettingsServiceProtocol,
        reportWriter: ExecutionLoopReportWriter,
        stateStore: (any ExecutionLoopStateStoreProtocol)? = nil,
        fileManager: FileManager = .default,
        now: @escaping () -> Date = Date.init
    ) {
        self.taskSource = taskSource
        self.profileSelector = profileSelector
        self.runLauncher = runLauncher
        self.runRepository = runRepository
        self.recorder = recorder
        self.toolService = toolService
        self.projectService = projectService
        self.agentProfileService = agentProfileService
        self.appSettingsService = appSettingsService
        self.reportWriter = reportWriter
        self.stateStore = stateStore ?? FileExecutionLoopStateStore()
        self.fileManager = fileManager
        self.now = now
        restoreCheckpoint()
    }

    func start(sourcePath: String) async throws -> UUID {
        guard loopTask == nil else {
            throw ExecutionLoopServiceError.alreadyRunning
        }
        let trimmedPath = sourcePath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPath.isEmpty else {
            throw ExecutionLoopServiceError.sourcePathRequired
        }
        guard appSettingsService.defaultSafetyMode == .autoInsideSandbox else {
            throw ExecutionLoopServiceError.autoApproveRequired
        }
        guard runLauncher.selectedAgentRuntimeDescriptor != nil else {
            throw ExecutionLoopServiceError.agentRuntimeUnavailable
        }
        guard runLauncher.selectedAgentRuntimeDescriptor?.id == LocalLLMAgentRuntime.gatewayRuntimeId else {
            throw ExecutionLoopServiceError.llmGatewayRuntimeRequired
        }

        let pool = try preview(sourcePath: trimmedPath)
        try validateTargetRepository(pool.targetRepositoryPath)

        originalProjectId = projectService.currentProject?.id
        let project = try selectTargetProject(at: pool.targetRepositoryPath)
        agentProfileService.reload()

        let controllerRun = Run(
            projectId: project.id,
            goal: "Execute task pool \(URL(fileURLWithPath: pool.sourcePath).lastPathComponent)",
            mode: .codingLoop
        )
        runRepository.insert(controllerRun)
        recorder.record(
            runId: controllerRun.id,
            type: .runCreated,
            message: controllerRun.goal,
            metadata: [
                "executionLoopAttempt": "true",
                "sourcePath": pool.sourcePath,
                "targetRepositoryPath": pool.targetRepositoryPath,
                "taskCount": "\(pool.tasks.count)"
            ]
        )

        let attempt = ExecutionLoopAttempt(
            id: UUID(),
            controllerRunId: controllerRun.id,
            sourcePath: pool.sourcePath,
            targetRepositoryPath: pool.targetRepositoryPath,
            baseBranch: pool.baseBranch,
            status: .preparing,
            startedAt: now(),
            taskResults: []
        )
        activeAttempt = attempt
        activePool = pool
        activeTaskCheckpoint = nil
        recoveryTaskId = nil
        pauseRequested = false
        try persistState()

        loopTask = Task { [weak self] in
            await self?.execute(pool: pool)
        }
        return controllerRun.id
    }

    func pauseAfterCurrentTask() {
        guard loopTask != nil,
              activeAttempt?.status == .running || activeAttempt?.status == .preparing else { return }
        pauseRequested = true
        recorder.record(
            runId: controllerRunId,
            type: .finalSummary,
            message: "Pause requested. The loop will pause after the current task.",
            metadata: ["executionLoopProgress": "true"]
        )
    }

    func resume() async throws -> UUID {
        guard loopTask == nil, let attempt = activeAttempt, attempt.status == .paused else {
            throw ExecutionLoopServiceError.noAttempt
        }
        guard appSettingsService.defaultSafetyMode == .autoInsideSandbox else {
            throw ExecutionLoopServiceError.autoApproveRequired
        }
        guard runLauncher.selectedAgentRuntimeDescriptor != nil else {
            throw ExecutionLoopServiceError.agentRuntimeUnavailable
        }
        guard runLauncher.selectedAgentRuntimeDescriptor?.id == LocalLLMAgentRuntime.gatewayRuntimeId else {
            throw ExecutionLoopServiceError.llmGatewayRuntimeRequired
        }

        guard let pool = activePool else {
            throw ExecutionLoopServiceError.checkpointUnavailable
        }
        try validateTargetRepository(pool.targetRepositoryPath)
        originalProjectId = projectService.currentProject?.id
        _ = try selectTargetProject(at: pool.targetRepositoryPath)
        agentProfileService.reload()
        pauseRequested = false
        updateAttempt {
            $0.status = .preparing
            $0.stopReason = nil
        }
        do {
            try await reconcileRepository(for: pool)
        } catch {
            recordRecoveryFailure(error)
            throw error
        }
        runRepository.updateRun(attempt.controllerRunId) { $0.status = .running }
        recorder.record(
            runId: attempt.controllerRunId,
            type: .runResumed,
            message: "Execution loop resumed with a new task Run from the saved checkpoint.",
            metadata: [
                "attemptId": attempt.id.uuidString,
                "recoveryStrategy": "restart-new-run",
                "recoveryTaskId": recoveryTaskId ?? ""
            ]
        )
        loopTask = Task { [weak self] in
            await self?.execute(pool: pool, repositoryPrepared: true)
        }
        return attempt.controllerRunId
    }

    func stop() async {
        guard let task = loopTask else {
            if activeAttempt?.status == .paused {
                finishAttempt(status: .cancelled, reason: "Ended by the user.")
            }
            return
        }
        task.cancel()
        if let activeTaskRunId {
            await runLauncher.cancelRun(runId: activeTaskRunId)
        }
        finishAttempt(status: .cancelled, reason: "Stopped by the user.")
        await task.value
    }

    private func execute(pool: ExecutionTaskPool, repositoryPrepared: Bool = false) async {
        defer {
            activeTaskRunId = nil
            loopTask = nil
            preexistingCompletedTaskIds = []
            restoreOriginalProject()
        }

        do {
            if !repositoryPrepared {
                try await prepareRepository(for: pool)
            }
            guard !Task.isCancelled else {
                finishAttempt(status: .cancelled, reason: "Stopped by the user.")
                return
            }

            updateAttempt { $0.status = .running }
            for task in pool.tasks where !preexistingCompletedTaskIds.contains(task.id) {
                guard !Task.isCancelled else {
                    finishAttempt(status: .cancelled, reason: "Stopped by the user.")
                    return
                }
                try validateDependencies(of: task)

                let attemptNumber = (activeAttempt?.taskResults.filter { $0.taskId == task.id }.count ?? 0) + 1
                let result = await execute(
                    task: task,
                    in: pool,
                    attemptNumber: attemptNumber,
                    isRecovery: recoveryTaskId == task.id
                )
                updateAttempt { $0.taskResults.append(result) }
                activeTaskCheckpoint = nil
                if recoveryTaskId == task.id { recoveryTaskId = nil }
                try persistState()
                try persistReport()

                guard result.status == .passed else {
                    let status: ExecutionLoopAttemptStatus = result.status == .blocked ? .blocked : .failed
                    finishAttempt(
                        status: status,
                        reason: result.failureReason ?? "Task \(task.id) did not pass."
                    )
                    return
                }
                if pauseRequested {
                    pauseAttempt(reason: "Paused after completing \(task.id).")
                    return
                }
            }

            finishAttempt(status: .passed, reason: nil)
        } catch is CancellationError {
            finishAttempt(status: .cancelled, reason: "Stopped by the user.")
        } catch {
            let status: ExecutionLoopAttemptStatus
            if case ExecutionLoopServiceError.dependencyNotPassed = error {
                status = .blocked
            } else {
                status = .failed
            }
            finishAttempt(status: status, reason: error.localizedDescription)
        }
    }

    private func prepareRepository(for pool: ExecutionTaskPool) async throws {
        let status = try await git(
            "status --porcelain",
            runId: controllerRunId,
            projectRootPath: pool.targetRepositoryPath
        )
        guard status.standardOutput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ExecutionLoopServiceError.targetRepositoryDirty
        }

        let branch = try await git(
            "branch --show-current",
            runId: controllerRunId,
            projectRootPath: pool.targetRepositoryPath
        ).standardOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !branch.isEmpty else {
            throw ExecutionLoopServiceError.currentBranchUnavailable
        }

        let baseCommit = try await git(
            "rev-parse HEAD",
            runId: controllerRunId,
            projectRootPath: pool.targetRepositoryPath
        ).standardOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !baseCommit.isEmpty else {
            throw ExecutionLoopServiceError.gitFailed("rev-parse HEAD")
        }

        let commitSubjects = try await git(
            "log --format=%s",
            runId: controllerRunId,
            projectRootPath: pool.targetRepositoryPath
        ).standardOutput.split(whereSeparator: \.isNewline).map(String.init)
        preexistingCompletedTaskIds = Set(pool.tasks.compactMap { task in
            commitSubjects.contains(where: { $0.hasPrefix("\(task.id): ") })
                ? task.id
                : nil
        })
        updateAttempt {
            $0.baseCommitSHA = baseCommit
            $0.executionBranch = branch
        }
        recorder.record(
            runId: controllerRunId,
            type: .finalSummary,
            message: "Using current execution branch: \(branch)",
            metadata: [
                "baseCommitSHA": baseCommit,
                "executionBranch": branch,
                "preexistingCompletedTasks": preexistingCompletedTaskIds
                    .sorted()
                    .joined(separator: ",")
            ]
        )
        try persistReport()
        try persistState()
    }

    private func execute(
        task: ExecutionTask,
        in pool: ExecutionTaskPool,
        attemptNumber: Int,
        isRecovery: Bool
    ) async -> ExecutionTaskResult {
        let startedAt = now()
        let profileId = profileSelector.profileId(for: task)
        let descriptor = runLauncher.selectedAgentRuntimeDescriptor
        let modelId = descriptor.flatMap(selectedModelId)
        var result = ExecutionTaskResult(
            taskId: task.id,
            title: task.title,
            category: task.category,
            status: .failed,
            profileId: profileId,
            runtimeId: descriptor?.id,
            runtimeName: descriptor?.displayName,
            modelId: modelId,
            startedAt: startedAt,
            finishedAt: startedAt,
            buildPassed: false,
            testsPassed: false,
            pushSucceeded: false,
            attemptNumber: attemptNumber
        )

        do {
            if let descriptor {
                runRepository.updateRun(controllerRunId) {
                    $0.executionBackend = RunExecutionBackendSnapshot(
                        kind: .agentRuntime,
                        id: descriptor.id,
                        displayName: descriptor.displayName,
                        modelId: modelId
                    )
                }
            }
            let headBeforeTask = try await git(
                "rev-parse HEAD",
                runId: controllerRunId,
                projectRootPath: pool.targetRepositoryPath
            ).standardOutput.trimmingCharacters(in: .whitespacesAndNewlines)
            activeTaskCheckpoint = ExecutionLoopTaskCheckpoint(
                task: task,
                attemptNumber: attemptNumber,
                startedAt: startedAt,
                headBeforeTask: headBeforeTask
            )
            try persistState()
            let configuration = agentProfileService.configuration(for: profileId)
            recorder.record(
                runId: controllerRunId,
                type: .agentStarted,
                message: "[\(task.id)] Started \(task.title).",
                metadata: [
                    "taskId": task.id,
                    "taskTitle": task.title,
                    "profileId": profileId,
                    "runtimeId": descriptor?.id ?? "",
                    "runtimeName": descriptor?.displayName ?? "",
                    "modelId": modelId ?? "",
                    "executionLoopProgress": "true"
                ]
            )
            guard let runId = await runLauncher.startRun(
                goal: taskPrompt(task, pool: pool, isRecovery: isRecovery),
                mode: .multiAgent,
                configuration: configuration,
                progressMirrorRunId: controllerRunId,
                progressMirrorMetadata: [
                    "taskId": task.id,
                    "taskTitle": task.title,
                    "profileId": profileId,
                    "executionLoopProgress": "true"
                ]
            ) else {
                throw ExecutionLoopServiceError.taskRunFailed(task.id)
            }
            activeTaskRunId = runId
            result.runId = runId
            activeTaskCheckpoint?.runId = runId
            try persistState()

            guard let completedRun = runLauncher.run(withId: runId),
                  completedRun.status == .completed else {
                throw ExecutionLoopServiceError.taskRunFailed(task.id)
            }
            result.modelId = completedRun.executionBackend?.modelId ?? result.modelId
            let routingEvents = completedRun.events.filter { $0.type == .modelRoutingDecision }
            if let initialRoute = routingEvents.first {
                result.routingRoute = initialRoute.metadata["route"]
                result.routingReason = initialRoute.metadata["reason"]
            }
            if let escalation = routingEvents.last(where: {
                $0.metadata["reason"] == "fast_model_runtime_failure"
            }) {
                result.escalationReason = escalation.metadata["reason"]
                result.routingLatencyMilliseconds = escalation.metadata["escalationLatencyMilliseconds"]
                    .flatMap(Int.init)
                result.routingCostUSD = escalation.metadata["costBeforeFallbackUSD"]
                    .flatMap(Double.init)
            }

            let headAfterAgent = try await git(
                "rev-parse HEAD",
                runId: runId,
                projectRootPath: pool.targetRepositoryPath
            ).standardOutput.trimmingCharacters(in: .whitespacesAndNewlines)
            guard headAfterAgent == headBeforeTask else {
                throw ExecutionLoopServiceError.taskChangedGitHistory
            }

            let changedFiles = try await git(
                "status --porcelain",
                runId: runId,
                projectRootPath: pool.targetRepositoryPath
            ).standardOutput.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !changedFiles.isEmpty else {
                throw ExecutionLoopServiceError.taskProducedNoChanges
            }

            recorder.record(
                runId: runId,
                type: .validationStarted,
                message: "Execution-loop validation started.",
                metadata: ["taskId": task.id]
            )
            recorder.record(
                runId: controllerRunId,
                type: .validationStarted,
                message: "[\(task.id)] Independent build and test validation started.",
                metadata: [
                    "taskId": task.id,
                    "taskTitle": task.title,
                    "executionLoopProgress": "true"
                ]
            )
            _ = try await shell(
                pool.buildCommand,
                runId: runId,
                projectRootPath: pool.targetRepositoryPath
            )
            result.buildPassed = true
            _ = try await shell(
                pool.testCommand,
                runId: runId,
                projectRootPath: pool.targetRepositoryPath
            )
            result.testsPassed = true
            recorder.record(
                runId: runId,
                type: .validationFinished,
                message: "Build and tests passed.",
                metadata: [
                    "taskId": task.id,
                    "build": "passed",
                    "tests": "passed"
                ]
            )
            recorder.record(
                runId: controllerRunId,
                type: .validationFinished,
                message: "[\(task.id)] Build and tests passed.",
                metadata: [
                    "taskId": task.id,
                    "taskTitle": task.title,
                    "build": "passed",
                    "tests": "passed",
                    "executionLoopProgress": "true"
                ]
            )

            let securityDecision = try await performFinalSecurityGate(
                task: task,
                pool: pool,
                parentRunId: runId,
                baseConfiguration: configuration
            )
            result.securityVerdict = securityDecision.verdict.rawValue
            result.securitySeverity = securityDecision.severity.rawValue
            result.securityFinding = securityDecision.finding
            result.securityRemediationCount = securityDecision.remediationCount

            guard appSettingsService.defaultSafetyMode == .autoInsideSandbox else {
                throw ExecutionLoopServiceError.autoApproveRequired
            }
            _ = try await git(
                "add -A",
                runId: runId,
                projectRootPath: pool.targetRepositoryPath
            )
            let commitMessage = "\(task.id): \(task.title)"
                .replacingOccurrences(of: "\"", with: "'")
            _ = try await git(
                "commit -m \"\(commitMessage)\"",
                runId: runId,
                projectRootPath: pool.targetRepositoryPath
            )
            let commitSHA = try await git(
                "rev-parse HEAD",
                runId: runId,
                projectRootPath: pool.targetRepositoryPath
            ).standardOutput.trimmingCharacters(in: .whitespacesAndNewlines)
            result.commitSHA = commitSHA

            _ = try await git(
                "push -u origin HEAD",
                runId: runId,
                projectRootPath: pool.targetRepositoryPath
            )
            result.pushSucceeded = true
            result.status = .passed
            result.finishedAt = now()
            runRepository.updateRun(runId) { $0.status = .completed }
            recorder.record(
                runId: runId,
                type: .finalSummary,
                message: "\(task.id) passed, committed and pushed.",
                metadata: [
                    "taskId": task.id,
                    "profileId": profileId,
                    "commitSHA": commitSHA,
                    "push": "succeeded"
                ]
            )
            recorder.record(
                runId: controllerRunId,
                type: .finalSummary,
                message: "[\(task.id)] Passed, committed and pushed.",
                metadata: [
                    "taskId": task.id,
                    "taskTitle": task.title,
                    "profileId": profileId,
                    "commitSHA": commitSHA,
                    "push": "succeeded",
                    "executionLoopProgress": "true"
                ]
            )
        } catch is CancellationError {
            result.status = .cancelled
            result.failureKind = .cancelled
            result.failureReason = "Stopped by the user."
            result.finishedAt = now()
        } catch {
            result.status = .failed
            result.failureKind = failureKind(for: error)
            result.failureReason = error.localizedDescription
            result.finishedAt = now()
            recorder.record(
                runId: controllerRunId,
                type: .error,
                message: "[\(task.id)] \(error.localizedDescription)",
                metadata: [
                    "taskId": task.id,
                    "taskTitle": task.title,
                    "profileId": profileId,
                    "executionLoopProgress": "true"
                ]
            )
            if let runId = result.runId {
                runRepository.updateRun(runId) { $0.status = .failed }
                recorder.record(
                    runId: runId,
                    type: .error,
                    message: error.localizedDescription,
                    metadata: [
                        "executionLoopTaskId": task.id,
                        "executionLoopFailure": "true"
                    ]
                )
                recorder.record(
                    runId: runId,
                    type: .runFailed,
                    message: error.localizedDescription,
                    metadata: ["executionLoopTaskId": task.id]
                )
            }
        }
        activeTaskRunId = nil
        return result
    }

    private func performFinalSecurityGate(
        task: ExecutionTask,
        pool: ExecutionTaskPool,
        parentRunId: UUID,
        baseConfiguration: MultiAgentRunConfiguration
    ) async throws -> (verdict: SecurityReviewVerdict, severity: SecurityReviewSeverity, finding: String, remediationCount: Int) {
        guard let securityRole = agentProfileService.configuration(for: "implementation")
            .roles.first(where: { $0.role == .securityReviewer }) else {
            throw ExecutionLoopServiceError.validationFailed("Security Reviewer is unavailable")
        }
        let securityConfiguration = MultiAgentRunConfiguration(
            profileId: "implementation-security-gate",
            profileName: "Implementation Security Gate",
            roles: [securityRole]
        )
        var remediationCount = 0

        while true {
            let reviewRun = try await launchSecurityRun(
                goal: securityGatePrompt(task: task, pool: pool),
                configuration: securityConfiguration,
                task: task
            )
            guard let event = reviewRun.events.last(where: {
                $0.type == .validationFinished && $0.metadata["validationKind"] == "securityReview"
            }),
            let verdictValue = event.metadata["verdict"],
            let severityValue = event.metadata["severity"],
            let verdict = SecurityReviewVerdict(rawValue: verdictValue),
            let severity = SecurityReviewSeverity(rawValue: severityValue) else {
                throw ExecutionLoopServiceError.validationFailed("Security review audit result is missing")
            }
            let finding = event.message
            recorder.record(
                runId: parentRunId,
                type: .validationFinished,
                message: finding,
                metadata: event.metadata.merging([
                    "taskId": task.id,
                    "securityReviewRunId": reviewRun.id.uuidString,
                    "executionLoopSecurityGate": "true"
                ]) { _, new in new }
            )
            guard severity.blocksCommit || verdict == .block else {
                return (verdict, severity, finding, remediationCount)
            }
            guard remediationCount < 2 else {
                throw ExecutionLoopServiceError.validationFailed(
                    "Security review blocked commit: \(finding)"
                )
            }

            remediationCount += 1
            let remediationRoles = baseConfiguration.roles.filter {
                [.coder, .testRunner, .securityReviewer].contains($0.role)
            }
            let remediationConfiguration = MultiAgentRunConfiguration(
                profileId: "implementation-security-remediation",
                profileName: "Implementation Security Remediation",
                roles: remediationRoles
            )
            _ = try await launchSecurityRun(
                goal: "Fix the blocking security finding before commit: \(finding). \(event.metadata["remediation"] ?? "Apply the smallest secure fix.")",
                configuration: remediationConfiguration,
                task: task
            )
            _ = try await shell(pool.buildCommand, runId: parentRunId, projectRootPath: pool.targetRepositoryPath)
            _ = try await shell(pool.testCommand, runId: parentRunId, projectRootPath: pool.targetRepositoryPath)
        }
    }

    private func launchSecurityRun(
        goal: String,
        configuration: MultiAgentRunConfiguration,
        task: ExecutionTask
    ) async throws -> Run {
        guard let runId = await runLauncher.startRun(
            goal: goal,
            mode: .multiAgent,
            configuration: configuration,
            progressMirrorRunId: controllerRunId,
            progressMirrorMetadata: [
                "taskId": task.id,
                "executionLoopSecurityGate": "true",
                "gatewayProviderId": MCPProviderDescriptor.llmGateway.id
            ]
        ) else {
            throw ExecutionLoopServiceError.taskRunFailed(task.id)
        }
        activeTaskRunId = runId
        guard let run = runLauncher.run(withId: runId), run.status == .completed else {
            throw ExecutionLoopServiceError.taskRunFailed(task.id)
        }
        return run
    }

    private func securityGatePrompt(task: ExecutionTask, pool: ExecutionTaskPool) -> String {
        """
        Final security gate for Task Loop task \(task.id), after independent build and tests passed.
        Review only the current uncommitted diff in \(pool.targetRepositoryPath).
        Do not edit, commit, or push. The LLM Gateway input/output guards are mandatory.
        Return the configured compact security JSON verdict.
        """
    }

    private func selectedModelId(for descriptor: AgentRuntimeDescriptor) -> String? {
        let savedModelId = appSettingsService.agentModelId(for: descriptor.id)
        guard !descriptor.modelOptions.isEmpty else {
            return savedModelId ?? descriptor.defaultModelId
        }
        if let savedModelId,
           descriptor.modelOptions.contains(where: { $0.id == savedModelId }) {
            return savedModelId
        }
        if let defaultModelId = descriptor.defaultModelId,
           descriptor.modelOptions.contains(where: { $0.id == defaultModelId }) {
            return defaultModelId
        }
        return descriptor.modelOptions.first?.id
    }

    private func validateDependencies(of task: ExecutionTask) throws {
        for dependencyId in task.dependencies {
            guard preexistingCompletedTaskIds.contains(dependencyId) ||
                    activeAttempt?.taskResults.contains(where: {
                $0.taskId == dependencyId && $0.status == .passed
            }) == true else {
                throw ExecutionLoopServiceError.dependencyNotPassed(
                    taskId: task.id,
                    dependencyId: dependencyId
                )
            }
        }
    }

    private func taskPrompt(
        _ task: ExecutionTask,
        pool: ExecutionTaskPool,
        isRecovery: Bool
    ) -> String {
        """
        WorkHarness Execution Loop task \(task.id).

        Work only in:
        \(pool.targetRepositoryPath)

        Selected workflow profile: \(profileSelector.profileId(for: task)).
        This is autonomous attempt #\((activeAttempt?.taskResults.filter { $0.taskId == task.id }.count ?? 0) + 1). Do not ask the user questions.
        \(isRecovery ? "This attempt recovers an interrupted task. Inspect the current git diff first and preserve valid existing edits before continuing." : "Start from the current repository state and keep the change scoped to this task.")
        Inspect the repository rules and current code before editing.
        Implement only this task and its acceptance criteria.
        Do not run git commit, git push, git switch, git checkout, git reset, git merge, or git rebase.
        The execution loop owns validation, commit, and push after your Run completes.
        Do not edit the task-pool source or execution reports.
        Finish with a concise summary of changed files and focused checks.

        \(task.definition)
        """
    }

    private func shell(
        _ command: String,
        runId: UUID,
        projectRootPath: String
    ) async throws -> CommandPayload {
        let result = try await toolService.executeAwaitingApproval(.init(
            runId: runId,
            toolId: "shell.run",
            arguments: ["command": command],
            projectRootPath: projectRootPath
        ))
        do {
            return try commandPayload(from: result)
        } catch {
            throw ExecutionLoopServiceError.validationFailed(command)
        }
    }

    private func git(
        _ arguments: String,
        runId: UUID,
        projectRootPath: String
    ) async throws -> CommandPayload {
        let result = try await toolService.executeAwaitingApproval(.init(
            runId: runId,
            toolId: "git.run",
            arguments: ["arguments": arguments],
            projectRootPath: projectRootPath
        ))
        do {
            return try commandPayload(from: result)
        } catch {
            throw ExecutionLoopServiceError.gitFailed(arguments)
        }
    }

    private func commandPayload(from result: ToolResult) throws -> CommandPayload {
        guard result.status == .succeeded,
              let data = result.output.data(using: .utf8),
              let payload = try? JSONDecoder().decode(CommandPayload.self, from: data),
              payload.exitCode == 0 else {
            throw ExecutionLoopServiceError.gitFailed(result.toolId)
        }
        return payload
    }

    private func selectTargetProject(at rootPath: String) throws -> Project {
        let standardizedPath = URL(fileURLWithPath: rootPath, isDirectory: true)
            .standardizedFileURL.path
        let project = projectService.projects.first {
            guard let candidate = $0.rootPath else { return false }
            return URL(fileURLWithPath: candidate, isDirectory: true)
                .standardizedFileURL.path == standardizedPath
        } ?? projectService.addProject(
            name: URL(fileURLWithPath: standardizedPath).lastPathComponent,
            rootPath: standardizedPath
        )
        try projectService.selectProject(id: project.id)
        guard projectService.currentProject?.id == project.id else {
            throw ExecutionLoopServiceError.projectSelectionFailed
        }
        return project
    }

    private func validateTargetRepository(_ rootPath: String) throws {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: rootPath, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw ExecutionLoopServiceError.targetRepositoryUnavailable(rootPath)
        }
        let gitPath = URL(fileURLWithPath: rootPath, isDirectory: true)
            .appendingPathComponent(".git").path
        guard fileManager.fileExists(atPath: gitPath) else {
            throw ExecutionLoopServiceError.targetIsNotGitRepository(rootPath)
        }
    }

    private func persistReport() throws {
        guard var attempt = activeAttempt else { return }
        do {
            let reportURL = try reportWriter.write(attempt)
            let wasMissing = attempt.reportPath == nil
            attempt.reportPath = reportURL.path
            activeAttempt = attempt
            guard wasMissing else { return }

            let artifact = RunArtifact(
                name: "Day 5 Execution Loop Report",
                kind: "execution-loop-report",
                path: reportURL.path
            )
            recorder.recordArtifact(runId: attempt.controllerRunId, artifact: artifact)
            recorder.record(
                runId: attempt.controllerRunId,
                type: .artifactCreated,
                message: artifact.name,
                metadata: [
                    "artifactId": artifact.id.uuidString,
                    "kind": artifact.kind,
                    "path": reportURL.path
                ]
            )
        } catch {
            throw ExecutionLoopServiceError.reportFailed(error.localizedDescription)
        }
    }

    private func finishAttempt(
        status: ExecutionLoopAttemptStatus,
        reason: String?
    ) {
        guard var attempt = activeAttempt else { return }
        if attempt.finishedAt != nil { return }

        attempt.status = status
        attempt.finishedAt = now()
        attempt.stopReason = reason
        activeAttempt = attempt

        let runStatus: RunStatus
        let eventType: RunEventType
        switch status {
        case .passed:
            runStatus = .completed
            eventType = .runCompleted
        case .cancelled:
            runStatus = .cancelled
            eventType = .runCancelled
        case .preparing, .running, .paused, .failed, .blocked:
            runStatus = .failed
            eventType = .runFailed
        }
        runRepository.updateRun(attempt.controllerRunId) { $0.status = runStatus }
        recorder.record(
            runId: attempt.controllerRunId,
            type: eventType,
            message: reason ?? "Execution loop completed.",
            metadata: [
                "attemptId": attempt.id.uuidString,
                "status": status.rawValue,
                "consecutivePassed": "\(attempt.consecutivePassedTaskCount)",
                "attemptedTasks": "\(attempt.attemptedTaskCount)",
                "firstPassSuccessRate": "\(attempt.firstPassSuccessRate)"
            ]
        )
        try? persistReport()
        try? persistState()
    }

    private func pauseAttempt(reason: String) {
        guard var attempt = activeAttempt else { return }
        attempt.status = .paused
        attempt.stopReason = reason
        activeAttempt = attempt
        runRepository.updateRun(attempt.controllerRunId) { $0.status = .interrupted }
        recorder.record(
            runId: attempt.controllerRunId,
            type: .runInterrupted,
            message: reason,
            metadata: [
                "attemptId": attempt.id.uuidString,
                "status": ExecutionLoopAttemptStatus.paused.rawValue,
                "executionLoopProgress": "true"
            ]
        )
        try? persistReport()
        try? persistState()
    }

    private func restoreOriginalProject() {
        if let originalProjectId {
            try? projectService.selectProject(id: originalProjectId)
        } else {
            projectService.clearCurrentProject()
        }
        agentProfileService.reload()
        self.originalProjectId = nil
    }

    private func updateAttempt(_ update: (inout ExecutionLoopAttempt) -> Void) {
        guard var attempt = activeAttempt else { return }
        update(&attempt)
        activeAttempt = attempt
        try? persistState()
    }

    private var controllerRunId: UUID {
        activeAttempt?.controllerRunId ?? UUID()
    }

    private func persistState() throws {
        guard let attempt = activeAttempt, let pool = activePool else { return }
        do {
            try stateStore.save(ExecutionLoopCheckpoint(
                attempt: attempt,
                pool: pool,
                activeTask: activeTaskCheckpoint,
                recoveryTaskId: recoveryTaskId,
                savedAt: now()
            ))
        } catch {
            throw ExecutionLoopServiceError.checkpointFailed(error.localizedDescription)
        }
    }

    private func restoreCheckpoint() {
        guard let checkpoint = try? stateStore.load(),
              checkpoint.attempt.finishedAt == nil else { return }
        var attempt = checkpoint.attempt
        activePool = checkpoint.pool
        recoveryTaskId = checkpoint.recoveryTaskId
        activeTaskCheckpoint = checkpoint.activeTask
        if let activeTask = checkpoint.activeTask {
            attempt.taskResults.append(ExecutionTaskResult(
                taskId: activeTask.task.id,
                title: activeTask.task.title,
                category: activeTask.task.category,
                status: .interrupted,
                profileId: profileSelector.profileId(for: activeTask.task),
                runtimeId: nil,
                runtimeName: nil,
                modelId: nil,
                runId: activeTask.runId,
                startedAt: activeTask.startedAt,
                finishedAt: now(),
                buildPassed: false,
                testsPassed: false,
                commitSHA: nil,
                pushSucceeded: false,
                failureReason: "WorkHarness stopped while this task was running.",
                attemptNumber: activeTask.attemptNumber,
                failureKind: .runtimeCrash
            ))
            recoveryTaskId = activeTask.task.id
            activeTaskCheckpoint = nil
        }
        if attempt.status == .running || attempt.status == .preparing {
            attempt.status = .paused
            attempt.stopReason = "Recovered after WorkHarness relaunch. Repository reconciliation is required before resume."
        }
        activeAttempt = attempt
        runRepository.updateRun(attempt.controllerRunId) { $0.status = .interrupted }
        recorder.record(
            runId: attempt.controllerRunId,
            type: .runInterrupted,
            message: attempt.stopReason ?? "Execution loop recovered after relaunch.",
            metadata: [
                "attemptId": attempt.id.uuidString,
                "recoveryStrategy": "restart-new-run",
                "recoveryTaskId": recoveryTaskId ?? ""
            ]
        )
        try? persistState()
    }

    private func reconcileRepository(for pool: ExecutionTaskPool) async throws {
        let branch = try await git(
            "branch --show-current",
            runId: controllerRunId,
            projectRootPath: pool.targetRepositoryPath
        ).standardOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard branch == activeAttempt?.executionBranch else {
            throw ExecutionLoopServiceError.repositoryMismatch("Current branch \(branch) does not match saved branch \(activeAttempt?.executionBranch ?? "—").")
        }
        let head = try await git(
            "rev-parse HEAD",
            runId: controllerRunId,
            projectRootPath: pool.targetRepositoryPath
        ).standardOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        let expectedHead = activeAttempt?.taskResults.reversed().first(where: { $0.status == .passed })?.commitSHA
            ?? activeAttempt?.baseCommitSHA
        guard expectedHead == nil || head == expectedHead else {
            throw ExecutionLoopServiceError.repositoryMismatch("Current HEAD \(head) does not match saved HEAD \(expectedHead ?? "—").")
        }
        let status = try await git(
            "status --porcelain",
            runId: controllerRunId,
            projectRootPath: pool.targetRepositoryPath
        ).standardOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard status.isEmpty || recoveryTaskId != nil else {
            throw ExecutionLoopServiceError.repositoryMismatch("The repository has uncommitted changes unrelated to an interrupted task.")
        }
        preexistingCompletedTaskIds = Set(activeAttempt?.taskResults.compactMap {
            $0.status == .passed ? $0.taskId : nil
        } ?? [])
        try persistState()
    }

    private func recordRecoveryFailure(_ error: Error) {
        recorder.record(
            runId: controllerRunId,
            type: .error,
            message: error.localizedDescription,
            metadata: [
                "failureKind": ExecutionTaskFailureKind.repositoryMismatch.rawValue,
                "executionLoopRecovery": "true"
            ]
        )
        try? persistState()
    }

    private func failureKind(for error: Error) -> ExecutionTaskFailureKind {
        let message = error.localizedDescription.lowercased()
        if message.contains("token") && (message.contains("limit") || message.contains("exhaust")) {
            return .tokenExhausted
        }
        if case ExecutionLoopServiceError.validationFailed = error {
            return .validationFailure
        }
        if case ExecutionLoopServiceError.taskChangedGitHistory = error {
            return .repositoryMismatch
        }
        if case ExecutionLoopServiceError.gitFailed = error {
            return .repositoryMismatch
        }
        if case ExecutionLoopServiceError.repositoryMismatch = error {
            return .repositoryMismatch
        }
        if case ExecutionLoopServiceError.taskRunFailed = error {
            return .runtimeCrash
        }
        return .unknown
    }
}
