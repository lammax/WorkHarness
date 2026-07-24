//
// SettingsPageView.swift
// WorkHarness
//
// Created by Auto (Codex) on 08.07.2026.
//

import SwiftUI
import UniformTypeIdentifiers

extension MainScreen {
    private enum SettingsTab: String, CaseIterable {
        case execution
        case profiles
        case application
        case rag

        var title: String {
            switch self {
            case .execution: SettingsPageDesign.Tabs.executionTitle
            case .profiles: SettingsPageDesign.Tabs.profilesTitle
            case .application: SettingsPageDesign.Tabs.applicationTitle
            case .rag: SettingsPageDesign.Tabs.ragTitle
            }
        }

        var icon: String {
            switch self {
            case .execution: SettingsPageDesign.Tabs.executionIcon
            case .profiles: SettingsPageDesign.Tabs.profilesIcon
            case .application: SettingsPageDesign.Tabs.applicationIcon
            case .rag: SettingsPageDesign.Tabs.ragIcon
            }
        }
    }

    struct SettingsPageView: View {
        typealias Design = SettingsPageDesign

        @Bindable var viewModel: SettingsPageViewModel
        @State private var selectedTab: SettingsTab = .execution

        var body: some View {
            VStack(alignment: .leading, spacing: Design.Layout.spacing) {
                header

                Divider()

                Picker(Design.Tabs.title, selection: $selectedTab) {
                    ForEach(SettingsTab.allCases, id: \.self) { tab in
                        Label(tab.title, systemImage: tab.icon).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, Design.Content.padding)

                ScrollView {
                    VStack(alignment: .leading, spacing: Design.Content.sectionSpacing) {
                        tabContent
                    }
                    .padding(Design.Content.padding)
                }
            }
            .fileImporter(
                isPresented: $viewModel.isPromptImporterPresented,
                allowedContentTypes: [UTType(filenameExtension: "md") ?? .plainText],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first {
                        viewModel.importPrompt(from: url)
                    }
                case .failure(let error):
                    viewModel.setPromptImportError(error.localizedDescription)
                }
            }
            .onAppear {
                viewModel.reloadAgentProfiles()
            }
        }

        @ViewBuilder
        private var tabContent: some View {
            switch selectedTab {
            case .execution:
                executionTab
            case .profiles:
                agentProfiles
            case .application:
                appSettings
            case .rag:
                ragSettings
            }
        }

