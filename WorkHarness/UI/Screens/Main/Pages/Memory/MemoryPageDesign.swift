//
// MemoryPageDesign.swift
// WorkHarness
//
// Created by Auto (Codex) on 10.07.2026.
//

import CoreGraphics

extension MainScreen {
    enum MemoryPageDesign {
        enum Layout {
            static let spacing: CGFloat = 16
            static let padding: CGFloat = 18
            static let cornerRadius: CGFloat = 8
        }

        enum Header {
            static let title = "Memory"
            static let projectPrefix = "Project: "
            static let noProject = "No project selected"
            static let subtitle = "Stable project facts and decisions"
        }

        enum Composer {
            static let placeholder = "Add a durable project fact or decision"
            static let save = "Save Memory"
            static let spacing: CGFloat = 10
            static let editorHeight: CGFloat = 90
        }

        enum Row {
            static let delete = "trash"
            static let spacing: CGFloat = 8
            static let padding: CGFloat = 12
        }

        enum EmptyState {
            static let title = "No Project Memory"
            static let icon = "brain"
            static let description = "Save stable facts and decisions for the selected project."
        }

        enum Error {
            static let noProject = "Select a project before saving memory."
        }
    }
}
