//
// UsageStatisticsService.swift
// WorkHarness
//
// Created by Auto (Codex) on 09.07.2026.
//

import Foundation

@MainActor
final class UsageStatisticsService: UsageStatisticsServiceProtocol {
    private enum Constants {
        static let unknownProviderId = "unknown.provider"
        static let providerIdMetadataKey = "providerId"
    }

    private let runService: RunServiceProtocol
    private let calendar: Calendar

    init(runService: RunServiceProtocol, calendar: Calendar = .current) {
        self.runService = runService
        self.calendar = calendar
    }

    var snapshot: UsageStatisticsSnapshot {
        let runSummaries = runService.runs.map(runSummary(for:))

        return UsageStatisticsSnapshot(
            total: totalSummary(for: runSummaries),
            providers: providerSummaries(for: runSummaries),
            runs: runSummaries.sorted { $0.createdAt > $1.createdAt },
            days: dailySummaries(for: runSummaries)
        )
    }

    private func runSummary(for run: Run) -> RunUsageSummary {
        let inputTokens = run.tokenUsage.inputTokens
        let outputTokens = run.tokenUsage.outputTokens
        let totalTokens = inputTokens + outputTokens

        return RunUsageSummary(
            runId: run.id,
            title: run.goal,
            providerId: providerId(for: run),
            createdAt: run.createdAt,
            inputTokens: inputTokens,
            outputTokens: outputTokens,
            totalTokens: totalTokens,
            totalCostUSD: run.costUsage.totalUSD
        )
    }

    private func providerId(for run: Run) -> String {
        if let providerId = run.agents.first?.providerId, !providerId.isEmpty {
            return providerId
        }

        if let providerId = run.events.first(where: { $0.metadata[Constants.providerIdMetadataKey] != nil })?
            .metadata[Constants.providerIdMetadataKey],
           !providerId.isEmpty {
            return providerId
        }

        return Constants.unknownProviderId
    }

    private func totalSummary(for runs: [RunUsageSummary]) -> UsageStatisticsTotal {
        runs.reduce(.empty) { partial, run in
            UsageStatisticsTotal(
                runCount: partial.runCount + 1,
                inputTokens: partial.inputTokens + run.inputTokens,
                outputTokens: partial.outputTokens + run.outputTokens,
                totalTokens: partial.totalTokens + run.totalTokens,
                totalCostUSD: partial.totalCostUSD + run.totalCostUSD
            )
        }
    }

    private func providerSummaries(for runs: [RunUsageSummary]) -> [ProviderUsageSummary] {
        Dictionary(grouping: runs, by: \.providerId)
            .map { providerId, runs in
                ProviderUsageSummary(
                    providerId: providerId,
                    runCount: runs.count,
                    inputTokens: runs.reduce(0) { $0 + $1.inputTokens },
                    outputTokens: runs.reduce(0) { $0 + $1.outputTokens },
                    totalTokens: runs.reduce(0) { $0 + $1.totalTokens },
                    totalCostUSD: runs.reduce(0) { $0 + $1.totalCostUSD }
                )
            }
            .sorted { first, second in
                if first.totalTokens == second.totalTokens {
                    return first.providerId < second.providerId
                }
                return first.totalTokens > second.totalTokens
            }
    }

    private func dailySummaries(for runs: [RunUsageSummary]) -> [DailyUsageSummary] {
        Dictionary(grouping: runs) { run in
            calendar.startOfDay(for: run.createdAt)
        }
        .map { day, runs in
            DailyUsageSummary(
                day: day,
                runCount: runs.count,
                inputTokens: runs.reduce(0) { $0 + $1.inputTokens },
                outputTokens: runs.reduce(0) { $0 + $1.outputTokens },
                totalTokens: runs.reduce(0) { $0 + $1.totalTokens },
                totalCostUSD: runs.reduce(0) { $0 + $1.totalCostUSD }
            )
        }
        .sorted { $0.day > $1.day }
    }
}
