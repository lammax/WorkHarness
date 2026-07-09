//
// SettingsPageViewModel.swift
// WorkHarness
//
// Created by Auto (Codex) on 08.07.2026.
//

import Foundation
import Observation

extension MainScreen {
    @MainActor
    @Observable
    final class SettingsPageViewModel {
        private let providerService: ProviderServiceProtocol
        private let appSettingsService: AppSettingsServiceProtocol

        private(set) var providers: [ProviderSettingsItem] = []
        private(set) var activeProviderId: String?
        private(set) var errorMessage: String?
        var selectedSafetyMode: SafetyMode
        var mcpServerBasePath: String
        var localLLMEndpoint: String
        var localLLMModel: String
        var defaultMaxInputTokens: Int
        var defaultMaxOutputTokens: Int

        init(providerService: ProviderServiceProtocol, appSettingsService: AppSettingsServiceProtocol) {
            self.providerService = providerService
            self.appSettingsService = appSettingsService
            self.selectedSafetyMode = appSettingsService.defaultSafetyMode
            self.mcpServerBasePath = appSettingsService.mcpServerBasePath
            self.localLLMEndpoint = appSettingsService.localLLMEndpoint
            self.localLLMModel = appSettingsService.localLLMModel
            self.defaultMaxInputTokens = appSettingsService.defaultMaxInputTokens
            self.defaultMaxOutputTokens = appSettingsService.defaultMaxOutputTokens
            reloadProviders()
        }

        var activeProviderName: String {
            selectedProvider?.name ?? SettingsPageDesign.ProviderFallback.noActiveProvider
        }

        var hasUnsavedAppSettingsChanges: Bool {
            currentAppSettingsSnapshot != persistedAppSettingsSnapshot
        }

        var appSettingsStatus: String {
            hasUnsavedAppSettingsChanges ? SettingsPageDesign.AppSettings.unsavedStatus : SettingsPageDesign.AppSettings.savedStatus
        }

        var selectedProvider: ProviderSettingsItem? {
            guard let activeProviderId else { return providers.first }
            return providers.first { $0.id == activeProviderId }
        }

        func reloadProviders() {
            activeProviderId = providerService.activeProviderId
            providers = providerService.availableProviders.map { provider in
                ProviderSettingsItem(
                    id: provider.id,
                    name: provider.displayName,
                    isActive: provider.id == activeProviderId,
                    capabilities: capabilityRows(for: provider.capabilities)
                )
            }
        }

        func selectProvider(id providerId: String) {
            do {
                try providerService.selectProvider(id: providerId)
                errorMessage = nil
                reloadProviders()
            } catch {
                errorMessage = error.localizedDescription
            }
        }

        func saveSettings() {
            appSettingsService.defaultSafetyMode = selectedSafetyMode
            appSettingsService.mcpServerBasePath = mcpServerBasePath
            appSettingsService.localLLMEndpoint = localLLMEndpoint
            appSettingsService.localLLMModel = localLLMModel
            appSettingsService.defaultMaxInputTokens = defaultMaxInputTokens
            appSettingsService.defaultMaxOutputTokens = defaultMaxOutputTokens

            mcpServerBasePath = appSettingsService.mcpServerBasePath
            localLLMEndpoint = appSettingsService.localLLMEndpoint
            localLLMModel = appSettingsService.localLLMModel
            defaultMaxInputTokens = appSettingsService.defaultMaxInputTokens
            defaultMaxOutputTokens = appSettingsService.defaultMaxOutputTokens
            errorMessage = nil
        }

        func revertSettings() {
            loadSettingsFromService()
            errorMessage = nil
        }

        func restoreDefaultSettingsDraft() {
            selectedSafetyMode = AppSettingsDefaults.defaultSafetyMode
            mcpServerBasePath = AppSettingsDefaults.mcpServerBasePath
            localLLMEndpoint = AppSettingsDefaults.localLLMEndpoint
            localLLMModel = AppSettingsDefaults.localLLMModel
            defaultMaxInputTokens = AppSettingsDefaults.defaultMaxInputTokens
            defaultMaxOutputTokens = AppSettingsDefaults.defaultMaxOutputTokens
            errorMessage = nil
        }

        func resetSettings() {
            restoreDefaultSettingsDraft()
        }

