//
// StatsPageViewModel.swift
// WorkHarness
//
// Created by Auto (Codex) on 09.07.2026.
//

import Foundation
import Observation

extension MainScreen {
    @MainActor
    @Observable
    final class StatsPageViewModel {
        private let statisticsService: UsageStatisticsServiceProtocol

        init(statisticsService: UsageStatisticsServiceProtocol) {
            self.statisticsService = statisticsService
        }

        var summaryCards: [StatsSummaryCardState] {
            let total = statisticsService.snapshot.total
            return [
                StatsSummaryCardState(title: StatsPageDesign.Summary.runsTitle, value: "\(total.runCount)"),
                StatsSummaryCardState(title: StatsPageDesign.Summary.inputTitle, value: tokenLabel(total.inputTokens)),
                StatsSummaryCardState(title: StatsPageDesign.Summary.outputTitle, value: tokenLabel(total.outputTokens)),
                StatsSummaryCardState(title: StatsPageDesign.Summary.totalTitle, value: tokenLabel(total.totalTokens)),
                StatsSummaryCardState(title: StatsPageDesign.Summary.costTitle, value: costLabel(total.totalCostUSD))
            ]
        }

        var providerRows: [StatsProviderRowState] {
            statisticsService.snapshot.providers.map { provider in
                StatsProviderRowState(
                    id: provider.providerId,
                    providerId: provider.providerId,
                    runs: "\(provider.runCount)",
                    tokens: tokenLabel(provider.totalTokens),
                    cost: costLabel(provider.totalCostUSD)
                )
            }
        }

        var runRows: [StatsRunRowState] {
            statisticsService.snapshot.runs.map { run in
                StatsRunRowState(
                    id: run.runId,
                    title: run.title,
                    subtitle: "\(run.providerId)\(StatsPageDesign.Row.separator)\(run.createdAt.formatted(date: .abbreviated, time: .shortened))",
                    tokens: tokenLabel(run.totalTokens),
                    cost: costLabel(run.totalCostUSD)
                )
            }
        }

        var dailyRows: [StatsDailyRowState] {
            statisticsService.snapshot.days.map { day in
                StatsDailyRowState(
                    id: day.day,
                    title: day.day.formatted(date: .abbreviated, time: .omitted),
                    runs: "\(day.runCount)",
                    tokens: tokenLabel(day.totalTokens),
                    cost: costLabel(day.totalCostUSD)
                )
            }
        }

        var isEmpty: Bool {
            statisticsService.snapshot.total.runCount == 0
        }

        private func tokenLabel(_ value: Int) -> String {
            "\(value)"
        }

        private func costLabel(_ cost: Decimal) -> String {
            guard cost != 0 else { return StatsPageDesign.Summary.zeroCostValue }
            return "\(StatsPageDesign.Summary.costPrefix)\(NSDecimalNumber(decimal: cost).stringValue)"
        }
    }

    struct StatsSummaryCardState: Identifiable, Equatable {
        var id: String { title }
        var title: String
        var value: String
    }

    struct StatsProviderRowState: Identifiable, Equatable {
        var id: String
        var providerId: String
        var runs: String
        var tokens: String
        var cost: String
    }

    struct StatsRunRowState: Identifiable, Equatable {
        var id: UUID
        var title: String
        var subtitle: String
        var tokens: String
        var cost: String
    }

    struct StatsDailyRowState: Identifiable, Equatable {
        var id: Date
        var title: String
        var runs: String
        var tokens: String
        var cost: String
    }
}
