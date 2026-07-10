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
    private let repository: RunRepository
    private let recorder: RunRecorder

    init(repository: RunRepository, recorder: RunRecorder) {
        self.repository = repository
        self.recorder = recorder
    }

    func execute(
        plan: AgentExecutionPlan,
        candidates: [AgentCandidate],
        runtimes: [UUID: AgentRuntime],
        runId: UUID,
        context: ContextSnapshot? = nil,
        workingDirectory: String? = nil
    ) async throws -> MultiAgentExecutionResult {
        var results: [MultiAgentStepResult] = []

        for step in plan.steps {
            guard let candidate = candidates.first(where: { $0.agent.id == step.agentId }),
                  let runtime = runtimes[step.agentId] else {
                throw MultiAgentCoordinatorError.missingRuntime(step.agentId)
            }

            runtime.configure(modelId: candidate.agent.model, runId: runId)
            let session = try await runtime.connect()
            let metadata = [
                "planId": plan.id.uuidString,
                "planStepId": step.id.uuidString,
                "role": step.role.rawValue,
                "agentId": candidate.agent.id.uuidString,
                "sessionId": session.id.uuidString
            ]
            recorder.record(
                runId: runId,
                type: .agentStarted,
                message: "\(step.role.label) session started.",
                metadata: metadata
            )

            var output = ""
            do {
                let execution = try await runtime.run(
                    task: AgentTask(
                        runId: runId,
                        prompt: prompt(for: step, goal: plan.goal, previousResults: results),
                        context: context,
                        workingDirectory: workingDirectory
                    ),
                    sessionId: session.id
                )

                for try await event in execution.events {
                    switch event {
                    case .textDelta(let delta):
                        output += delta
                        recorder.record(runId: runId, type: .providerStreamDelta, message: delta, metadata: metadata)
                    case .messageCompleted(let message):
                        output = message
                        recorder.record(runId: runId, type: .assistantMessage, message: message, metadata: metadata)
                    case .toolCallRequested(let name, let input):
                        recorder.record(runId: runId, type: .toolCallRequested, message: name, metadata: metadata.merging(["input": input]) { _, new in new })
                    case .fileChanged(let path):
                        recorder.record(runId: runId, type: .fileChanged, message: path, metadata: metadata)
                    case .approvalRequested(let summary):
                        recorder.record(runId: runId, type: .approvalRequested, message: summary, metadata: metadata)
                    case .tokenUsage(let usage):
                        repository.updateRun(runId) { run in
                            run.tokenUsage.inputTokens += usage.inputTokens
                            run.tokenUsage.outputTokens += usage.outputTokens
                            run.costUsage = CostUsage(totalUSD: run.costUsage.totalUSD + usage.totalCostUSD)
                        }
                    case .artifactCreated(let artifact):
                        repository.updateRun(runId) { run in run.artifacts.append(artifact) }
                    case .finished:
                        break
                    case .started, .thinking:
                        break
                    case .failed(let message):
                        throw MultiAgentCoordinatorError.stepFailed(step.id, message)
                    }
                }

                recorder.record(runId: runId, type: .agentFinished, message: "\(step.role.label) finished.", metadata: metadata)
                results.append(MultiAgentStepResult(
                    stepId: step.id,
                    role: step.role,
                    agentId: candidate.agent.id,
                    output: output,
                    sessionId: session.id
                ))
                await runtime.disconnect(sessionId: session.id)
            } catch {
                await runtime.disconnect(sessionId: session.id)
                throw error
            }
        }

        return MultiAgentExecutionResult(planId: plan.id, steps: results)
    }

    private func prompt(for step: AgentPlanStep, goal: String, previousResults: [MultiAgentStepResult]) -> String {
        let priorOutput = previousResults.last?.output ?? "No previous agent output."
        return "Role: \(step.role.label)\nGoal: \(goal)\nPrevious step output:\n\(priorOutput)"
    }
}

enum MultiAgentCoordinatorError: LocalizedError, Equatable {
    case missingRuntime(UUID)
    case stepFailed(UUID, String)

    var errorDescription: String? {
        switch self {
        case .missingRuntime(let agentId): "No runtime registered for agent \(agentId.uuidString)."
        case .stepFailed(_, let message): "Multi-agent step failed: \(message)"
        }
    }
}
