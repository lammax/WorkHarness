//
// RunRecorder.swift
// WorkHarness
//
// Created by Auto (Codex) on 07.07.2026.
//

import Foundation

@MainActor
final class RunRecorder {
    private let repository: RunRepository

    init(repository: RunRepository) {
        self.repository = repository
    }

    func record(runId: UUID, type: RunEventType, message: String, metadata: [String: String] = [:]) {
        repository.appendEvent(.init(runId: runId, type: type, message: message, metadata: metadata))
    }

    func recordArtifact(runId: UUID, artifact: RunArtifact) {
        repository.updateRun(runId) { run in
            run.artifacts.append(artifact)
        }
    }
}
