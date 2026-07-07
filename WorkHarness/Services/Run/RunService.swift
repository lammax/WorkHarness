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

    func run(withId runId: UUID) -> Run? {
        repository.run(withId: runId)
    }

    func startRun(goal: String) async -> UUID? {
        await harnessEngine.startRun(goal: goal)
    }

    func sendMessage(runId: UUID, message: String) async {
        await harnessEngine.sendMessage(runId: runId, message: message)
    }
}
