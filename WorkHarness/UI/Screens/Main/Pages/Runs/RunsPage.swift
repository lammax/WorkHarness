//
// RunsPage.swift
// WorkHarness
//
// Created by Auto (Codex) on 07.07.2026.
//

import SwiftUI

extension MainScreen {
    final class RunsPage: BasePageProtocol {
        let content: AnyView

        init(screenModel: MainScreenViewModel, viewModel: RunsPageViewModel) {
            self.content = AnyView(RunsPageView(viewModel: viewModel, onRunSelected: { [weak screenModel] run in
                screenModel?.selectRun(run)
            }))
        }
    }
}
