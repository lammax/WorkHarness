//
// RunsPageDesign.swift
// WorkHarness
//
// Created by Auto (Codex) on 07.07.2026.
//

import CoreGraphics
import SwiftUI

extension MainScreen {
    enum RunsPageDesign {
        enum Layout {
            static let spacing: CGFloat = 0
            static let listMinWidth: CGFloat = 260
            static let listIdealWidth: CGFloat = 320
            static let detailMinWidth: CGFloat = 520
        }

        enum Header {
            static let title = "Runs"
            static let openInChatTitle = "Open in Chat"
            static let openInChatIcon = "bubble.left.and.bubble.right"
            static let resumeTitle = "Resume"
            static let resumeIcon = "play.fill"
            static let restartTitle = "Restart"
            static let restartIcon = "arrow.clockwise"
            static let cancelTitle = "Cancel"
            static let cancelIcon = "xmark"
            static let resumeFailure = "The interrupted Run could not be resumed."
            static let restartFailure = "The interrupted Run could not be restarted."
            static let padding: CGFloat = 16
            static let spacing: CGFloat = 12
            static let titleSpacing: CGFloat = 4
            static let metadataSeparator = " · "
        }

        enum Row {
            static let spacing: CGFloat = 6
            static let verticalPadding: CGFloat = 4
            static let horizontalPadding: CGFloat = 8
            static let eventsTokensSeparator = " · "
            static let eventsSuffix = " events"
            static let tokensSuffix = " tokens"
        }

        enum Detail {
            static let spacing: CGFloat = 16
            static let padding: CGFloat = 16
            static let sectionSpacing: CGFloat = 10
            static let sectionTitleSpacing: CGFloat = 6
            static let sectionTitleFontSize: CGFloat = 13
            static let cardSpacing: CGFloat = 10
            static let cardPadding: CGFloat = 12
            static let cornerRadius: CGFloat = 8
            static let timelineTitle = "Timeline"
            static let emptyTimelineTitle = "No Events"
            static let emptyTimelineDescription = "This run has no recorded events yet."
            static let emptyTimelineIcon = "timeline.selection"
            static let inspectorTitle = "Event Inspector"
            static let metricsTitle = "Stats"
            static let artifactsTitle = "Artifacts"
            static let artifactsPlaceholder = "Artifacts will appear here when runs start producing files, logs, diffs, or reports."
            static let artifactOpenTitle = "Open"
            static let artifactOpenIcon = "arrow.up.forward.app"
            static let artifactOpenIdentifier = "runs.artifact.open"
            static let artifactOpenFailure = "The artifact file is unavailable or could not be opened."
            static let artifactSpacing: CGFloat = 12
        }

        enum Metric {
            static let eventsTitle = "Events"
            static let inputTokensTitle = "Input"
            static let outputTokensTitle = "Output"
            static let totalTokensTitle = "Total"
            static let costTitle = "Cost"
            static let zeroCostValue = "$0"
            static let costPrefix = "$"
            static let spacing: CGFloat = 8
            static let minWidth: CGFloat = 92
        }

        enum EventRow {
            static let spacing: CGFloat = 10
            static let contentSpacing: CGFloat = 5
            static let iconSize: CGFloat = 22
            static let iconFontSize: CGFloat = 14
            static let metadataSpacing: CGFloat = 8
            static let padding: CGFloat = 10
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
                case .toolCallFailed: "exclamationmark.triangle"
                case .toolResult: "doc.text.magnifyingglass"
                case .artifactCreated: "photo.badge.checkmark"
                case .fileChanged: "doc.badge.gearshape"
                case .approvalRequested: "hand.raised"
                case .approvalGranted: "checkmark.shield"
                case .approvalRejected: "xmark.shield"
                case .contextBuilt: "text.viewfinder"
                case .contextCompacted: "rectangle.compress.vertical"
                case .memorySaved: "brain"
                case .validationStarted: "checklist"
                case .validationFinished: "checkmark.square"
                case .error: "exclamationmark.triangle"
                case .finalSummary: "text.badge.checkmark"
                case .runInterrupted: "pause.circle"
                case .runResumed: "play.circle.fill"
                case .runRestarted: "arrow.clockwise.circle"
                case .runCompleted: "flag.checkered"
                case .runCancelled: "stop.circle"
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
                case .runCancelled, .runInterrupted:
                    .orange
                default:
                    .secondary
                }
            }
        }

        enum Inspector {
            static let spacing: CGFloat = 8
            static let metadataSpacing: CGFloat = 6
            static let emptyTitle = "Select an event"
            static let emptyDescription = "Timeline events can be inspected here."
            static let emptyMetadata = "No metadata"
        }

        enum StatusBadge {
            static let horizontalPadding: CGFloat = 8
            static let verticalPadding: CGFloat = 4
        }

        enum EmptyState {
            static let title = "No Runs"
            static let icon = "play.square.stack"
            static let description = "Start from Chat to create the first run."
        }
    }
}
