//
// UsageStatisticsServiceProtocol.swift
// WorkHarness
//
// Created by Auto (Codex) on 09.07.2026.
//

import Foundation

@MainActor
protocol UsageStatisticsServiceProtocol: BaseServiceProtocol {
    var snapshot: UsageStatisticsSnapshot { get }
}

extension UsageStatisticsServiceProtocol {
    var service: AppService { .statistics }
}

struct UsageStatisticsSnapshot: Equatable {
    var total: UsageStatisticsTotal
    var providers: [ProviderUsageSummary]
    var runs: [RunUsageSummary]
    var days: [DailyUsageSummary]
}

struct UsageStatisticsTotal: Equatable {
    var runCount: Int
    var inputTokens: Int
    var outputTokens: Int
    var totalTokens: Int
    var totalCostUSD: Decimal

    static let empty = UsageStatisticsTotal(
        runCount: 0,
        inputTokens: 0,
        outputTokens: 0,
        totalTokens: 0,
        totalCostUSD: 0
    )
}

struct ProviderUsageSummary: Identifiable, Equatable {
    var id: String { providerId }
    var providerId: String
    var runCount: Int
    var inputTokens: Int
    var outputTokens: Int
    var totalTokens: Int
    var totalCostUSD: Decimal
}

struct RunUsageSummary: Identifiable, Equatable {
    var id: UUID { runId }
    var runId: UUID
    var title: String
    var providerId: String
    var createdAt: Date
    var inputTokens: Int
    var outputTokens: Int
    var totalTokens: Int
    var totalCostUSD: Decimal
}

struct DailyUsageSummary: Identifiable, Equatable {
    var id: Date { day }
    var day: Date
    var runCount: Int
    var inputTokens: Int
    var outputTokens: Int
    var totalTokens: Int
    var totalCostUSD: Decimal
}
