//
// MainScreen.swift
// WorkHarness
//
// Created by Auto (Codex) on 07.07.2026.
//

@MainActor
final class MainScreen {
    private let viewModel: MainScreenViewModel

    init(chatPageViewModel: ChatPageViewModel, runsPageViewModel: RunsPageViewModel, settingsPageViewModel: SettingsPageViewModel) {
        self.viewModel = MainScreenViewModel(
            chatPageViewModel: chatPageViewModel,
            runsPageViewModel: runsPageViewModel,
            settingsPageViewModel: settingsPageViewModel
        )
    }
}

extension MainScreen: MainScreenProtocol {
    var pagesModel: PagesViewModel { viewModel }
}
