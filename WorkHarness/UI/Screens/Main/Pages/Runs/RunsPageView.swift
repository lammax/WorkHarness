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
            if viewModel.runs.isEmpty {
                EmptyRunsView()
            } else {
                HSplitView {
                    RunsListView(viewModel: viewModel)
                        .frame(
                            minWidth: Design.Layout.listMinWidth,
                            idealWidth: Design.Layout.listIdealWidth
                        )

                    Divider()

                    RunDetailView(viewModel: viewModel, onRunSelected: onRunSelected)
                        .frame(minWidth: Design.Layout.detailMinWidth)
                }
            }
        }
    }

    private struct EmptyRunsView: View {
        typealias Design = RunsPageDesign.EmptyState

        var body: some View {
            ContentUnavailableView(
                Design.title,
                systemImage: Design.icon,
                description: Text(Design.description)
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private struct RunsListView: View {
        typealias Design = RunsPageDesign

        @Bindable var viewModel: RunsPageViewModel

        var body: some View {
            VStack(alignment: .leading, spacing: Design.Layout.spacing) {
                Text(Design.Header.title)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .padding(Design.Header.padding)

                Divider()

                List(selection: selection) {
                    ForEach(viewModel.runRows) { row in
                        RunListRow(row: row)
                            .tag(row.id)
                    }
                }
                .listStyle(.sidebar)
            }
        }

        private var selection: Binding<Run.ID?> {
            Binding {
                viewModel.selectedRun?.id
            } set: { runId in
                viewModel.selectRun(id: runId)
            }
        }
    }

    private struct RunListRow: View {
        typealias Design = RunsPageDesign.Row

        let row: RunRowState

        var body: some View {
            VStack(alignment: .leading, spacing: Design.spacing) {
                HStack {
                    Text(row.title)
                        .font(.headline)
                        .lineLimit(1)
                    Spacer()
                    Text(row.status)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(row.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, Design.horizontalPadding)
            .padding(.vertical, Design.verticalPadding)
        }
    }

    private struct RunDetailView: View {
        typealias Design = RunsPageDesign

        @Bindable var viewModel: RunsPageViewModel
        let onRunSelected: (Run) -> Void

        var body: some View {
            if let detail = viewModel.selectedRunDetail {
                ScrollView {
                    VStack(alignment: .leading, spacing: Design.Detail.spacing) {
                        RunDetailHeader(detail: detail, run: viewModel.selectedRun, onRunSelected: onRunSelected)
                        MetricsView(metrics: detail.metrics)
                        TimelineView(viewModel: viewModel, events: detail.events, hasEvents: detail.hasEvents)
                        ArtifactsView(artifacts: detail.artifacts)
                        EventInspectorView(event: detail.selectedEvent)
                    }
                    .padding(Design.Detail.padding)
                }
            } else {
                EmptyRunsView()
            }
        }
    }

    private struct RunDetailHeader: View {
        typealias Design = RunsPageDesign.Header

        let detail: RunDetailState
        let run: Run?
        let onRunSelected: (Run) -> Void

        var body: some View {
            HStack(spacing: Design.spacing) {
                VStack(alignment: .leading, spacing: Design.titleSpacing) {
                    Text(detail.title)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .lineLimit(2)

                    Text("\(detail.mode)\(Design.metadataSeparator)\(detail.createdAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                StatusBadge(status: detail.status)

                if let run {
                    Button {
                        onRunSelected(run)
                    } label: {
                        Label(Design.openInChatTitle, systemImage: Design.openInChatIcon)
                    }
                }
            }
        }
    }

    private struct MetricsView: View {
        typealias Design = RunsPageDesign

        let metrics: [MetricState]

        var body: some View {
            SectionBlock(title: Design.Detail.metricsTitle) {
                HStack(spacing: Design.Metric.spacing) {
                    ForEach(metrics) { metric in
                        VStack(alignment: .leading, spacing: Design.Detail.sectionTitleSpacing) {
                            Text(metric.title)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(metric.value)
                                .font(.headline)
                        }
                        .frame(minWidth: Design.Metric.minWidth, alignment: .leading)
                    }

                    Spacer()
                }
            }
        }
    }

    private struct TimelineView: View {
        typealias Design = RunsPageDesign

        @Bindable var viewModel: RunsPageViewModel
        let events: [RunEventState]
        let hasEvents: Bool

        var body: some View {
            SectionBlock(title: Design.Detail.timelineTitle) {
                if hasEvents {
                    LazyVStack(alignment: .leading, spacing: Design.Detail.cardSpacing) {
                        ForEach(events) { event in
                            Button {
                                viewModel.selectEvent(id: event.id)
                            } label: {
                                TimelineEventRow(event: event, isSelected: viewModel.isEventSelected(event))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } else {
                    ContentUnavailableView(
                        Design.Detail.emptyTimelineTitle,
                        systemImage: Design.Detail.emptyTimelineIcon,
                        description: Text(Design.Detail.emptyTimelineDescription)
                    )
                }
            }
        }
    }

    private struct TimelineEventRow: View {
        typealias Design = RunsPageDesign.EventRow

        let event: RunEventState
        let isSelected: Bool

        var body: some View {
            HStack(alignment: .top, spacing: Design.spacing) {
                Image(systemName: Design.icon(for: event.type))
                    .font(.system(size: Design.iconFontSize, weight: .medium))
                    .foregroundStyle(Design.color(for: event.type))
                    .frame(width: Design.iconSize, height: Design.iconSize)

                VStack(alignment: .leading, spacing: Design.contentSpacing) {
                    HStack(spacing: Design.metadataSpacing) {
                        Text(event.title)
                            .font(.caption)
                            .fontWeight(.semibold)
                        Text(event.createdAt, style: .time)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Text(event.message)
                        .font(.body)
                        .textSelection(.enabled)
                }
            }
            .padding(Design.padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? .thickMaterial : .regularMaterial, in: RoundedRectangle(cornerRadius: Design.cornerRadius))
        }
    }

    private struct ArtifactsView: View {
        typealias Design = RunsPageDesign

        let artifacts: [ArtifactState]

        var body: some View {
            SectionBlock(title: Design.Detail.artifactsTitle) {
                if artifacts.isEmpty {
                    Text(Design.Detail.artifactsPlaceholder)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: Design.Detail.sectionSpacing) {
                        ForEach(artifacts) { artifact in
                            VStack(alignment: .leading, spacing: Design.Detail.sectionTitleSpacing) {
                                Text(artifact.title)
                                    .font(.headline)
                                Text(artifact.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
    }

    private struct EventInspectorView: View {
        typealias Design = RunsPageDesign

        let event: EventInspectorState?

        var body: some View {
            SectionBlock(title: Design.Detail.inspectorTitle) {
                if let event {
                    VStack(alignment: .leading, spacing: Design.Inspector.spacing) {
                        Text(event.title)
                            .font(.headline)
                        Text(event.createdAt, style: .time)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(event.message)
                            .textSelection(.enabled)

                        Divider()

                        if event.metadata.isEmpty {
                            Text(Design.Inspector.emptyMetadata)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            VStack(alignment: .leading, spacing: Design.Inspector.metadataSpacing) {
                                ForEach(event.metadata) { item in
                                    HStack(alignment: .top) {
                                        Text(item.key)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Spacer()
                                        Text(item.value)
                                            .font(.caption)
                                            .textSelection(.enabled)
                                    }
                                }
                            }
                        }
                    }
                } else {
                    ContentUnavailableView(
                        Design.Inspector.emptyTitle,
                        systemImage: Design.EmptyState.icon,
                        description: Text(Design.Inspector.emptyDescription)
                    )
                }
            }
        }
    }

    private struct SectionBlock<Content: View>: View {
        typealias Design = RunsPageDesign.Detail

        let title: String
        @ViewBuilder let content: Content

        var body: some View {
            VStack(alignment: .leading, spacing: Design.sectionSpacing) {
                Text(title)
                    .font(.system(size: Design.sectionTitleFontSize, weight: .semibold))
                    .foregroundStyle(.secondary)
                content
            }
            .padding(Design.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Design.cornerRadius))
        }
    }

    private struct StatusBadge: View {
        typealias Design = RunsPageDesign.StatusBadge

        let status: String

        var body: some View {
            Text(status)
                .font(.caption)
                .fontWeight(.semibold)
                .padding(.horizontal, Design.horizontalPadding)
                .padding(.vertical, Design.verticalPadding)
                .background(.thinMaterial, in: Capsule())
        }
    }
}
