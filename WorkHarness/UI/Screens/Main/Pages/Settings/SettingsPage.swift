//
// SettingsPage.swift
// WorkHarness
//
// Created by Auto (Codex) on 08.07.2026.
//

import SwiftUI

extension MainScreen {
    final class SettingsPage: BasePageProtocol {
        let content: AnyView

        init(screenModel: MainScreenViewModel, viewModel: SettingsPageViewModel) {
            self.content = AnyView(SettingsPageView(viewModel: viewModel))
        }
    }
}
