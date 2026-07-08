//
// MainScreenViewModel.swift
// WorkHarness
//
// Created by Auto (Codex) on 07.07.2026.
//

import Foundation
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
        var isProjectFormPresented = false
        var projectDraftName = ""
        var projectDraftRootPath = ""
        private(set) var projectFormError: String?

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

        var projects: [Project] {
            projectService.projects
        }

        var selectedProjectId: Project.ID? {
            projectService.currentProject?.id
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

        func showProjectForm() {
            projectDraftName = ""
            projectDraftRootPath = ""
            projectFormError = nil
            isProjectFormPresented = true
        }

        func dismissProjectForm() {
            isProjectFormPresented = false
            projectFormError = nil
        }

        func addProjectFromDraft() {
            let trimmedName = projectDraftName.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedRootPath = projectDraftRootPath.trimmingCharacters(in: .whitespacesAndNewlines)

            guard !trimmedName.isEmpty else {
                projectFormError = MainScreenDesign.Sidebar.Project.nameRequiredMessage
                return
            }

            let rootPath = trimmedRootPath.isEmpty ? nil : trimmedRootPath
            projectService.addProject(name: trimmedName, rootPath: rootPath)
            dismissProjectForm()
        }

        func selectProject(_ project: Project) {
            do {
                try projectService.selectProject(id: project.id)
                projectFormError = nil
            } catch {
                projectFormError = error.localizedDescription
            }
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
