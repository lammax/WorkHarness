//
// MainScreen.swift
// WorkHarness
//
// Created by Auto (Codex) on 07.07.2026.
//

@MainActor
final class MainScreen {
    private let viewModel: MainScreenViewModel

    init(chatPageViewModel: ChatPageViewModel, runsPageViewModel: RunsPageViewModel) {
        self.viewModel = MainScreenViewModel(
            chatPageViewModel: chatPageViewModel,
            runsPageViewModel: runsPageViewModel
        )
    }
}

extension MainScreen: MainScreenProtocol {
    var pagesModel: PagesViewModel { viewModel }
}