        private var agentProfiles: some View {
            VStack(alignment: .leading, spacing: Design.AgentProfiles.sectionSpacing) {
                HStack {
                    Label(Design.AgentProfiles.title, systemImage: Design.AgentProfiles.icon)
                        .font(.headline)

                    Spacer()

                    Button(Design.AgentProfiles.reloadButtonTitle) {
                        viewModel.reloadAgentProfiles()
                    }
                }

                Text(Design.AgentProfiles.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                LabeledContent(Design.AgentProfiles.directoryTitle) {
                    Text(viewModel.agentProfileDirectoryPath)
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                }

                if viewModel.agentProfiles.isEmpty {
                    ContentUnavailableView(
                        Design.AgentProfiles.emptyTitle,
                        systemImage: Design.AgentProfiles.icon,
                        description: Text(Design.AgentProfiles.emptyDescription)
                    )
                } else {
                    Picker(
                        Design.AgentProfiles.profilePickerTitle,
                        selection: Binding(
                            get: { viewModel.selectedAgentProfileId },
                            set: viewModel.selectAgentProfile(id:)
                        )
                    ) {
                        ForEach(viewModel.agentProfiles) { profile in
                            Text(profile.name).tag(profile.id)
                        }
                    }
                    .pickerStyle(.segmented)

                    if let profile = viewModel.selectedAgentProfile {
                        Text(profile.summary)
                            .font(.callout)
                            .foregroundStyle(.secondary)

                        VStack(spacing: Design.AgentProfiles.assistantSpacing) {
                            ForEach(Array(profile.assistants.enumerated()), id: \.element.id) { index, assistant in
                                assistantProfileRow(
                                    assistant,
                                    index: index,
                                    assistantCount: profile.assistants.count
                                )
                            }
                        }
                    }
                }
            }
            .padding(Design.AgentProfiles.padding)
            .background(
                .thinMaterial,
                in: RoundedRectangle(cornerRadius: Design.AgentProfiles.cornerRadius)
            )
        }

        private func assistantProfileRow(
            _ assistant: AgentProfileAssistant,
            index: Int,
            assistantCount: Int
        ) -> some View {
            HStack(alignment: .top, spacing: Design.AgentProfiles.rowSpacing) {
                Text("\(index + 1)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: Design.AgentProfiles.orderWidth)

                VStack(alignment: .leading, spacing: Design.AgentProfiles.textSpacing) {
                    HStack {
                        Text(assistant.name)
                            .fontWeight(.semibold)
                        Text(assistant.role.label)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Text(assistant.promptFileName)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)

                    Text(viewModel.promptPreview(for: assistant.id))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(Design.AgentProfiles.promptLineLimit)
                }

                Spacer()

                VStack(spacing: Design.AgentProfiles.buttonSpacing) {
                    HStack {
                        Button {
                            viewModel.moveAssistant(id: assistant.id, direction: .up)
                        } label: {
                            Image(systemName: Design.AgentProfiles.moveUpIcon)
                        }
                        .disabled(index == 0)

                        Button {
                            viewModel.moveAssistant(id: assistant.id, direction: .down)
                        } label: {
                            Image(systemName: Design.AgentProfiles.moveDownIcon)
                        }
                        .disabled(index == assistantCount - 1)
                    }

                    HStack {
                        Button(Design.AgentProfiles.openPromptButtonTitle) {
                            viewModel.openPrompt(for: assistant.id)
                        }

                        Button(Design.AgentProfiles.loadPromptButtonTitle) {
                            viewModel.presentPromptImporter(for: assistant.id)
                        }
                    }
                }
            }
            .padding(Design.AgentProfiles.rowPadding)
            .background(
                Color.secondary.opacity(Design.AgentProfiles.rowBackgroundOpacity),
                in: RoundedRectangle(cornerRadius: Design.AgentProfiles.rowCornerRadius)
            )
        }

        private var header: some View {
            VStack(alignment: .leading, spacing: Design.Header.spacing) {
                Text(Design.Header.title)
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("\(Design.Header.activeBackendPrefix)\(viewModel.activeExecutionBackendName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            .padding(Design.Header.padding)
        }

        private var executionTab: some View {
            Group {
                if viewModel.executionBackends.isEmpty {
                    ContentUnavailableView(
                        Design.EmptyState.title,
                        systemImage: Design.EmptyState.icon,
                        description: Text(Design.EmptyState.description)
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    HStack(alignment: .top, spacing: Design.Content.columnSpacing) {
                        executionBackendList
                        Divider()
                        executionBackendDetails
                    }
                }
            }
        }

        private var executionBackendList: some View {
            VStack(alignment: .leading, spacing: Design.BackendList.spacing) {
                HStack {
                    Label(Design.ExecutionBackend.title, systemImage: Design.ExecutionBackend.icon)
                        .font(.headline)

                    Spacer()

                    Text(Design.ExecutionBackend.nextRunLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(Design.BackendList.agentSectionTitle)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)

                ForEach(viewModel.executionBackends.filter { $0.kind == .agentRuntime }) { backend in
                    executionBackendButton(backend)
                }

                Text(Design.BackendList.providerSectionTitle)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .padding(.top, Design.BackendList.sectionSpacing)

                ForEach(viewModel.executionBackends.filter { $0.kind == .provider }) { backend in
                    executionBackendButton(backend)
                }
            }
            .frame(width: Design.BackendList.width, alignment: .topLeading)
        }

        private func executionBackendButton(_ backend: ExecutionBackendItem) -> some View {
            Button {
                viewModel.selectExecutionBackend(id: backend.id)
            } label: {
                ExecutionBackendRow(backend: backend)
            }
            .buttonStyle(.plain)
        }

        @ViewBuilder
        private var executionBackendDetails: some View {
            if let activeRuntime = viewModel.activeAgentRuntime {
                VStack(alignment: .leading, spacing: Design.BackendDetails.spacing) {
                    backendTitle(
                        name: activeRuntime.name,
                        id: activeRuntime.id,
                        type: Design.BackendDetails.agentType,
                        icon: Design.BackendRow.agentIcon
                    )

                    LabeledContent(Design.BackendDetails.transportTitle, value: activeRuntime.transport)
                    LabeledContent(Design.BackendDetails.availabilityTitle, value: activeRuntime.availability)
                    Text(activeRuntime.authentication)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if !activeRuntime.modelOptions.isEmpty {
                        Picker(Design.AgentRuntime.modelPickerTitle, selection: Binding(
                            get: { viewModel.validatedAgentModelId(for: activeRuntime) },
                            set: { viewModel.selectedAgentModelId = $0 }
                        )) {
                            ForEach(activeRuntime.modelOptions) { model in
                                Text(model.title).tag(model.id)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else if let selectedProvider = viewModel.selectedProvider {
                VStack(alignment: .leading, spacing: Design.BackendDetails.spacing) {
                    backendTitle(
                        name: selectedProvider.name,
                        id: selectedProvider.id,
                        type: Design.BackendDetails.providerType,
                        icon: Design.BackendRow.providerIcon
                    )

                    LabeledContent(Design.BackendDetails.transportTitle, value: selectedProvider.transport)
                    LabeledContent(Design.BackendDetails.availabilityTitle, value: selectedProvider.availability)

                    VStack(alignment: .leading, spacing: Design.CapabilityList.spacing) {
                        Text(Design.CapabilityList.title)
                            .font(.headline)

                        ForEach(selectedProvider.capabilities) { capability in
                            CapabilityRow(capability: capability)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }

        private func backendTitle(
            name: String,
            id: String,
            type: String,
            icon: String
        ) -> some View {
            VStack(alignment: .leading, spacing: Design.BackendDetails.titleSpacing) {
                Label(name, systemImage: icon)
                    .font(.title3)
                    .fontWeight(.semibold)
                Text(type)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Text(id)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }

        private var appSettings: some View {
            VStack(alignment: .leading, spacing: Design.AppSettings.spacing) {
                HStack {
                    Text(Design.AppSettings.title)
                        .font(.headline)

                    Spacer()

                    Text(viewModel.appSettingsStatus)
                        .font(.caption)
                        .foregroundStyle(viewModel.hasUnsavedAppSettingsChanges ? .orange : .secondary)

                    Button(Design.AppSettings.revertButtonTitle) {
                        viewModel.revertSettings()
                    }
                    .disabled(!viewModel.hasUnsavedAppSettingsChanges)

                    Button(Design.AppSettings.restoreDefaultsButtonTitle) {
                        viewModel.restoreDefaultSettingsDraft()
                    }

                    Button(Design.AppSettings.saveButtonTitle) {
                        viewModel.saveSettings()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!viewModel.hasUnsavedAppSettingsChanges)
                }

                VStack(alignment: .leading, spacing: Design.AppSettings.rowSpacing) {
                    Picker(Design.AppSettings.safetyModeTitle, selection: $viewModel.selectedSafetyMode) {
                        ForEach(SafetyMode.allCases, id: \.self) { mode in
                            Text(mode.label).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    Toggle(
                        Design.AppSettings.autoApproveWorkspaceActionsTitle,
                        isOn: $viewModel.autoApproveWorkspaceActions
                    )
                    .toggleStyle(.checkbox)

                    Text(Design.AppSettings.autoApproveWorkspaceActionsDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    SettingsTextField(
                        title: Design.AppSettings.mcpBasePathTitle,
                        placeholder: Design.AppSettings.mcpBasePathPlaceholder,
                        text: $viewModel.mcpServerBasePath
                    )

                    SettingsTextField(
                        title: Design.AppSettings.localLLMEndpointTitle,
                        placeholder: Design.AppSettings.localLLMEndpointPlaceholder,
                        text: $viewModel.localLLMEndpoint
                    )

                    SettingsTextField(
                        title: Design.AppSettings.localLLMModelTitle,
                        placeholder: Design.AppSettings.localLLMModelPlaceholder,
                        text: $viewModel.localLLMModel
                    )

                    Divider()

                    Text(Design.AppSettings.remoteControlTitle)
                        .font(.headline)

                    Toggle(Design.AppSettings.remoteControlEnabledTitle, isOn: $viewModel.remoteControlEnabled)
                    Toggle(Design.AppSettings.remoteControlAllowLANTitle, isOn: $viewModel.remoteControlAllowLAN)
                        .disabled(!viewModel.remoteControlEnabled)

                    HStack {
                        Text(Design.AppSettings.remoteControlPortTitle)
                        Spacer()
                        TextField("8787", value: $viewModel.remoteControlPort, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 100)
                    }

                    SecureField(Design.AppSettings.remoteControlTokenPlaceholder, text: $viewModel.remoteControlToken)
                        .textFieldStyle(.roundedBorder)

                    HStack(spacing: Design.AppSettings.fieldSpacing) {
                        TokenBudgetStepper(
                            title: Design.AppSettings.maxInputTokensTitle,
                            value: $viewModel.defaultMaxInputTokens
                        )

                        TokenBudgetStepper(
                            title: Design.AppSettings.maxOutputTokensTitle,
                            value: $viewModel.defaultMaxOutputTokens
                        )
                    }
                }
            }
            .padding(Design.AppSettings.padding)
            .background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: Design.AppSettings.cornerRadius))
        }

        private var ragSettings: some View {
            VStack(alignment: .leading, spacing: Design.RAGSettings.spacing) {
                HStack {
                    Label(Design.RAGSettings.title, systemImage: Design.RAGSettings.icon)
                        .font(.headline)

                    Spacer()

                    Text(Design.RAGSettings.sourceLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Picker(Design.RAGSettings.answerModeTitle, selection: $viewModel.ragAnswerMode) {
                    ForEach(RAGAnswerMode.allCases, id: \.self) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                Picker(Design.RAGSettings.chunkingTitle, selection: $viewModel.ragChunkingStrategy) {
                    ForEach(RAGChunkingStrategy.allCases, id: \.self) { strategy in
                        Text(strategy.title).tag(strategy)
                    }
                }
                .pickerStyle(.segmented)

                Picker(Design.RAGSettings.retrievalTitle, selection: $viewModel.ragRetrievalMode) {
                    ForEach(RAGRetrievalMode.allCases, id: \.self) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                Picker(Design.RAGSettings.filterTitle, selection: $viewModel.ragRelevanceFilterMode) {
                    ForEach(RAGRelevanceFilterMode.allCases, id: \.self) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                HStack(spacing: Design.RAGSettings.fieldSpacing) {
                    Stepper(
                        "\(Design.RAGSettings.topKBeforeTitle): \(viewModel.ragTopKBeforeFiltering)",
                        value: $viewModel.ragTopKBeforeFiltering,
                        in: Design.RAGSettings.topKBeforeRange
                    )

                    Stepper(
                        "\(Design.RAGSettings.topKAfterTitle): \(viewModel.ragTopKAfterFiltering)",
                        value: $viewModel.ragTopKAfterFiltering,
                        in: Design.RAGSettings.topKAfterRange
                    )
                }

                VStack(alignment: .leading, spacing: Design.RAGSettings.controlSpacing) {
                    Text("\(Design.RAGSettings.thresholdTitle): \(viewModel.ragSimilarityThreshold, specifier: "%.2f")")
                    Slider(value: $viewModel.ragSimilarityThreshold, in: Design.RAGSettings.thresholdRange, step: Design.RAGSettings.thresholdStep)
                }
            }
            .padding(Design.RAGSettings.padding)
            .background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: Design.RAGSettings.cornerRadius))
        }

    }

    private struct ExecutionBackendRow: View {
        typealias Design = SettingsPageDesign.BackendRow

        let backend: ExecutionBackendItem

        var body: some View {
            HStack(spacing: Design.spacing) {
                Image(systemName: backend.isActive ? Design.activeIcon : Design.inactiveIcon)
                    .foregroundStyle(backend.isActive ? .green : .secondary)
                    .frame(width: Design.iconSize, height: Design.iconSize)

                VStack(alignment: .leading, spacing: Design.textSpacing) {
                    Text(backend.name)
                        .font(.body)
                        .fontWeight(backend.isActive ? .semibold : .regular)
                    Label(typeLabel, systemImage: typeIcon)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()
            }
            .padding(Design.padding)
            .background {
                if backend.isActive {
                    RoundedRectangle(cornerRadius: Design.cornerRadius)
                        .fill(.regularMaterial)
                } else {
                    RoundedRectangle(cornerRadius: Design.cornerRadius)
                        .fill(Color.clear)
                }
            }
        }

        private var typeLabel: String {
            switch backend.kind {
            case .agentRuntime:
                Design.agentType
            case .provider:
                Design.providerType
            }
        }

        private var typeIcon: String {
            switch backend.kind {
            case .agentRuntime:
                Design.agentIcon
            case .provider:
                Design.providerIcon
            }
        }
    }

    private struct CapabilityRow: View {
        typealias Design = SettingsPageDesign.CapabilityRow

        let capability: ProviderCapabilityRow

        var body: some View {
            HStack(alignment: .firstTextBaseline, spacing: Design.spacing) {
                Text(capability.title)
                    .foregroundStyle(.secondary)
                    .frame(width: Design.titleWidth, alignment: .leading)
                Text(capability.value)
                    .textSelection(.enabled)
                Spacer(minLength: 0)
            }
            .font(.callout)
            .padding(.vertical, Design.verticalPadding)
        }
    }

    private struct SettingsTextField: View {
        let title: String
        let placeholder: String
        @Binding var text: String

        var body: some View {
            LabeledContent(title) {
                TextField(placeholder, text: $text)
                    .textFieldStyle(.roundedBorder)
                    .textSelection(.enabled)
            }
        }
    }

    private struct TokenBudgetStepper: View {
        typealias Design = SettingsPageDesign.AppSettings

        let title: String
        @Binding var value: Int

        var body: some View {
            Stepper(
                "\(title): \(value)",
                value: $value,
                in: Design.tokenRange,
                step: Design.tokenStep
            )
            .monospacedDigit()
        }
    }
}
