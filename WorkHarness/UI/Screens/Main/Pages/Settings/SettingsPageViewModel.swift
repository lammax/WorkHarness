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

        private(set) var providers: [ProviderSettingsItem] = []
        private(set) var activeProviderId: String?
        private(set) var errorMessage: String?

        init(providerService: ProviderServiceProtocol) {
            self.providerService = providerService
            reloadProviders()
        }

        var activeProviderName: String {
            selectedProvider?.name ?? SettingsPageDesign.ProviderFallback.noActiveProvider
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
