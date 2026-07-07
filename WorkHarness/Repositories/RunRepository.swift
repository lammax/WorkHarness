//
// RunRepository.swift
// WorkHarness
//
// Created by Auto (Codex) on 07.07.2026.
//

import Foundation
import Observation

@MainActor
protocol RunRepository: BaseRepositoryProtocol {
    var runs: [Run] { get }

    func insert(_ run: Run)
    func appendEvent(_ event: RunEvent)
    func updateRun(_ runId: UUID, mutation: (inout Run) -> Void)
    func run(withId runId: UUID) -> Run?
}

extension RunRepository {
    var repository: AppRepository { .runs }
}

@MainActor
@Observable
final class InMemoryRunRepository: RunRepository {
    private(set) var runs: [Run] = []

    func insert(_ run: Run) {
        runs.insert(run, at: 0)
    }

    func appendEvent(_ event: RunEvent) {
        updateRun(event.runId) { run in
            run.events.append(event)
        }
    }

    func updateRun(_ runId: UUID, mutation: (inout Run) -> Void) {
        guard let index = runs.firstIndex(where: { $0.id == runId }) else { return }
        mutation(&runs[index])
        runs[index].updatedAt = Date()
    }

    func run(withId runId: UUID) -> Run? {
        runs.first { $0.id == runId }
    }
}
