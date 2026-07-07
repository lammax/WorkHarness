//
// PlaceholderPageViewModel.swift
// WorkHarness
//
// Created by Auto (Codex) on 07.07.2026.
//

import Observation

extension MainScreen {
    @MainActor
    @Observable
    final class PlaceholderPageViewModel {
        let section: NavigationSection

        init(section: NavigationSection) {
            self.section = section
        }

        var title: String {
            MainScreenDesign.Sidebar.title(for: section)
        }

        var icon: String {
            MainScreenDesign.Sidebar.icon(for: section)
        }
    }
}
