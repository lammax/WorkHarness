//
// StatsPageView.swift
// WorkHarness
//
// Created by Auto (Codex) on 09.07.2026.
//

import SwiftUI

extension MainScreen {
    struct StatsPageView: View {
        typealias Design = StatsPageDesign

        @Bindable var viewModel: StatsPageViewModel

        var body: some View {
            if viewModel.isEmpty {
                ContentUnavailableView(
                    Design.EmptyState.title,
                    systemImage: Design.EmptyState.icon,
                    description: Text(Design.EmptyState.description)
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: Design.Layout.spacing) {
                        header
                        summaryCards
                        StatsSection(title: Design.Section.providersTitle) {
                            ForEach(viewModel.providerRows) { row in
                                ProviderUsageRow(row: row)
                            }
                        }
                        StatsSection(title: Design.Section.daysTitle) {
                            ForEach(viewModel.dailyRows) { row in
                                DailyUsageRow(row: row)
                            }
                        }
                        StatsSection(title: Design.Section.runsTitle) {
                            ForEach(viewModel.runRows) { row in
                                RunUsageRow(row: row)
                            }
                        }
                    }
                    .padding(Design.Layout.padding)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }

        private var header: some View {
            VStack(alignment: .leading, spacing: Design.Layout.rowSpacing) {
                Text(Design.Header.title)
                    .font(.title2)
                    .fontWeight(.semibold)
                Text(Design.Header.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }

        private var summaryCards: some View {
            HStack(spacing: Design.Layout.cardSpacing) {
                ForEach(viewModel.summaryCards) { card in
                    VStack(alignment: .leading, spacing: Design.Layout.rowSpacing) {
                        Text(card.title)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(card.value)
                            .font(.title3)
                            .fontWeight(.semibold)
                    }
                    .frame(minWidth: Design.Layout.minSummaryWidth, alignment: .leading)
                    .padding(Design.Layout.cardPadding)
                    .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: Design.Layout.cornerRadius))
                }

                Spacer()
            }
        }
    }

    private struct StatsSection<Content: View>: View {
        typealias Design = StatsPageDesign

        let title: String
        @ViewBuilder let content: Content

        var body: some View {
            VStack(alignment: .leading, spacing: Design.Layout.cardSpacing) {
                Text(title)
                    .font(.headline)

                VStack(alignment: .leading, spacing: 0) {
                    content
                }
                .background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: Design.Layout.cornerRadius))
            }
        }
    }

    private struct ProviderUsageRow: View {
        typealias Design = StatsPageDesign

        let row: StatsProviderRowState

        var body: some View {
            HStack(spacing: Design.Layout.cardSpacing) {
                Text(row.providerId)
                    .font(.body)
                    .lineLimit(1)
                Spacer()
                metric(row.runs, title: Design.Section.runsColumn)
                metric(row.tokens, title: Design.Section.tokensColumn)
                metric(row.cost, title: Design.Section.costColumn)
            }
            .padding(Design.Layout.cardPadding)
        }

        private func metric(_ value: String, title: String) -> some View {
            VStack(alignment: .trailing, spacing: 2) {
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.callout)
                    .fontWeight(.medium)
            }
            .frame(width: Design.Row.metricWidth, alignment: .trailing)
        }
    }

    private struct DailyUsageRow: View {
        typealias Design = StatsPageDesign

        let row: StatsDailyRowState

        var body: some View {
            HStack(spacing: Design.Layout.cardSpacing) {
                Text(row.title)
                    .font(.body)
                Spacer()
                metric(row.runs, title: Design.Section.runsColumn)
                metric(row.tokens, title: Design.Section.tokensColumn)
                metric(row.cost, title: Design.Section.costColumn)
            }
            .padding(Design.Layout.cardPadding)
        }

        private func metric(_ value: String, title: String) -> some View {
            VStack(alignment: .trailing, spacing: 2) {
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.callout)
                    .fontWeight(.medium)
            }
            .frame(width: Design.Row.metricWidth, alignment: .trailing)
        }
    }

    private struct RunUsageRow: View {
        typealias Design = StatsPageDesign

        let row: StatsRunRowState

        var body: some View {
            HStack(spacing: Design.Layout.cardSpacing) {
                VStack(alignment: .leading, spacing: Design.Layout.rowSpacing) {
                    Text(row.title)
                        .font(.body)
                        .lineLimit(1)
                    Text(row.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Text(row.tokens)
                    .font(.callout)
                    .fontWeight(.medium)
                    .frame(width: Design.Row.metricWidth, alignment: .trailing)
                Text(row.cost)
                    .font(.callout)
                    .fontWeight(.medium)
                    .frame(width: Design.Row.metricWidth, alignment: .trailing)
            }
            .padding(Design.Layout.cardPadding)
        }
    }
}
