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
            static let recentRunsSectionTitle = "Recent Runs"
            static let appTitle = "WorkHarness"
            static let recentRunSpacing: CGFloat = 3
            static let recentRunsLimit = 6
            static let minWidth: CGFloat = Window.sidebarMinWidth
            static let idealWidth: CGFloat = Window.sidebarIdealWidth

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
