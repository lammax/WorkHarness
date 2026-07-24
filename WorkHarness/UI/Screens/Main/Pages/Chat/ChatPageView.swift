//
// ChatPageView.swift
// WorkHarness
//
// Created by Auto (Codex) on 07.07.2026.
//

import SwiftUI
import UniformTypeIdentifiers

extension MainScreen {
    struct ChatPageView: View {
        typealias Design = ChatPageDesign

        @Bindable var viewModel: ChatPageViewModel

        var body: some View {
            VStack(spacing: Design.Layout.spacing) {
                ChatHeaderView(
                    run: viewModel.selectedRun,
                    providerName: viewModel.providerName,
                    isRecovering: viewModel.isSending,
                    onResume: viewModel.resumeInterruptedRun,
                    onRestart: viewModel.restartInterruptedRun,
                    onCancel: viewModel.stopRun
                )

                Divider()

                if viewModel.draftRunMode == .multiAgent {
                    MultiAgentPlanPreviewView(
                        configuration: $viewModel.multiAgentConfiguration,
                        modelOptions: viewModel.agentModelOptions,
                        onEnabledChanged: viewModel.setAssistantEnabled,
                        onModelOverrideChanged: viewModel.setAssistantModelOverride
                    )
                }

                ScrollViewReader { proxy in
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

                            Color.clear
                                .frame(height: Design.Timeline.bottomAnchorHeight)
                                .id(Design.Timeline.bottomAnchorID)
                        }
                        .padding(Design.Timeline.padding)
                    }
                    .onAppear {
                        scrollToTimelineBottom(using: proxy)
                    }
                    .onChange(of: viewModel.selectedRunId) {
                        scrollToTimelineBottom(using: proxy)
                    }
                    .onChange(of: viewModel.displayEvents) {
                        scrollToTimelineBottom(using: proxy)
                    }
                }

                Divider()

                ComposerView(
                    text: $viewModel.draftMessage,
                    mode: $viewModel.draftRunMode,
                    contextAttachments: viewModel.draftContextAttachments,
                    isSending: viewModel.isSending,
                    onAttach: viewModel.presentAttachmentImporter,
                    onRemoveAttachment: viewModel.removeAttachment,
                    onNewChat: viewModel.startNewChat,
                    onSend: viewModel.submitDraft,
                    onStop: viewModel.stopRun
                )
                .padding(Design.Composer.padding)

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal, Design.Composer.errorHorizontalPadding)
                        .padding(.bottom, Design.Composer.errorBottomPadding)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .fileImporter(
                isPresented: $viewModel.isAttachmentImporterPresented,
                allowedContentTypes: [.item],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first {
                        viewModel.attachFile(url)
                    }
                case .failure(let error):
                    viewModel.setAttachmentError(error.localizedDescription)
                }
            }
            .onAppear {
                viewModel.reloadAgentProfile()
            }
        }

        private func scrollToTimelineBottom(using proxy: ScrollViewProxy) {
            proxy.scrollTo(Design.Timeline.bottomAnchorID, anchor: .bottom)
        }
    }

    private struct MultiAgentPlanPreviewView: View {
        typealias Design = ChatPageDesign.MultiAgentPlan

        @Binding var configuration: MultiAgentRunConfiguration
        let modelOptions: [AgentRuntimeModelOption]
        let onEnabledChanged: (UUID, Bool) -> Void
        let onModelOverrideChanged: (UUID, String?) -> Void

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
                        Toggle(roleConfiguration.assistantName, isOn: Binding(
                            get: { roleConfiguration.enabled },
                            set: { value in
                                configuration.roles[index].enabled = value
                                onEnabledChanged(roleConfiguration.id, value)
                            }
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
                            set: { value in
                                let modelOverride = value.isEmpty ? nil : value
                                configuration.roles[index].modelOverride = modelOverride
                                onModelOverrideChanged(roleConfiguration.id, modelOverride)
                            }
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
        let isRecovering: Bool
        let onResume: () -> Void
        let onRestart: () -> Void
        let onCancel: () -> Void

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
                    if run.status == .interrupted {
                        Button(action: onResume) {
                            Label(Design.resumeTitle, systemImage: Design.resumeIcon)
                        }
                        .disabled(isRecovering)

                        Button(action: onRestart) {
                            Label(Design.restartTitle, systemImage: Design.restartIcon)
                        }
                        .disabled(isRecovering)

                        Button(role: .destructive, action: onCancel) {
                            Label(Design.cancelTitle, systemImage: Design.cancelIcon)
                        }
                        .disabled(isRecovering)
                    }
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
