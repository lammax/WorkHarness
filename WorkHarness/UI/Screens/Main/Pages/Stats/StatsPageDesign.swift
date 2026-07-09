//
// StatsPageDesign.swift
// WorkHarness
//
// Created by Auto (Codex) on 09.07.2026.
//

import CoreGraphics

extension MainScreen {
    enum StatsPageDesign {
        enum Layout {
            static let spacing: CGFloat = 18
            static let padding: CGFloat = 18
            static let cardSpacing: CGFloat = 10
            static let cardPadding: CGFloat = 12
            static let cornerRadius: CGFloat = 8
            static let minSummaryWidth: CGFloat = 112
            static let rowSpacing: CGFloat = 6
        }

        enum Header {
            static let title = "Stats"
            static let subtitle = "Token and cost usage by run, provider and day"
        }

        enum Summary {
            static let runsTitle = "Runs"
            static let inputTitle = "Input"
            static let outputTitle = "Output"
            static let totalTitle = "Total"
            static let costTitle = "Cost"
            static let zeroCostValue = "$0"
            static let costPrefix = "$"
        }

        enum Section {
            static let providersTitle = "Providers"
            static let runsTitle = "Runs"
            static let daysTitle = "Days"
            static let runsColumn = "Runs"
            static let tokensColumn = "Tokens"
            static let costColumn = "Cost"
        }

        enum Row {
            static let separator = " · "
            static let metricWidth: CGFloat = 72
        }

        enum EmptyState {
            static let title = "No Usage"
            static let icon = "chart.bar.xaxis"
            static let description = "Token and cost statistics will appear after runs report usage."
        }
    }
}
