//
// RunRecorder.swift
// WorkHarness
//
// Created by Auto (Codex) on 07.07.2026.
//

import Foundation

@MainActor
final class RunRecorder {
    private struct EventMirror {
        var targetRunId: UUID
        var messagePrefix: String
        var metadata: [String: String]
    }

    private let repository: RunRepository
    private var eventMirrors: [UUID: EventMirror] = [:]

    init(repository: RunRepository) {
        self.repository = repository
    }

    func record(runId: UUID, type: RunEventType, message: String, metadata: [String: String] = [:]) {
        repository.appendEvent(.init(runId: runId, type: type, message: message, metadata: metadata))

        guard let mirror = eventMirrors[runId],
              Self.mirroredProgressEventTypes.contains(type) else {
            return
        }
        var mirroredMetadata = metadata
        mirror.metadata.forEach { mirroredMetadata[$0.key] = $0.value }
        mirroredMetadata["sourceRunId"] = runId.uuidString
        repository.appendEvent(.init(
            runId: mirror.targetRunId,
            type: type,
            message: "\(mirror.messagePrefix)\(message)",
            metadata: mirroredMetadata
        ))
    }

    func recordArtifact(runId: UUID, artifact: RunArtifact) {
        repository.updateRun(runId) { run in
            run.artifacts.append(artifact)
        }
    }

    func beginMirroringProgress(
        from sourceRunId: UUID,
        to targetRunId: UUID,
        messagePrefix: String,
        metadata: [String: String]
    ) {
        eventMirrors[sourceRunId] = EventMirror(
            targetRunId: targetRunId,
            messagePrefix: messagePrefix,
            metadata: metadata
        )
    }

    func endMirroringProgress(from sourceRunId: UUID) {
        eventMirrors.removeValue(forKey: sourceRunId)
    }

    private static let mirroredProgressEventTypes: Set<RunEventType> = [
        .assistantMessage,
        .agentStarted,
        .agentFinished,
        .artifactCreated,
        .fileChanged,
        .approvalRequested,
        .approvalGranted,
        .approvalRejected,
        .error,
        .runInterrupted,
        .runResumed,
        .runCompleted,
        .runCancelled,
        .runFailed
    ]
}
