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
        }

        private var selection: Binding<NavigationSection> {
            Binding {
                screenModel.selectedSection
            } set: { section in
                screenModel.show(section: section)
            }
        }
    }
}
