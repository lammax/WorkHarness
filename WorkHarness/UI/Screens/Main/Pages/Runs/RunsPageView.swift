//
// RunsPageView.swift
// WorkHarness
//
// Created by Auto (Codex) on 07.07.2026.
//

import SwiftUI

extension MainScreen {
    struct RunsPageView: View {
        typealias Design = RunsPageDesign

        @Bindable var viewModel: RunsPageViewModel
        let onRunSelected: (Run) -> Void

        var body: some View {
            VStack(alignment: .leading, spacing: Design.Layout.spacing) {
                Text(Design.Header.title)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .padding(Design.Header.padding)

                Divider()

                if viewModel.runs.isEmpty {
                    ContentUnavailableView(
                        Design.EmptyState.title,
                        systemImage: Design.EmptyState.icon,
                        description: Text(Design.EmptyState.description)
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(viewModel.runs) { run in
                        Button {
                            onRunSelected(run)
                        } label: {
                            VStack(alignment: .leading, spacing: Design.Row.spacing) {
                                HStack {
                                    Text(run.goal)
                                        .font(.headline)
                                        .lineLimit(1)
                                    Spacer()
                                    Text(run.status.label)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Text(viewModel.summary(for: run))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, Design.Row.verticalPadding)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}
