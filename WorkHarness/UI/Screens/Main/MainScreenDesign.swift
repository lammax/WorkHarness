//
// MainScreenDesign.swift
// WorkHarness
//
// Created by Auto (Codex) on 07.07.2026.
//

import CoreGraphics

extension MainScreen {
    enum MainScreenDesign {
        enum Window {
            static let minWidth: CGFloat = 960
            static let minHeight: CGFloat = 640
            static let sidebarMinWidth: CGFloat = 220
            static let sidebarIdealWidth: CGFloat = 260
        }

        enum Sidebar {
            static let workspaceSectionTitle = "Workspace"
            static let projectSectionTitle = "Project"
            static let approvalsSectionTitle = "Approvals"
            static let recentRunsSectionTitle = "Recent Runs"
            static let appTitle = "WorkHarness"
            static let recentRunSpacing: CGFloat = 3
            static let recentRunsLimit = 6
            static let minWidth: CGFloat = Window.sidebarMinWidth
            static let idealWidth: CGFloat = Window.sidebarIdealWidth

            enum Project {
                static let icon = "folder"
                static let emptyIcon = "folder.badge.questionmark"
                static let selectedIcon = "checkmark.circle.fill"
                static let addIcon = "plus"
                static let emptyTitle = "No Project"
                static let emptySubtitle = "Add a project to start"
                static let unselectedSubtitle = "Select a project"
                static let noRootPathSubtitle = "No root path"
                static let addButtonTitle = "Add Project"
                static let sheetTitle = "Add Project"
                static let nameLabel = "Name"
                static let namePlaceholder = "WorkHarness"
                static let rootPathLabel = "Root Path"
                static let rootPathPlaceholder = "/Users/me/Projects/App"
                static let cancelButtonTitle = "Cancel"
                static let createButtonTitle = "Create"
                static let nameRequiredMessage = "Project name is required."
                static let spacing: CGFloat = 6
                static let textSpacing: CGFloat = 2
                static let formWidth: CGFloat = 420
                static let formSpacing: CGFloat = 14
                static let formPadding: CGFloat = 20
                static let rowSpacing: CGFloat = 3
            }

            enum Approval {
                static let icon = "hand.raised"
                static let pendingIcon = "exclamationmark.triangle"
                static let sheetTitle = "Approval Required"
                static let modeTitle = "Safety Mode"
                static let pendingBadge = "Pending"
                static let approveButtonTitle = "Approve"
                static let rejectButtonTitle = "Reject"
                static let closeButtonTitle = "Close"
                static let spacing: CGFloat = 8
                static let textSpacing: CGFloat = 3
                static let sheetWidth: CGFloat = 460
                static let sheetSpacing: CGFloat = 14
                static let sheetPadding: CGFloat = 20
            }

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
    }
}
