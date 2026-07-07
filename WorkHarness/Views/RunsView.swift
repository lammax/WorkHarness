//
// RunsView.swift
// WorkHarness
//
// Created by Auto (Codex) on 07.07.2026.
//

import SwiftUI

struct RunsView: View {
    let runs: [Run]
    let onRunSelected: (Run) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(AppDesign.Runs.title)
                .font(.title2)
                .fontWeight(.semibold)
                .padding(AppDesign.Runs.headerPadding)

            Divider()

            if runs.isEmpty {
                ContentUnavailableView(
                    AppDesign.Runs.emptyTitle,
                    systemImage: AppDesign.Runs.emptyIcon,
                    description: Text(AppDesign.Runs.emptyDescription)
                )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(runs) { run in
                    Button {
                        onRunSelected(run)
                    } label: {
                        VStack(alignment: .leading, spacing: AppDesign.Runs.rowSpacing) {
                            HStack {
                                Text(run.goal)
                                    .font(.headline)
                                    .lineLimit(1)
                                Spacer()
                                Text(run.status.label)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Text(runSummary(for: run))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, AppDesign.Runs.rowVerticalPadding)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func runSummary(for run: Run) -> String {
        let totalTokens = run.tokenUsage.inputTokens + run.tokenUsage.outputTokens
        return "\(run.events.count)\(AppDesign.Runs.eventsSuffix)\(AppDesign.Runs.eventsTokensSeparator)\(totalTokens)\(AppDesign.Runs.tokensSuffix)"
    }
}
