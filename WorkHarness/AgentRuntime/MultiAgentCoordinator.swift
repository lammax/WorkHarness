//
// MultiAgentCoordinator.swift
// WorkHarness
//
// Created by Auto (Codex) on 10.07.2026.
//

import Foundation

struct MultiAgentStepResult: Identifiable, Equatable {
    let id: UUID
    var stepId: UUID
    var role: AgentRole
    var agentId: UUID
    var output: String
    var sessionId: UUID

    init(
        id: UUID = UUID(),
        stepId: UUID,
        role: AgentRole,
        agentId: UUID,
        output: String,
        sessionId: UUID
    ) {
        self.id = id
        self.stepId = stepId
        self.role = role
        self.agentId = agentId
        self.output = output
        self.sessionId = sessionId
    }
}

struct MultiAgentExecutionResult: Equatable {
    var planId: UUID
    var steps: [MultiAgentStepResult]
}

@MainActor
final class MultiAgentCoordinator {
    private struct ActiveSession {
        let runtime: AgentRuntime
        let sessionId: UUID
    }

    private let repository: RunRepository
    private let recorder: RunRecorder
    private let outputValidator: AgentOutputValidator
    private let handoffPolicy: MultiAgentHandoffPolicy
    private var activeSessionsByRunId: [UUID: [UUID: ActiveSession]] = [:]
    private var cancelledRunIds: Set<UUID> = []

    init(repository: RunRepository, recorder: RunRecorder) {
        self.repository = repository
        self.recorder = recorder
        self.outputValidator = AgentOutputValidator()
        self.handoffPolicy = MultiAgentHandoffPolicy()
    }

    init(
        repository: RunRepository,
        recorder: RunRecorder,
        handoffPolicy: MultiAgentHandoffPolicy
    ) {
        self.repository = repository
        self.recorder = recorder
        self.outputValidator = AgentOutputValidator()
        self.handoffPolicy = handoffPolicy
    }

    func execute(
        plan: AgentExecutionPlan,
        candidates: [AgentCandidate],
        runtimes: [UUID: AgentRuntime],
        runId: UUID,
        context: ContextSnapshot? = nil,
        workingDirectory: String? = nil,
        configuration: MultiAgentRunConfiguration
    ) async throws -> MultiAgentExecutionResult {
        cancelledRunIds.remove(runId)
        defer {
            activeSessionsByRunId.removeValue(forKey: runId)
            cancelledRunIds.remove(runId)
        }

        var results: [MultiAgentStepResult] = []
        var completedStepIds: Set<UUID> = []

        while completedStepIds.count < plan.steps.count {
            try ensureRunIsActive(runId)
            let readySteps = plan.steps.filter { step in
                !completedStepIds.contains(step.id) && step.dependsOn.allSatisfy(completedStepIds.contains)
            }
            guard !readySteps.isEmpty else {
                throw MultiAgentCoordinatorError.invalidPlan
            }

            var selectedSteps: [AgentPlanStep] = []
            var selectedAgentIds: Set<UUID> = []
            for step in readySteps {
                guard !selectedAgentIds.contains(step.agentId) else { continue }
                selectedSteps.append(step)
                selectedAgentIds.insert(step.agentId)
            }

            if selectedSteps.count == 1 {
                let result = try await executeStep(
                    selectedSteps[0],
                    plan: plan,
                    candidates: candidates,
                    runtimes: runtimes,
                    runId: runId,
                    context: context,
                    workingDirectory: workingDirectory,
                    previousResults: results,
                    configuration: configuration
                )
                results.append(result)
            } else {
                let previousResults = results
                let batchResults = try await withThrowingTaskGroup(of: MultiAgentStepResult.self) { group in
                    for step in selectedSteps {
                        group.addTask {
                            try await self.executeStep(
                                step,
                                plan: plan,
                                candidates: candidates,
                                runtimes: runtimes,
                                runId: runId,
                                context: context,
                                workingDirectory: workingDirectory,
                                previousResults: previousResults,
                                configuration: configuration
                            )
                        }
                    }

                    var collected: [MultiAgentStepResult] = []
                    for try await result in group {
                        collected.append(result)
                    }
                    return collected
                }
                results.append(contentsOf: batchResults.sorted { lhs, rhs in
                    (plan.steps.firstIndex { $0.id == lhs.stepId } ?? 0) < (plan.steps.firstIndex { $0.id == rhs.stepId } ?? 0)
                })
            }

            completedStepIds.formUnion(selectedSteps.map(\.id))
        }

        return MultiAgentExecutionResult(planId: plan.id, steps: results)
    }

