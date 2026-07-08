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
        private let projectService: ProjectServiceProtocol

        private(set) var selectedSection: NavigationSection = .chat
        private(set) var detailPage: (any BasePageProtocol)?

        init(
            chatPageViewModel: ChatPageViewModel,
            runsPageViewModel: RunsPageViewModel,
            settingsPageViewModel: SettingsPageViewModel,
            projectService: ProjectServiceProtocol
        ) {
            self.chatPageViewModel = chatPageViewModel
            self.runsPageViewModel = runsPageViewModel
            self.settingsPageViewModel = settingsPageViewModel
            self.projectService = projectService
            super.init()
            show(section: .chat)
            pushHard(page: MainShellPage(screenModel: self))
        }

        var projectDisplayState: ProjectDisplayState {
            guard let project = projectService.currentProject else {
                return .empty(projectCount: projectService.projects.count)
            }

            return .current(project)
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

    struct ProjectDisplayState: Equatable {
        var title: String
        var subtitle: String
        var isEmpty: Bool

        static func current(_ project: Project) -> ProjectDisplayState {
            ProjectDisplayState(
                title: project.name,
                subtitle: project.rootPath ?? MainScreenDesign.Sidebar.Project.noRootPathSubtitle,
                isEmpty: false
            )
        }

        static func empty(projectCount: Int) -> ProjectDisplayState {
            ProjectDisplayState(
                title: MainScreenDesign.Sidebar.Project.emptyTitle,
                subtitle: projectCount == 0 ? MainScreenDesign.Sidebar.Project.emptySubtitle : MainScreenDesign.Sidebar.Project.unselectedSubtitle,
                isEmpty: true
            )
        }
    }
}
