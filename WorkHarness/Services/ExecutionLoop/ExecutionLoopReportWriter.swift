//
// ExecutionLoopReportWriter.swift
// WorkHarness
//
// Created by Auto (Codex) on 26.07.2026.
//

import Foundation

struct ExecutionLoopReportWriter {
    private let fileManager: FileManager
    private let reportsRootURL: URL?
    private let now: () -> Date

    init(
        fileManager: FileManager = .default,
        reportsRootURL: URL? = nil,
        now: @escaping () -> Date = Date.init
    ) {
        self.fileManager = fileManager
        self.reportsRootURL = reportsRootURL
        self.now = now
    }

    func write(_ attempt: ExecutionLoopAttempt) throws -> URL {
        let directoryURL = reportsRootURL ?? defaultReportsRootURL
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        let reportURL = directoryURL
            .appendingPathComponent("execution-\(attempt.id.uuidString.lowercased())")
            .appendingPathExtension("md")
        try markdown(for: attempt).write(
            to: reportURL,
            atomically: true,
            encoding: .utf8
        )
        return reportURL
    }

    func markdown(for attempt: ExecutionLoopAttempt) -> String {
        let formatter = ISO8601DateFormatter()
        let percentage = Int((attempt.firstPassSuccessRate * 100).rounded())
        let rows = attempt.taskResults.map { result -> String in
            let routingLatency = result.routingLatencyMilliseconds.map { "\($0)ms" } ?? "—"
            let routingCost = result.routingCostUSD.map { String(format: "$%.6f", $0) } ?? "—"
            let columns: [String] = [
                result.taskId,
                escaped(result.title),
                result.profileId,
                result.runtimeName ?? "—",
                result.runtimeId ?? "—",
                result.modelId ?? "—",
                result.routingRoute ?? "—",
                result.routingReason ?? "—",
                result.escalationReason ?? "—",
                routingLatency,
                routingCost,
                result.status.rawValue,
                "\(result.attemptNumber ?? 1)",
                result.failureKind?.rawValue ?? "—",
                duration(result.duration),
                result.buildPassed ? "passed" : "not passed",
                result.testsPassed ? "passed" : "not passed",
                result.commitSHA ?? "—",
                result.pushSucceeded ? "pushed" : "not pushed",
                escaped(result.failureReason ?? "—")
            ]
            return "| \(columns.joined(separator: " | ")) |"
        }.joined(separator: "\n")

        return """
        # Day 5 Execution Loop Report

        - Attempt: `\(attempt.id.uuidString)`
        - Generated: `\(formatter.string(from: now()))`
        - Status: `\(attempt.status.rawValue)`
        - Source: `\(attempt.sourcePath)`
        - Target repository: `\(attempt.targetRepositoryPath)`
        - Base branch: `\(attempt.baseBranch)`
        - Base commit: `\(attempt.baseCommitSHA ?? "—")`
        - Execution branch: `\(attempt.executionBranch ?? "—")`
        - Started: `\(formatter.string(from: attempt.startedAt))`
        - Finished: `\(attempt.finishedAt.map(formatter.string(from:)) ?? "—")`
        - Stop reason: \(attempt.stopReason ?? "—")

        ## Metrics

        - Consecutive tasks passed without intervention: \(attempt.consecutivePassedTaskCount)
        - Attempted tasks: \(attempt.attemptedTaskCount)
        - Passed tasks: \(attempt.passedTaskCount)
        - Average time per attempted task: \(duration(attempt.averageAttemptedTaskDuration))
        - Average time per passed task: \(duration(attempt.averagePassedTaskDuration))
        - First-pass success rate: \(percentage)%

        ## Task Log

        | Task | Title | Profile | Agent | Runtime ID | Model | Route | Route reason | Escalation | Routing latency | Cost before fallback | Result | Attempt | Failure kind | Time | Build | Tests | Commit | Push | Failure |
        | --- | --- | --- | --- | --- | --- | --- | --- | --- | ---: | ---: | --- | ---: | --- | ---: | --- | --- | --- | --- | --- |
        \(rows.isEmpty ? "| — | — | — | — | — | — | — | — | — | — | — | — | — | — | — | — | — | — | — | — |" : rows)
        """
    }

    private func duration(_ interval: TimeInterval) -> String {
        String(format: "%.1fs", interval)
    }

    private func escaped(_ value: String) -> String {
        value
            .replacingOccurrences(of: "|", with: "\\|")
            .replacingOccurrences(of: "\n", with: " ")
    }

    private var defaultReportsRootURL: URL {
        let applicationSupportURL = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? fileManager.temporaryDirectory
        return applicationSupportURL
            .appendingPathComponent("WorkHarness", isDirectory: true)
            .appendingPathComponent("ExecutionLoopReports", isDirectory: true)
    }
}