    func cancel(runId: UUID) async {
        cancelledRunIds.insert(runId)
        let sessions = activeSessionsByRunId[runId]?.values.map { $0 } ?? []

        for session in sessions {
            await session.runtime.cancel(sessionId: session.sessionId)
        }
    }

    private func executeStep(
        _ step: AgentPlanStep,
        plan: AgentExecutionPlan,
        candidates: [AgentCandidate],
        runtimes: [UUID: AgentRuntime],
        runId: UUID,
        context: ContextSnapshot?,
        workingDirectory: String?,
        previousResults: [MultiAgentStepResult],
        configuration: MultiAgentRunConfiguration
    ) async throws -> MultiAgentStepResult {
            try ensureRunIsActive(runId)
            guard let candidate = candidates.first(where: { $0.agent.id == step.agentId }),
                  let runtime = runtimes[step.agentId] else {
                throw MultiAgentCoordinatorError.missingRuntime(step.agentId)
            }

            let roleConfiguration = configuration.configuration(for: step)
            runtime.configure(
                modelId: roleConfiguration?.modelOverride ?? candidate.agent.model,
                runId: runId,
                workingDirectory: workingDirectory
            )
            let session = try await runtime.connect()
            do {
                try ensureRunIsActive(runId)
            } catch {
                await runtime.disconnect(sessionId: session.id)
                throw error
            }
            activeSessionsByRunId[runId, default: [:]][step.id] = ActiveSession(
                runtime: runtime,
                sessionId: session.id
            )
            var metadata = [
                "planId": plan.id.uuidString,
                "planStepId": step.id.uuidString,
                "role": step.role.rawValue,
                "assistantName": roleConfiguration?.assistantName ?? step.role.label,
                "agentId": candidate.agent.id.uuidString,
                "sessionId": session.id.uuidString
            ]
            if let profileId = configuration.profileId {
                metadata["profileId"] = profileId
            }
            if let profileName = configuration.profileName {
                metadata["profileName"] = profileName
            }
            if let promptFilePath = roleConfiguration?.promptFilePath,
               !promptFilePath.isEmpty {
                metadata["promptFilePath"] = promptFilePath
            }
            recorder.record(
                runId: runId,
                type: .agentStarted,
                message: "\(roleConfiguration?.assistantName ?? step.role.label) session started.",
                metadata: metadata
            )

            var output = ""
            var persistedStreamCharacterCount = 0
            var didRecordStreamLimit = false
            var didRecordUsage = false
            do {
                let execution = try await runtime.run(
                    task: AgentTask(
                        runId: runId,
                        prompt: prompt(
                            for: step,
                            goal: plan.goal,
                            previousResults: previousResults,
                            assistantName: roleConfiguration?.assistantName ?? step.role.label,
                            instructions: roleConfiguration?.instructions ?? "",
                            outputContract: roleConfiguration?.outputContract
                        ),
                        context: context,
                        workingDirectory: workingDirectory
                    ),
                    sessionId: session.id
                )

                for try await event in execution.events {
                    try ensureRunIsActive(runId)
                    switch event {
                    case .textDelta(let delta):
                        output += delta
                        let safeDelta = SensitiveTextRedactor.redact(delta)
                        let remaining = max(
                            0,
                            handoffPolicy.configuration.maxPersistedStreamCharacters
                                - persistedStreamCharacterCount
                        )
                        if remaining > 0 {
                            let boundedDelta = String(safeDelta.prefix(remaining))
                            persistedStreamCharacterCount += boundedDelta.count
                            recorder.record(
                                runId: runId,
                                type: .providerStreamDelta,
                                message: boundedDelta,
                                metadata: metadata
                            )
                        }
                        if safeDelta.count > remaining, !didRecordStreamLimit {
                            didRecordStreamLimit = true
                            recorder.record(
                                runId: runId,
                                type: .providerStreamDelta,
                                message: "[Further stream output retained in the final handoff artifact.]",
                                metadata: metadata.merging(["contentBounded": "true"]) { _, new in new }
                            )
                        }
                    case .messageCompleted(let message):
                        output = message
                    case .toolCallRequested(let name, let input):
                        recorder.record(runId: runId, type: .toolCallRequested, message: name, metadata: metadata.merging(["input": input]) { _, new in new })
                    case .fileChanged(let path):
                        recorder.record(runId: runId, type: .fileChanged, message: path, metadata: metadata)
                    case .approvalRequested(let summary):
                        recorder.record(runId: runId, type: .approvalRequested, message: summary, metadata: metadata)
                    case .tokenUsage(let usage):
                        didRecordUsage = true
                        repository.updateRun(runId) { run in
                            run.tokenUsage.inputTokens += usage.inputTokens
                            run.tokenUsage.outputTokens += usage.outputTokens
                            run.costUsage = CostUsage(totalUSD: run.costUsage.totalUSD + usage.totalCostUSD)
                        }
                        recorder.record(
                            runId: runId,
                            type: .usageUpdated,
                            message: "\(roleConfiguration?.assistantName ?? step.role.label) reported token and cost usage.",
                            metadata: ContextUsageObservation.metadata(
                                usage: usage,
                                snapshot: context,
                                providerId: runtime.id,
                                source: "multiAgentStep",
                                additionalMetadata: metadata
                            )
                        )
                    case .artifactCreated(let artifact):
                        repository.updateRun(runId) { run in run.artifacts.append(artifact) }
                    case .finished(let response):
                        if let usage = response.tokenUsage, !didRecordUsage {
                            repository.updateRun(runId) { run in
                                run.tokenUsage.inputTokens += usage.inputTokens
                                run.tokenUsage.outputTokens += usage.outputTokens
                                run.costUsage = CostUsage(
                                    totalUSD: run.costUsage.totalUSD + usage.totalCostUSD
                                )
                            }
                            recorder.record(
                                runId: runId,
                                type: .usageUpdated,
                                message: "\(roleConfiguration?.assistantName ?? step.role.label) reported final token and cost usage.",
                                metadata: ContextUsageObservation.metadata(
                                    usage: usage,
                                    snapshot: context,
                                    providerId: runtime.id,
                                    source: "multiAgentStepFinal",
                                    additionalMetadata: metadata
                                )
                            )
                        }
                    case .started, .thinking:
                        break
                    case .failed(let message):
                        throw MultiAgentCoordinatorError.stepFailed(step.id, message)
                    }
                }

                try ensureRunIsActive(runId)
                let completedOutput = output.trimmingCharacters(in: .whitespacesAndNewlines)
                let safetyMetadata = metadata.merging([
                    "validationKind": "agentOutputSafety"
                ]) { _, new in new }
                recorder.record(
                    runId: runId,
                    type: .validationStarted,
                    message: "Validating final output for \(roleConfiguration?.assistantName ?? step.role.label).",
                    metadata: safetyMetadata
                )
                let handoff = try handoffPolicy.prepare(
                    output: completedOutput,
                    runId: runId,
                    stepId: step.id,
                    assistantName: roleConfiguration?.assistantName ?? step.role.label,
                    projectRootPath: workingDirectory
                )
                if let artifact = handoff.artifact {
                    recorder.recordArtifact(runId: runId, artifact: artifact)
                    recorder.record(
                        runId: runId,
                        type: .artifactCreated,
                        message: artifact.name,
                        metadata: [
                            "artifactId": artifact.id.uuidString,
                            "kind": artifact.kind,
                            "sourcePlanStepId": step.id.uuidString
                        ]
                    )
                }
                if let rejectionReason = handoff.rejectionReason {
                    recorder.record(
                        runId: runId,
                        type: .validationFinished,
                        message: rejectionReason.message,
                        metadata: safetyMetadata.merging([
                            "status": "failed",
                            "reason": rejectionReason.rawValue
                        ]) { _, new in new }
                    )
                    throw MultiAgentCoordinatorError.stepFailed(
                        step.id,
                        rejectionReason.message
                    )
                }
                recorder.record(
                    runId: runId,
                    type: .validationFinished,
                    message: "Agent output passed safety validation.",
                    metadata: safetyMetadata.merging([
                        "status": "passed"
                    ]) { _, new in new }
                )
                if let outputContract = roleConfiguration?.outputContract {
                    try validateOutput(
                        completedOutput,
                        against: outputContract,
                        runId: runId,
                        stepId: step.id,
                        metadata: metadata
                    )
                }
                if !handoff.content.isEmpty {
                    recorder.record(
                        runId: runId,
                        type: .assistantMessage,
                        message: handoff.content,
                        metadata: metadata.merging(handoff.metadata) { _, new in new }
                    )
                }
                recorder.record(
                    runId: runId,
                    type: .agentFinished,
                    message: "\(roleConfiguration?.assistantName ?? step.role.label) finished.",
                    metadata: metadata
                )
                let result = MultiAgentStepResult(
                    stepId: step.id,
                    role: step.role,
                    agentId: candidate.agent.id,
                    output: handoff.content,
                    sessionId: session.id
                )
                activeSessionsByRunId[runId]?.removeValue(forKey: step.id)
                await runtime.disconnect(sessionId: session.id)
                return result
            } catch {
                activeSessionsByRunId[runId]?.removeValue(forKey: step.id)
                await runtime.disconnect(sessionId: session.id)
                throw error
            }
    }

