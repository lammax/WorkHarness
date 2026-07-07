//
// AppDesign.swift
// WorkHarness
//
// Created by Auto (Codex) on 07.07.2026.
//

import SwiftUI

enum AppDesign {
    enum Window {
        static let minWidth: CGFloat = 960
        static let minHeight: CGFloat = 640
        static let sidebarMinWidth: CGFloat = 220
        static let sidebarIdealWidth: CGFloat = 260
    }

    enum Navigation {
        static let workspaceSectionTitle = "Workspace"
        static let recentRunsSectionTitle = "Recent Runs"
        static let appTitle = "WorkHarness"

        static func title(for section: NavigationSection) -> String {
            switch section {
            case .chat: "Chat"
            case .runs: "Runs"
            case .agents: "Agents"
            case .tools: "Tools"
            case .memory: "Memory"
            case .stats: "Stats"
            case .settings: "Settings"
            }
        }

        static func icon(for section: NavigationSection) -> String {
            switch section {
            case .chat: "bubble.left.and.bubble.right"
            case .runs: "play.square.stack"
            case .agents: "person.2"
            case .tools: "wrench.and.screwdriver"
            case .memory: "brain"
            case .stats: "chart.bar.xaxis"
            case .settings: "gearshape"
            }
        }
    }

    enum Chat {
        static let timelineSpacing: CGFloat = 12
        static let timelinePadding: CGFloat = 16
        static let composerPadding: CGFloat = 12
        static let headerSpacing: CGFloat = 12
        static let headerTitleSpacing: CGFloat = 4
        static let headerHorizontalPadding: CGFloat = 16
        static let headerVerticalPadding: CGFloat = 12
        static let emptyStateMinHeight: CGFloat = 280
        static let emptyStateTitle = "Start a Run"
        static let emptyStateDescription = "Send the first goal to create a run and record its events."
        static let emptyStateIcon = "play.circle"
        static let newRunTitle = "New Run"
        static let titleSeparator = " · "
    }

    enum EventRow {
        static let rowSpacing: CGFloat = 10
        static let iconSize: CGFloat = 22
        static let iconFontSize: CGFloat = 14
        static let contentSpacing: CGFloat = 5
        static let metadataSpacing: CGFloat = 8
        static let contentPadding: CGFloat = 10
        static let cornerRadius: CGFloat = 8

        static func icon(for type: RunEventType) -> String {
            switch type {
            case .runCreated: "plus.circle"
            case .userMessage: "person.crop.circle"
            case .assistantMessage: "sparkles"
            case .agentStarted: "play.circle"
            case .agentFinished: "checkmark.circle"
            case .providerRequestStarted: "antenna.radiowaves.left.and.right"
            case .providerStreamDelta: "text.line.first.and.arrowtriangle.forward"
            case .providerRequestFinished: "checkmark.seal"
            case .providerRequestFailed: "exclamationmark.octagon"
            case .toolCall: "terminal"
            case .toolCallRequested: "terminal"
            case .toolCallStarted: "play.rectangle"
            case .toolCallFinished: "checkmark.rectangle"
            case .toolResult: "doc.text.magnifyingglass"
            case .fileChanged: "doc.badge.gearshape"
            case .approvalRequested: "hand.raised"
            case .approvalGranted: "checkmark.shield"
            case .approvalRejected: "xmark.shield"
            case .contextCompacted: "rectangle.compress.vertical"
            case .memorySaved: "brain"
            case .validationStarted: "checklist"
            case .validationFinished: "checkmark.square"
            case .error: "exclamationmark.triangle"
            case .finalSummary: "text.badge.checkmark"
            case .runCompleted: "flag.checkered"
            case .runFailed: "flag.slash"
            }
        }

        static func color(for type: RunEventType) -> Color {
            switch type {
            case .error, .approvalRejected, .providerRequestFailed, .runFailed:
                .red
            case .assistantMessage, .agentFinished, .approvalGranted, .runCompleted, .providerRequestFinished:
                .green
            case .userMessage, .runCreated:
                .blue
            case .providerStreamDelta:
                .purple
            default:
                .secondary
            }
        }
    }

    enum Composer {
        static let spacing: CGFloat = 10
        static let fieldPadding: CGFloat = 10
        static let cornerRadius: CGFloat = 8
        static let minLineLimit = 2
        static let maxLineLimit = 6
        static let buttonIconSize: CGFloat = 20
        static let placeholder = "Describe the run goal..."
        static let sendingIcon = "hourglass"
        static let sendIcon = "paperplane.fill"
        static let sendHelp = "Send"
    }

    enum Runs {
        static let title = "Runs"
        static let headerPadding: CGFloat = 16
        static let rowSpacing: CGFloat = 6
        static let rowVerticalPadding: CGFloat = 4
        static let emptyTitle = "No Runs"
        static let emptyIcon = "play.square.stack"
        static let emptyDescription = "Start from Chat to create the first run."
        static let eventsTokensSeparator = " · "
        static let eventsSuffix = " events"
        static let tokensSuffix = " tokens"
    }

    enum Sidebar {
        static let recentRunSpacing: CGFloat = 3
        static let recentRunsLimit = 6
    }

    enum Placeholder {
        static let description = "This surface is reserved for the next architecture slice."
    }

    enum StatusBadge {
        static let horizontalPadding: CGFloat = 8
        static let verticalPadding: CGFloat = 4
    }
}
