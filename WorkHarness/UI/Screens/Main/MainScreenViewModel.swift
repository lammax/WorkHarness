//
// MainScreenViewModel.swift
// WorkHarness
//
// Created by Auto (Codex) on 07.07.2026.
//

import Observation

extension MainScreen {
    @MainActor
    @Observable
    final class MainScreenViewModel: PagesViewModel {
        let chatPageViewModel: ChatPageViewModel
        let runsPageViewModel: RunsPageViewModel
        let settingsPageViewModel: SettingsPageViewModel

        private(set) var selectedSection: NavigationSection = .chat
        private(set) var detailPage: (any BasePageProtocol)?

        init(chatPageViewModel: ChatPageViewModel, runsPageViewModel: RunsPageViewModel, settingsPageViewModel: SettingsPageViewModel) {
            self.chatPageViewModel = chatPageViewModel
            self.runsPageViewModel = runsPageViewModel
            self.settingsPageViewModel = settingsPageViewModel
            super.init()
            show(section: .chat)
            pushHard(page: MainShellPage(screenModel: self))
        }

        func show(section: NavigationSection) {
            selectedSection = section

            switch section {
            case .chat:
                detailPage = ChatPage(screenModel: self)
            case .runs:
                detailPage = RunsPage(screenModel: self, viewModel: runsPageViewModel)
            case .settings:
                detailPage = SettingsPage(screenModel: self, viewModel: settingsPageViewModel)
            case .agents, .tools, .memory, .stats:
                detailPage = PlaceholderPage(screenModel: self, viewModel: PlaceholderPageViewModel(section: section))
            }
        }

        func selectRun(_ run: Run) {
            chatPageViewModel.selectRun(run)
            show(section: .chat)
        }
    }
}
