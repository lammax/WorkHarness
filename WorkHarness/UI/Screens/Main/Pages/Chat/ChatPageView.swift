//
// ChatPageView.swift
// WorkHarness
//
// Created by Auto (Codex) on 07.07.2026.
//

import SwiftUI

extension MainScreen {
    struct ChatPageView: View {
        typealias Design = ChatPageDesign

        @Bindable var viewModel: ChatPageViewModel

        var body: some View {
            VStack(spacing: Design.Layout.spacing) {
                ChatHeaderView(run: viewModel.selectedRun, providerName: viewModel.providerName)

                Divider()

                if viewModel.draftRunMode == .multiAgent {
                    MultiAgentPlanPreviewView(
                        configuration: $viewModel.multiAgentConfiguration,
                        modelOptions: viewModel.agentModelOptions
                    )
                }

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: Design.Timeline.spacing) {
                        if viewModel.displayEvents.isEmpty {
                            EmptyChatStateView()
                        } else {
                            ForEach(viewModel.displayEvents) { event in
                                RunEventRow(event: event)
                                    .id(event.id)
                            }
                        }
                    }
                    .padding(Design.Timeline.padding)
                }

                Divider()

                ComposerView(
                    text: $viewModel.draftMessage,
                    mode: $viewModel.draftRunMode,
                    isSending: viewModel.isSending,
                    onSend: viewModel.submitDraft
                )
                .padding(Design.Composer.padding)
            }
        }
    }

    private struct MultiAgentPlanPreviewView: View {
        typealias Design = ChatPageDesign.MultiAgentPlan

        @Binding var configuration: MultiAgentRunConfiguration
        let modelOptions: [AgentRuntimeModelOption]

        var body: some View {
            HStack(spacing: Design.spacing) {
                Image(systemName: Design.icon)
                    .foregroundStyle(.tint)

                Text(Design.title)
                    .font(.caption)
                    .fontWeight(.semibold)

                ForEach(Array(configuration.roles.enumerated()), id: \.element.id) { index, roleConfiguration in
                    if index > 0 {
                        Image(systemName: Design.arrowIcon)
                            .foregroundStyle(.secondary)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Toggle(roleConfiguration.role.label, isOn: Binding(
                            get: { roleConfiguration.enabled },
                            set: { value in configuration.roles[index].enabled = value }
                        ))
                        .toggleStyle(.checkbox)
                        .font(.caption)
                        Picker(roleConfiguration.role.label, selection: Binding(
                            get: {
                                guard let modelOverride = roleConfiguration.modelOverride,
                                      modelOptions.contains(where: { $0.id == modelOverride }) else {
                                    return ""
                                }
                                return modelOverride
                            },
                            set: { value in configuration.roles[index].modelOverride = value.isEmpty ? nil : value }
                        )) {
                            Text(Design.runtimeDefaultModelTitle).tag("")
                            ForEach(modelOptions) { model in
                                Text(model.title).tag(model.id)
                            }
                        }
                        .labelsHidden()
                        .frame(width: Design.modelPickerWidth)
                    }
                }

                Spacer()
            }
            .padding(.horizontal, Design.horizontalPadding)
            .padding(.vertical, Design.verticalPadding)
            .background(.thinMaterial)
        }
    }

    private struct ChatHeaderView: View {
        typealias Design = ChatPageDesign.Header

        let run: Run?
        let providerName: String

        var body: some View {
            HStack(spacing: Design.spacing) {
                VStack(alignment: .leading, spacing: Design.titleSpacing) {
                    Text(run?.goal ?? Design.newRunTitle)
                        .font(.headline)
                        .lineLimit(1)
                    Text("\(run?.mode.label ?? RunMode.simpleChat.label)\(Design.titleSeparator)\(providerName)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if let run {
                    StatusBadge(status: run.status)
                }
            }
            .padding(.horizontal, Design.horizontalPadding)
            .padding(.vertical, Design.verticalPadding)
        }
    }

    private struct EmptyChatStateView: View {
        typealias Design = ChatPageDesign.EmptyState

        var body: some View {
            ContentUnavailableView {
                Label(Design.title, systemImage: Design.icon)
            } description: {
                Text(Design.description)
            }
            .frame(maxWidth: .infinity, minHeight: Design.minHeight)
        }
    }

    private struct RunEventRow: View {
        typealias Design = ChatPageDesign.EventRow

        let event: RunEvent

        var body: some View {
            HStack(alignment: .top, spacing: Design.rowSpacing) {
                Image(systemName: Design.icon(for: event.type))
                    .font(.system(size: Design.iconFontSize, weight: .medium))
                    .foregroundStyle(Design.color(for: event.type))
                    .frame(width: Design.iconSize, height: Design.iconSize)

                VStack(alignment: .leading, spacing: Design.contentSpacing) {
                    HStack(spacing: Design.metadataSpacing) {
                            Text(event.type == .providerStreamDelta && event.metadata["source"] == "acp" ? Design.assistantLabel : event.type.label)
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
                .padding(Design.contentPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Design.cornerRadius))
            }
        }
    }

    private struct StatusBadge: View {
        typealias Design = ChatPageDesign.StatusBadge

        let status: RunStatus

        var body: some View {
            Text(status.label)
                .font(.caption)
                .fontWeight(.semibold)
                .padding(.horizontal, Design.horizontalPadding)
                .padding(.vertical, Design.verticalPadding)
                .background(.thinMaterial, in: Capsule())
        }
    }
}
