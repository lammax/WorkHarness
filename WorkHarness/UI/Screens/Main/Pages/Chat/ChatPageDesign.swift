//
// ChatPageDesign.swift
// WorkHarness
//
// Created by Auto (Codex) on 07.07.2026.
//

import CoreGraphics
import SwiftUI

extension MainScreen {
    enum ChatPageDesign {
        enum Layout {
            static let spacing: CGFloat = 0
        }

        enum Timeline {
            static let spacing: CGFloat = 12
            static let padding: CGFloat = 16
            static let bottomAnchorID = "chat-timeline-bottom"
            static let bottomAnchorHeight: CGFloat = 1
        }

        enum Composer {
            static let padding: CGFloat = 12
            static let errorHorizontalPadding: CGFloat = 12
            static let errorBottomPadding: CGFloat = 8
        }

        enum Command {
            static let smokeUnavailable = "Smoke commands are unavailable for the selected project."
        }

        enum Header {
            static let spacing: CGFloat = 12
            static let titleSpacing: CGFloat = 4
            static let horizontalPadding: CGFloat = 16
            static let verticalPadding: CGFloat = 12
            static let newRunTitle = "New Run"
            static let titleSeparator = " · "
            static let resumeTitle = "Resume"
            static let resumeIcon = "play.fill"
            static let restartTitle = "Restart"
            static let restartIcon = "arrow.clockwise"
            static let cancelTitle = "Cancel"
            static let cancelIcon = "xmark"
            static let resumeFailure = "The interrupted Run could not be resumed."
            static let restartFailure = "The interrupted Run could not be restarted."
        }

        enum EmptyState {
            static let minHeight: CGFloat = 280
            static let title = "Start a Run"
            static let description = "Send the first goal to create a run and record its events."
            static let icon = "play.circle"
        }

        enum EventRow {
            static let assistantLabel = "Assistant"
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

        enum StatusBadge {
            static let horizontalPadding: CGFloat = 8
            static let verticalPadding: CGFloat = 4
        }

        enum MultiAgentPlan {
            static let spacing: CGFloat = 8
            static let horizontalPadding: CGFloat = 16
            static let verticalPadding: CGFloat = 8
            static let title = "Execution plan"
            static let icon = "point.3.connected.trianglepath.dotted"
            static let arrowIcon = "chevron.right"
            static let runtimeDefaultModelTitle = "Runtime default"
            static let modelPickerWidth: CGFloat = 150
        }
    }
}
