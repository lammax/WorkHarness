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

        private(set) var selectedSection: NavigationSection = .chat
        private(set) var detailPage: (any BasePageProtocol)?

        init(chatPageViewModel: ChatPageViewModel, runsPageViewModel: RunsPageViewModel) {
            self.chatPageViewModel = chatPageViewModel
            self.runsPageViewModel = runsPageViewModel
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
            case .agents, .tools, .memory, .stats, .settings:
                detailPage = PlaceholderPage(screenModel: self, viewModel: PlaceholderPageViewModel(section: section))
            }
        }

        func selectRun(_ run: Run) {
            chatPageViewModel.selectRun(run)
            show(section: .chat)
        }
    }
}
