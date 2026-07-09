//
// StatsPage.swift
// WorkHarness
//
// Created by Auto (Codex) on 09.07.2026.
//

import SwiftUI

extension MainScreen {
    final class StatsPage: BasePageProtocol {
        let content: AnyView

        init(screenModel: MainScreenViewModel, viewModel: StatsPageViewModel) {
            self.content = AnyView(StatsPageView(viewModel: viewModel))
        }
    }
}
