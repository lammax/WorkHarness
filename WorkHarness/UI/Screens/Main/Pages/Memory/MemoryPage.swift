//
// MemoryPage.swift
// WorkHarness
//
// Created by Auto (Codex) on 10.07.2026.
//

import SwiftUI

extension MainScreen {
    final class MemoryPage: BasePageProtocol {
        let content: AnyView

        init(screenModel: MainScreenViewModel, viewModel: MemoryPageViewModel) {
            self.content = AnyView(MemoryPageView(viewModel: viewModel))
        }
    }
}