    private func validateOutput(
        _ output: String,
        against contract: AgentOutputContract,
        runId: UUID,
        stepId: UUID,
        metadata: [String: String]
    ) throws {
        let validationMetadata = metadata.merging([
            "validationKind": "agentOutputContract"
        ]) { _, new in new }
        recorder.record(
            runId: runId,
            type: .validationStarted,
            message: "Validating structured output for \(metadata["assistantName"] ?? "agent").",
            metadata: validationMetadata
        )

        do {
            try outputValidator.validate(output, against: contract)
            recorder.record(
                runId: runId,
                type: .validationFinished,
                message: "Structured output is valid.",
                metadata: validationMetadata.merging(["status": "passed"]) { _, new in new }
            )
        } catch {
            recorder.record(
                runId: runId,
                type: .validationFinished,
                message: error.localizedDescription,
                metadata: validationMetadata.merging(["status": "failed"]) { _, new in new }
            )
            throw MultiAgentCoordinatorError.stepFailed(stepId, error.localizedDescription)
        }
    }

    private func ensureRunIsActive(_ runId: UUID) throws {
        guard !cancelledRunIds.contains(runId), !Task.isCancelled else {
            throw MultiAgentCoordinatorError.cancelled
        }
    }

    private func prompt(
        for step: AgentPlanStep,
        goal: String,
        previousResults: [MultiAgentStepResult],
        assistantName: String,
        instructions: String,
        outputContract: AgentOutputContract?
    ) -> String {
        let priorOutput = previousResults.last?.output ?? "No previous agent output."
        let customInstructions = instructions.isEmpty ? "Use the role's standard responsibilities." : instructions
        let contractInstructions = outputContract?.promptInstructions
            ?? "No structured output contract."
        return """
        Assistant: \(assistantName)
        Role: \(step.role.label)
        Goal: \(goal)

        System instructions:
        \(customInstructions)

        \(contractInstructions)

        Previous step output:
        \(priorOutput)
        """
    }
}

enum MultiAgentCoordinatorError: LocalizedError, Equatable {
    case missingRuntime(UUID)
    case stepFailed(UUID, String)
    case invalidPlan
    case cancelled

    var errorDescription: String? {
        switch self {
        case .missingRuntime(let agentId): "No runtime registered for agent \(agentId.uuidString)."
        case .stepFailed(_, let message): "Multi-agent step failed: \(message)"
        case .invalidPlan: "Multi-agent execution plan contains unresolved dependencies."
        case .cancelled: "Multi-agent run was cancelled."
        }
    }
}
