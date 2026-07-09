//
// MainScreen.swift
// WorkHarness
//
// Created by Auto (Codex) on 07.07.2026.
//

@MainActor
final class MainScreen {
    private let viewModel: MainScreenViewModel

    init(
        chatPageViewModel: ChatPageViewModel,
        runsPageViewModel: RunsPageViewModel,
        statsPageViewModel: StatsPageViewModel,
        settingsPageViewModel: SettingsPageViewModel,
        approvalService: ApprovalServiceProtocol,
        projectService: ProjectServiceProtocol
    ) {
        self.viewModel = MainScreenViewModel(
            chatPageViewModel: chatPageViewModel,
            runsPageViewModel: runsPageViewModel,
            statsPageViewModel: statsPageViewModel,
            settingsPageViewModel: settingsPageViewModel,
            approvalService: approvalService,
            projectService: projectService
        )
    }
}

extension MainScreen: MainScreenProtocol {
    var pagesModel: PagesViewModel { viewModel }
}
