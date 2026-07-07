//
// MainShellPageDesign.swift
// WorkHarness
//
// Created by Auto (Codex) on 07.07.2026.
//

import CoreGraphics

extension MainScreen {
    enum MainShellPageDesign {
        enum Window {
            static let minWidth: CGFloat = MainScreenDesign.Window.minWidth
            static let minHeight: CGFloat = MainScreenDesign.Window.minHeight
        }

        enum Sidebar {
            static let minWidth: CGFloat = MainScreenDesign.Window.sidebarMinWidth
            static let idealWidth: CGFloat = MainScreenDesign.Window.sidebarIdealWidth
        }
    }
}
