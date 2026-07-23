//
// RunService.swift
// WorkHarness
//
// Created by Auto (Codex) on 07.07.2026.
//

import Foundation

@MainActor
final class RunService: RunServiceProtocol {
    private let repository: RunRepository
    private let harnessEngine: HarnessEngine

    init(repository: RunRepository, harnessEngine: HarnessEngine) {
        self.repository = repository
        self.harnessEngine = harnessEngine
    }

    var runs: [Run] {
        repository.runs
    }

    var providerName: String {
        harnessEngine.providerName
    }

    var selectedAgentRuntimeDescriptor: AgentRuntimeDescriptor? {
        harnessEngine.selectedAgentRuntimeDescriptor
    }

    func run(withId runId: UUID) -> Run? {
        repository.run(withId: runId)
    }

    func startRun(goal: String) async -> UUID? {
        await harnessEngine.startRun(goal: goal)
    }

    func startRun(goal: String, mode: RunMode) async -> UUID? {
        await harnessEngine.startRun(goal: goal, mode: mode)
    }

    func startRun(goal: String, mode: RunMode, configuration: MultiAgentRunConfiguration) async -> UUID? {
        await harnessEngine.startRun(goal: goal, mode: mode, configuration: configuration)
    }

    func cancelRun(runId: UUID) async {
        await harnessEngine.cancelRun(runId: runId)
    }

    func sendMessage(runId: UUID, message: String) async {
        await harnessEngine.sendMessage(runId: runId, message: message)
    }

    func compactContext(runId: UUID) -> ContextFoldSummary? {
        harnessEngine.compactContext(runId: runId)
    }
}
