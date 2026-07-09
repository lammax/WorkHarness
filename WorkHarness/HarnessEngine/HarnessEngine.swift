//
// HarnessEngine.swift
// WorkHarness
//
// Created by Auto (Codex) on 07.07.2026.
//

import Foundation

@MainActor
final class HarnessEngine {
    private let repository: RunRepository
    private let recorder: RunRecorder
    private let providerService: ProviderServiceProtocol
    private let projectService: ProjectServiceProtocol?
    private let contextBuilder: ContextBuilderProtocol

    init(
        repository: RunRepository,
        recorder: RunRecorder,
        providerService: ProviderServiceProtocol,
        projectService: ProjectServiceProtocol? = nil,
        contextBuilder: ContextBuilderProtocol? = nil
    ) {
        self.repository = repository
        self.recorder = recorder
        self.providerService = providerService
        self.projectService = projectService
        self.contextBuilder = contextBuilder ?? ContextBuilder()
    }

    var providerName: String {
        providerService.activeProviderName
    }

    func startRun(goal: String) async -> UUID? {
        let trimmedGoal = goal.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedGoal.isEmpty else { return nil }

        let provider: any AIProvider
        do {
            provider = try providerService.activeProvider()
        } catch {
            return createFailedRun(goal: trimmedGoal, message: error.localizedDescription)
        }

        let agent = Agent(
            role: .coder,
            providerId: provider.id,
            model: provider.capabilities.supportedModels.first ?? "mock"
        )
        let run = Run(goal: trimmedGoal, agents: [agent])

        repository.insert(run)
        recorder.record(runId: run.id, type: .runCreated, message: trimmedGoal)
        recorder.record(runId: run.id, type: .agentStarted, message: "\(agent.role.label) started with \(provider.displayName).")
        recorder.record(runId: run.id, type: .userMessage, message: trimmedGoal)

        await runSimpleChatLoop(runId: run.id, prompt: trimmedGoal, agent: agent, provider: provider)
        return run.id
    }

    func sendMessage(runId: UUID, message: String) async {
        let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedMessage.isEmpty, let run = repository.run(withId: runId), let agent = run.agents.first else { return }
        let provider: any AIProvider

        do {
            provider = try providerService.activeProvider()
        } catch {
            failRun(runId, message: error.localizedDescription)
            return
        }

        recorder.record(runId: runId, type: .userMessage, message: trimmedMessage)
        repository.updateRun(runId) { run in
            run.status = .running
        }
        await runSimpleChatLoop(runId: runId, prompt: trimmedMessage, agent: agent, provider: provider)
    }

    private func runSimpleChatLoop(runId: UUID, prompt: String, agent: Agent, provider: any AIProvider) async {
        recorder.record(runId: runId, type: .providerRequestStarted, message: provider.displayName, metadata: ["providerId": provider.id, "agentId": agent.id.uuidString])

        do {
            let request = AIRequest(
                runId: runId,
                agent: agent,
                messages: [.init(role: .user, content: prompt)],
                context: context(for: runId, prompt: prompt, agent: agent, provider: provider).contextItems,
                tools: agent.tools,
                budget: .init(maxInputTokens: agent.contextPolicy.maxInputTokens, maxOutputTokens: nil)
            )
            let stream = try await provider.send(request)
            var completedMessage = ""

            for try await event in stream {
                switch event {
                case .started:
                    recorder.record(runId: runId, type: .providerRequestStarted, message: "Provider stream opened.", metadata: ["providerId": provider.id])
                case .messageDelta(let delta):
                    recorder.record(runId: runId, type: .providerStreamDelta, message: delta)
                case .messageCompleted(let message):
                    completedMessage = message
                    recorder.record(runId: runId, type: .assistantMessage, message: message)
                case .toolCall(let name, let input):
                    recorder.record(runId: runId, type: .toolCallRequested, message: name, metadata: ["input": input])
                case .tokenUsage(let usage):
                    repository.updateRun(runId) { run in
                        run.tokenUsage = usage
                        run.costUsage = CostUsage(totalUSD: usage.totalCostUSD)
                    }
                case .finished:
                    recorder.record(runId: runId, type: .providerRequestFinished, message: completedMessage.isEmpty ? "Provider finished." : completedMessage)
                case .error(let message):
                    recorder.record(runId: runId, type: .providerRequestFailed, message: message, metadata: ["providerId": provider.id])
                    failRun(runId, message: message)
                    return
                }
            }

            repository.updateRun(runId) { run in
                run.status = .completed
            }
            recorder.record(runId: runId, type: .agentFinished, message: "\(agent.role.label) finished.")
            recorder.record(runId: runId, type: .runCompleted, message: "Run completed.")
        } catch {
            failRun(runId, message: error.localizedDescription)
        }
    }

    private func context(for runId: UUID, prompt: String, agent: Agent, provider: any AIProvider) -> ContextSnapshot {
        let currentProject = projectService?.currentProject
        let snapshot = contextBuilder.buildSnapshot(from: ContextBuildInput(
            runId: runId,
            agent: agent,
            providerId: provider.id,
            userMessage: prompt,
            currentProject: currentProject,
            rootPath: currentProject?.rootPath,
            tokenBudget: .init(maxInputTokens: agent.contextPolicy.maxInputTokens, maxOutputTokens: nil)
        ))

        recorder.record(
            runId: runId,
            type: .contextBuilt,
            message: snapshot.summary,
            metadata: [
                "contextSnapshotId": snapshot.id.uuidString,
                "providerId": provider.id,
                "agentId": agent.id.uuidString,
                "tokenEstimate": "\(snapshot.tokenCount)"
            ]
        )

        return snapshot
    }

    private func failRun(_ runId: UUID, message: String) {
        recorder.record(runId: runId, type: .error, message: message)
        repository.updateRun(runId) { run in
            run.status = .failed
        }
        recorder.record(runId: runId, type: .runFailed, message: message)
    }

    private func createFailedRun(goal: String, message: String) -> UUID {
        let run = Run(goal: goal, status: .failed)
        repository.insert(run)
        recorder.record(runId: run.id, type: .runCreated, message: goal)
        recorder.record(runId: run.id, type: .error, message: message)
        recorder.record(runId: run.id, type: .runFailed, message: message)
        return run.id
    }
}
