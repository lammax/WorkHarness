//
// RunsPageDesign.swift
// WorkHarness
//
// Created by Auto (Codex) on 07.07.2026.
//

import CoreGraphics

extension MainScreen {
    enum RunsPageDesign {
        enum Layout {
            static let spacing: CGFloat = 0
        }

        enum Header {
            static let title = "Runs"
            static let padding: CGFloat = 16
        }

        enum Row {
            static let spacing: CGFloat = 6
            static let verticalPadding: CGFloat = 4
            static let eventsTokensSeparator = " · "
            static let eventsSuffix = " events"
            static let tokensSuffix = " tokens"
        }

        enum EmptyState {
            static let title = "No Runs"
            static let icon = "play.square.stack"
            static let description = "Start from Chat to create the first run."
        }
    }
}
