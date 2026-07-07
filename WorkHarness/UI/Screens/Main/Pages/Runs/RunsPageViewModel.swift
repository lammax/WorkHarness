//
// RunsPageViewModel.swift
// WorkHarness
//
// Created by Auto (Codex) on 07.07.2026.
//

import Observation

extension MainScreen {
    @MainActor
    @Observable
    final class RunsPageViewModel {
        private let runService: RunServiceProtocol

        init(runService: RunServiceProtocol) {
            self.runService = runService
        }

        var runs: [Run] {
            runService.runs
        }

        func summary(for run: Run) -> String {
            let totalTokens = run.tokenUsage.inputTokens + run.tokenUsage.outputTokens
            return "\(run.events.count)\(RunsPageDesign.Row.eventsSuffix)\(RunsPageDesign.Row.eventsTokensSeparator)\(totalTokens)\(RunsPageDesign.Row.tokensSuffix)"
        }
    }
}
