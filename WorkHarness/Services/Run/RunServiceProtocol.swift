//
// RunServiceProtocol.swift
// WorkHarness
//
// Created by Auto (Codex) on 07.07.2026.
//

import Foundation

@MainActor
protocol RunLaunchingProtocol: AnyObject {
    func startRun(goal: String, mode: RunMode, configuration: MultiAgentRunConfiguration) async -> UUID?
}

@MainActor
protocol RunServiceProtocol: BaseServiceProtocol, RunLaunchingProtocol {
    var runs: [Run] { get }
    var providerName: String { get }
    var selectedAgentRuntimeDescriptor: AgentRuntimeDescriptor? { get }

    func reconcileInterruptedRuns()
    func run(withId runId: UUID) -> Run?
    func startRun(goal: String) async -> UUID?
    func startRun(goal: String, mode: RunMode) async -> UUID?
    func startRun(
        goal: String,
        mode: RunMode,
        configuration: MultiAgentRunConfiguration,
        contextAttachments: [RunContextAttachment]
    ) async -> UUID?
    func resumeRun(runId: UUID) async -> Bool
    func restartRun(runId: UUID) async -> UUID?
    func cancelRun(runId: UUID) async
    func sendMessage(runId: UUID, message: String) async
    func sendMessage(runId: UUID, message: String, contextAttachments: [RunContextAttachment]) async
    func compactContext(runId: UUID) -> ContextFoldSummary?
    func openArtifact(_ artifact: RunArtifact) -> Bool
}

extension RunServiceProtocol {
    var service: AppService { .runs }
}
