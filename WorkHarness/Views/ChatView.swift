//
// ChatView.swift
// WorkHarness
//
// Created by Auto (Codex) on 07.07.2026.
//

import SwiftUI

struct ChatView: View {
    @Bindable var viewModel: ChatViewModel

    var body: some View {
        VStack(spacing: 0) {
            ChatHeaderView(run: viewModel.selectedRun, providerName: viewModel.providerName)

            Divider()

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: AppDesign.Chat.timelineSpacing) {
                        if viewModel.selectedRunEvents.isEmpty {
                            EmptyChatStateView()
                        } else {
                            ForEach(viewModel.selectedRunEvents) { event in
                                RunEventRow(event: event)
                                    .id(event.id)
                            }
                        }
                    }
                    .padding(AppDesign.Chat.timelinePadding)
                }
                .onChange(of: viewModel.selectedRunEvents.count) {
                    guard let last = viewModel.selectedRunEvents.last else { return }
                    withAnimation {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }

            Divider()

            ComposerView(
                text: $viewModel.draftMessage,
                isSending: viewModel.isSending,
                onSend: viewModel.submitDraft
            )
            .padding(AppDesign.Chat.composerPadding)
        }
    }
}

private struct ChatHeaderView: View {
    let run: Run?
    let providerName: String

    var body: some View {
        HStack(spacing: AppDesign.Chat.headerSpacing) {
            VStack(alignment: .leading, spacing: AppDesign.Chat.headerTitleSpacing) {
                Text(run?.goal ?? AppDesign.Chat.newRunTitle)
                    .font(.headline)
                    .lineLimit(1)
                Text("\(run?.mode.label ?? RunMode.simpleChat.label)\(AppDesign.Chat.titleSeparator)\(providerName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let run {
                StatusBadge(status: run.status)
            }
        }
        .padding(.horizontal, AppDesign.Chat.headerHorizontalPadding)
        .padding(.vertical, AppDesign.Chat.headerVerticalPadding)
    }
}

private struct EmptyChatStateView: View {
    var body: some View {
        ContentUnavailableView {
            Label(AppDesign.Chat.emptyStateTitle, systemImage: AppDesign.Chat.emptyStateIcon)
        } description: {
            Text(AppDesign.Chat.emptyStateDescription)
        }
        .frame(maxWidth: .infinity, minHeight: AppDesign.Chat.emptyStateMinHeight)
    }
}

private struct RunEventRow: View {
    let event: RunEvent

    var body: some View {
        HStack(alignment: .top, spacing: AppDesign.EventRow.rowSpacing) {
            Image(systemName: AppDesign.EventRow.icon(for: event.type))
                .font(.system(size: AppDesign.EventRow.iconFontSize, weight: .medium))
                .foregroundStyle(AppDesign.EventRow.color(for: event.type))
                .frame(width: AppDesign.EventRow.iconSize, height: AppDesign.EventRow.iconSize)

            VStack(alignment: .leading, spacing: AppDesign.EventRow.contentSpacing) {
                HStack(spacing: AppDesign.EventRow.metadataSpacing) {
                    Text(event.type.label)
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
            .padding(AppDesign.EventRow.contentPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: AppDesign.EventRow.cornerRadius))
        }
    }
}

private struct StatusBadge: View {
    let status: RunStatus

    var body: some View {
        Text(status.label)
            .font(.caption)
            .fontWeight(.semibold)
            .padding(.horizontal, AppDesign.StatusBadge.horizontalPadding)
            .padding(.vertical, AppDesign.StatusBadge.verticalPadding)
            .background(.thinMaterial, in: Capsule())
    }
}
