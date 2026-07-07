//
// PlaceholderPage.swift
// WorkHarness
//
// Created by Auto (Codex) on 07.07.2026.
//

import SwiftUI

extension MainScreen {
    final class PlaceholderPage: BasePageProtocol {
        let content: AnyView

        init(screenModel: MainScreenViewModel, viewModel: PlaceholderPageViewModel) {
            self.content = AnyView(PlaceholderPageView(viewModel: viewModel))
        }
    }
}
