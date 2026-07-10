//
// RunServiceProtocol.swift
// WorkHarness
//
// Created by Auto (Codex) on 07.07.2026.
//

import Foundation

@MainActor
protocol RunServiceProtocol: BaseServiceProtocol {
    var runs: [Run] { get }
    var providerName: String { get }

    func run(withId runId: UUID) -> Run?
    func startRun(goal: String) async -> UUID?
    func startRun(goal: String, mode: RunMode) async -> UUID?
    func sendMessage(runId: UUID, message: String) async
    func compactContext(runId: UUID) -> ContextFoldSummary?
}

extension RunServiceProtocol {
    var service: AppService { .runs }
}
