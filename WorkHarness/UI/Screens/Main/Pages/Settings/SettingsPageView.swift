//
// SettingsPageView.swift
// WorkHarness
//
// Created by Auto (Codex) on 08.07.2026.
//

import SwiftUI

extension MainScreen {
    struct SettingsPageView: View {
        typealias Design = SettingsPageDesign

        @Bindable var viewModel: SettingsPageViewModel

        var body: some View {
            VStack(alignment: .leading, spacing: Design.Layout.spacing) {
                header

                Divider()

                if viewModel.providers.isEmpty {
                    ContentUnavailableView(
                        Design.EmptyState.title,
                        systemImage: Design.EmptyState.icon,
                        description: Text(Design.EmptyState.description)
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: Design.Content.sectionSpacing) {
                            executionBackend
                            appSettings

                            HStack(alignment: .top, spacing: Design.Content.columnSpacing) {
                                providerList
                                Divider()
                                providerDetails
                            }
                        }
                        .padding(Design.Content.padding)
                    }
                }
            }
        }

        private var header: some View {
            VStack(alignment: .leading, spacing: Design.Header.spacing) {
                Text(Design.Header.title)
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("\(Design.Header.activeProviderPrefix)\(viewModel.activeProviderName)")
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

        private var executionBackend: some View {
            VStack(alignment: .leading, spacing: Design.ExecutionBackend.spacing) {
                HStack {
                    Label(Design.ExecutionBackend.title, systemImage: Design.ExecutionBackend.icon)
                        .font(.headline)

                    Spacer()

                    Text(Design.ExecutionBackend.nextRunLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Picker(Design.ExecutionBackend.pickerTitle, selection: Binding(
                    get: { viewModel.activeProviderId ?? "" },
                    set: { providerId in
                        guard !providerId.isEmpty else { return }
                        viewModel.selectProvider(id: providerId)
                    }
                )) {
                    ForEach(viewModel.providers) { provider in
                        Text(provider.name).tag(provider.id)
                    }
                }
                .pickerStyle(.menu)

                if let selectedProvider = viewModel.selectedProvider {
                    HStack(spacing: Design.ExecutionBackend.detailSpacing) {
                        Image(systemName: Design.ExecutionBackend.selectedIcon)
                            .foregroundStyle(.green)

                        VStack(alignment: .leading, spacing: Design.ExecutionBackend.detailTextSpacing) {
                            Text(selectedProvider.name)
                                .font(.body)
                                .fontWeight(.semibold)
                            Text("\(selectedProvider.transport) · \(selectedProvider.availability)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()
                    }
                }
            }
            .padding(Design.ExecutionBackend.padding)
            .background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: Design.ExecutionBackend.cornerRadius))
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

        private var providerList: some View {
            VStack(alignment: .leading, spacing: Design.ProviderList.spacing) {
                Text(Design.ProviderList.title)
                    .font(.headline)

                ForEach(viewModel.providers) { provider in
                    Button {
                        viewModel.selectProvider(id: provider.id)
                    } label: {
                        ProviderRow(provider: provider)
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(width: Design.ProviderList.width, alignment: .topLeading)
        }

        @ViewBuilder
        private var providerDetails: some View {
            if let selectedProvider = viewModel.selectedProvider {
                VStack(alignment: .leading, spacing: Design.ProviderDetails.spacing) {
                    VStack(alignment: .leading, spacing: Design.ProviderDetails.titleSpacing) {
                        Text(selectedProvider.name)
                            .font(.title3)
                            .fontWeight(.semibold)
                        Text(selectedProvider.id)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }

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
    }

    private struct ProviderRow: View {
        typealias Design = SettingsPageDesign.ProviderRow

        let provider: ProviderSettingsItem

        var body: some View {
            HStack(spacing: Design.spacing) {
                Image(systemName: provider.isActive ? Design.activeIcon : Design.inactiveIcon)
                    .foregroundStyle(provider.isActive ? .green : .secondary)
                    .frame(width: Design.iconSize, height: Design.iconSize)

                VStack(alignment: .leading, spacing: Design.textSpacing) {
                    Text(provider.name)
                        .font(.body)
                        .fontWeight(provider.isActive ? .semibold : .regular)
                    Text(provider.id)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()
            }
            .padding(Design.padding)
            .background {
                if provider.isActive {
                    RoundedRectangle(cornerRadius: Design.cornerRadius)
                        .fill(.regularMaterial)
                } else {
                    RoundedRectangle(cornerRadius: Design.cornerRadius)
                        .fill(Color.clear)
                }
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
