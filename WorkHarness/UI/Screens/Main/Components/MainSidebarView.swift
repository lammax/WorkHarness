//
// MainSidebarView.swift
// WorkHarness
//
// Created by Auto (Codex) on 07.07.2026.
//

import SwiftUI

extension MainScreen {
    struct MainSidebarView: View {
        typealias Design = MainScreenDesign.Sidebar

        @Bindable var screenModel: MainScreenViewModel

        var body: some View {
            List(selection: selection) {
                Section(Design.projectSectionTitle) {
                    ProjectBlockView(state: screenModel.projectDisplayState)
                    ProjectListView(
                        projects: screenModel.projects,
                        selectedProjectId: screenModel.selectedProjectId,
                        onSelect: screenModel.selectProject(_:)
                    )
                    Button {
                        screenModel.showProjectForm()
                    } label: {
                        Label(Design.Project.addButtonTitle, systemImage: Design.Project.addIcon)
                    }
                }

                Section(Design.workspaceSectionTitle) {
                    ForEach(NavigationSection.allCases) { section in
                        Label(Design.title(for: section), systemImage: Design.icon(for: section))
                            .tag(section)
                    }
                }

                if !screenModel.chatPageViewModel.runs.isEmpty {
                    Section(Design.recentRunsSectionTitle) {
                        ForEach(screenModel.chatPageViewModel.runs.prefix(Design.recentRunsLimit)) { run in
                            Button {
                                screenModel.selectRun(run)
                            } label: {
                                VStack(alignment: .leading, spacing: Design.recentRunSpacing) {
                                    Text(run.goal)
                                        .lineLimit(1)
                                    Text(run.status.label)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationTitle(Design.appTitle)
            .sheet(isPresented: projectFormPresentation) {
                ProjectFormView(screenModel: screenModel)
            }
        }

        private var selection: Binding<NavigationSection> {
            Binding {
                screenModel.selectedSection
            } set: { section in
                screenModel.show(section: section)
            }
        }

        private var projectFormPresentation: Binding<Bool> {
            Binding {
                screenModel.isProjectFormPresented
            } set: { isPresented in
                if isPresented {
                    screenModel.showProjectForm()
                } else {
                    screenModel.dismissProjectForm()
                }
            }
        }
    }

    private struct ProjectBlockView: View {
        typealias Design = MainScreenDesign.Sidebar.Project

        let state: ProjectDisplayState

        var body: some View {
            HStack(alignment: .top, spacing: Design.spacing) {
                Image(systemName: state.isEmpty ? Design.emptyIcon : Design.icon)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: Design.textSpacing) {
                    Text(state.title)
                        .lineLimit(1)
                    Text(state.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
    }

    private struct ProjectListView: View {
        typealias Design = MainScreenDesign.Sidebar.Project

        let projects: [Project]
        let selectedProjectId: Project.ID?
        let onSelect: (Project) -> Void

        var body: some View {
            ForEach(projects) { project in
                Button {
                    onSelect(project)
                } label: {
                    HStack(alignment: .top, spacing: Design.spacing) {
                        ProjectSelectionIcon(isSelected: selectedProjectId == project.id)

                        VStack(alignment: .leading, spacing: Design.rowSpacing) {
                            Text(project.name)
                                .lineLimit(1)
                            Text(project.rootPath ?? Design.noRootPathSubtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private struct ProjectSelectionIcon: View {
        typealias Design = MainScreenDesign.Sidebar.Project

        let isSelected: Bool

        var body: some View {
            if isSelected {
                Image(systemName: Design.selectedIcon)
                    .foregroundStyle(.tint)
            } else {
                Image(systemName: Design.icon)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private struct ProjectFormView: View {
        typealias Design = MainScreenDesign.Sidebar.Project

        @Bindable var screenModel: MainScreenViewModel

        var body: some View {
            VStack(alignment: .leading, spacing: Design.formSpacing) {
                Text(Design.sheetTitle)
                    .font(.headline)

                TextField(Design.namePlaceholder, text: $screenModel.projectDraftName)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel(Design.nameLabel)

                TextField(Design.rootPathPlaceholder, text: $screenModel.projectDraftRootPath)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel(Design.rootPathLabel)

                if let error = screenModel.projectFormError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                HStack {
                    Spacer()
                    Button(Design.cancelButtonTitle) {
                        screenModel.dismissProjectForm()
                    }
                    Button(Design.createButtonTitle) {
                        screenModel.addProjectFromDraft()
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(Design.formPadding)
            .frame(width: Design.formWidth)
        }
    }
}