        private func capabilityRows(for capabilities: ProviderCapabilities) -> [ProviderCapabilityRow] {
            [
                .init(title: SettingsPageDesign.Capability.streaming, value: label(for: capabilities.supportsStreaming)),
                .init(title: SettingsPageDesign.Capability.toolCalls, value: label(for: capabilities.supportsToolCalls)),
                .init(title: SettingsPageDesign.Capability.fileEditing, value: label(for: capabilities.supportsFileEditing)),
                .init(title: SettingsPageDesign.Capability.shellExecution, value: label(for: capabilities.supportsShellExecution)),
                .init(title: SettingsPageDesign.Capability.vision, value: label(for: capabilities.supportsVision)),
                .init(title: SettingsPageDesign.Capability.embeddings, value: label(for: capabilities.supportsEmbeddings)),
                .init(title: SettingsPageDesign.Capability.reasoning, value: label(for: capabilities.supportsReasoningMode)),
                .init(title: SettingsPageDesign.Capability.localExecution, value: label(for: capabilities.supportsLocalExecution)),
                .init(title: SettingsPageDesign.Capability.approvals, value: label(for: capabilities.supportsApprovals)),
                .init(title: SettingsPageDesign.Capability.mcp, value: label(for: capabilities.supportsMCP)),
                .init(title: SettingsPageDesign.Capability.contextWindow, value: contextWindowLabel(for: capabilities.contextWindowTokens)),
                .init(title: SettingsPageDesign.Capability.costModel, value: capabilities.costModel ?? SettingsPageDesign.ProviderFallback.notAvailable),
                .init(title: SettingsPageDesign.Capability.models, value: modelsLabel(for: capabilities.supportedModels))
            ]
        }

        private func label(for flag: Bool) -> String {
            flag ? SettingsPageDesign.ProviderFallback.yes : SettingsPageDesign.ProviderFallback.no
        }

        private func contextWindowLabel(for tokenCount: Int?) -> String {
            guard let tokenCount else { return SettingsPageDesign.ProviderFallback.notAvailable }
            return "\(tokenCount) \(SettingsPageDesign.ProviderFallback.tokensSuffix)"
        }

        private func modelsLabel(for models: [String]) -> String {
            models.isEmpty ? SettingsPageDesign.ProviderFallback.notAvailable : models.joined(separator: SettingsPageDesign.ProviderFallback.listSeparator)
        }

        private func loadSettingsFromService() {
            selectedSafetyMode = appSettingsService.defaultSafetyMode
            mcpServerBasePath = appSettingsService.mcpServerBasePath
            localLLMEndpoint = appSettingsService.localLLMEndpoint
            localLLMModel = appSettingsService.localLLMModel
            defaultMaxInputTokens = appSettingsService.defaultMaxInputTokens
            defaultMaxOutputTokens = appSettingsService.defaultMaxOutputTokens
        }

        private var currentAppSettingsSnapshot: EditableAppSettingsSnapshot {
            EditableAppSettingsSnapshot(
                safetyMode: selectedSafetyMode,
                mcpServerBasePath: mcpServerBasePath,
                localLLMEndpoint: localLLMEndpoint,
                localLLMModel: localLLMModel,
                defaultMaxInputTokens: defaultMaxInputTokens,
                defaultMaxOutputTokens: defaultMaxOutputTokens
            )
        }

        private var persistedAppSettingsSnapshot: EditableAppSettingsSnapshot {
            EditableAppSettingsSnapshot(
                safetyMode: appSettingsService.defaultSafetyMode,
                mcpServerBasePath: appSettingsService.mcpServerBasePath,
                localLLMEndpoint: appSettingsService.localLLMEndpoint,
                localLLMModel: appSettingsService.localLLMModel,
                defaultMaxInputTokens: appSettingsService.defaultMaxInputTokens,
                defaultMaxOutputTokens: appSettingsService.defaultMaxOutputTokens
            )
        }
    }

    private struct EditableAppSettingsSnapshot: Equatable {
        var safetyMode: SafetyMode
        var mcpServerBasePath: String
        var localLLMEndpoint: String
        var localLLMModel: String
        var defaultMaxInputTokens: Int
        var defaultMaxOutputTokens: Int
    }

    struct ProviderSettingsItem: Identifiable, Equatable {
        var id: String
        var name: String
        var isActive: Bool
        var capabilities: [ProviderCapabilityRow]
    }

    struct ProviderCapabilityRow: Identifiable, Equatable {
        var id: String { title }
        var title: String
        var value: String
    }
}
