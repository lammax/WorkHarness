//
// NavigationSection.swift
// WorkHarness
//
// Created by Auto (Codex) on 07.07.2026.
//

import Foundation

enum NavigationSection: String, CaseIterable, Identifiable {
    case chat
    case runs
    case agents
    case tools
    case memory
    case stats
    case settings

    var id: String { rawValue }
}
