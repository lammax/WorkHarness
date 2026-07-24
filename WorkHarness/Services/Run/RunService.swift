//
// RunService.swift
// WorkHarness
//
// Created by Auto (Codex) on 07.07.2026.
//

import AppKit
import Foundation

@MainActor
final class RunService: RunServiceProtocol {
    private let repository: RunRepository
    private let harnessEngine: HarnessEngine
    private let fileManager: FileManager
    private let artifactOpener: (URL) -> Bool

    init(
        repository: RunRepository,
        harnessEngine: HarnessEngine,
        fileManager: FileManager = .default,
        artifactOpener: @escaping (URL) -> Bool = { NSWorkspace.shared.open($0) }
    ) {
        self.repository = repository
        self.harnessEngine = harnessEngine
        self.fileManager = fileManager
        self.artifactOpener = artifactOpener
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

    func reconcileInterruptedRuns() {
        harnessEngine.reconcileInterruptedRuns()
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

    func startRun(
        goal: String,
        mode: RunMode,
        configuration: MultiAgentRunConfiguration,
        contextAttachments: [RunContextAttachment]
    ) async -> UUID? {
        await harnessEngine.startRun(
            goal: goal,
            mode: mode,
            configuration: configuration,
            contextAttachments: contextAttachments
        )
    }

    func cancelRun(runId: UUID) async {
        await harnessEngine.cancelRun(runId: runId)
    }

    func resumeRun(runId: UUID) async -> Bool {
        await harnessEngine.resumeRun(runId: runId)
    }

    func restartRun(runId: UUID) async -> UUID? {
        await harnessEngine.restartRun(runId: runId)
    }

    func sendMessage(runId: UUID, message: String) async {
        await harnessEngine.sendMessage(runId: runId, message: message)
    }

    func sendMessage(runId: UUID, message: String, contextAttachments: [RunContextAttachment]) async {
        await harnessEngine.sendMessage(
            runId: runId,
            message: message,
            contextAttachments: contextAttachments
        )
    }

    func compactContext(runId: UUID) -> ContextFoldSummary? {
        harnessEngine.compactContext(runId: runId)
    }

    func openArtifact(_ artifact: RunArtifact) -> Bool {
        guard let path = artifact.path, fileManager.fileExists(atPath: path) else {
            return false
        }
        return artifactOpener(URL(fileURLWithPath: path))
    }
}
