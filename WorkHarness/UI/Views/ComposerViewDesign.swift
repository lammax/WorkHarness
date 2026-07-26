//
// ComposerViewDesign.swift
// WorkHarness
//
// Created by Auto (Codex) on 07.07.2026.
//

import SwiftUI

extension MainScreen {
    enum ComposerViewDesign {
        static let spacing: CGFloat = 10
        static let fieldPadding: CGFloat = 10
        static let cornerRadius: CGFloat = 8
        static let minLineLimit = 2
        static let maxLineLimit = 6
        static let buttonIconSize: CGFloat = 20
        static let placeholder = "Describe the run goal..."
        static let modeLabel = "Run mode"
        static let simpleModeLabel = "Chat"
        static let multiAgentModeLabel = "Multi-Agent"
        static let taskLoopModeLabel = "Task Loop"
        static let chooseTaskPoolTitle = "Choose Markdown"
        static let taskPoolPlaceholder = "Select a Markdown task pool"
        static let startLoopTitle = "Start Loop"
        static let previewSpacing: CGFloat = 3
        static let newChatIcon = "plus"
        static let newChatHelp = "New chat"
        static let modeControlSpacing: CGFloat = 8
        static let sendIcon = "paperplane.fill"
        static let stopIcon = "stop.fill"
        static let attachIcon = "paperclip"
        static let sendHelp = "Send"
        static let stopHelp = "Stop current run"
        static let stopColor = Color.red
        static let attachHelp = "Attach read-only context file"

        enum Attachment {
            static let spacing: CGFloat = 8
            static let contentSpacing: CGFloat = 6
            static let horizontalPadding: CGFloat = 10
            static let verticalPadding: CGFloat = 6
            static let nameLineLimit = 1
            static let fileIcon = "doc.text"
            static let removeIcon = "xmark"
            static let removeHelp = "Remove attachment"
        }
    }
}
