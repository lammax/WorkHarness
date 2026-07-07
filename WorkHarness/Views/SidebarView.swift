//
// SidebarView.swift
// WorkHarness
//
// Created by Auto (Codex) on 07.07.2026.
//

import SwiftUI

struct SidebarView: View {
    @Binding var selection: NavigationSection
    let runs: [Run]
    let onRunSelected: (Run) -> Void

    var body: some View {
        List(selection: $selection) {
            Section(AppDesign.Navigation.workspaceSectionTitle) {
                ForEach(NavigationSection.allCases) { section in
                    Label(AppDesign.Navigation.title(for: section), systemImage: AppDesign.Navigation.icon(for: section))
                        .tag(section)
                }
            }

            if !runs.isEmpty {
                Section(AppDesign.Navigation.recentRunsSectionTitle) {
                    ForEach(runs.prefix(AppDesign.Sidebar.recentRunsLimit)) { run in
                        Button {
                            selection = .chat
                            onRunSelected(run)
                        } label: {
                            VStack(alignment: .leading, spacing: AppDesign.Sidebar.recentRunSpacing) {
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
        .navigationTitle(AppDesign.Navigation.appTitle)
    }
}
