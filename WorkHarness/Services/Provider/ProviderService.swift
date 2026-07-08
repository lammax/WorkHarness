//
// ProviderService.swift
// WorkHarness
//
// Created by Auto (Codex) on 08.07.2026.
//

@MainActor
final class ProviderService: ProviderServiceProtocol {
    private let registry: ProviderRegistry
    private let appSettingsService: AppSettingsServiceProtocol

    init(registry: ProviderRegistry, appSettingsService: AppSettingsServiceProtocol) {
        self.registry = registry
        self.appSettingsService = appSettingsService
        restoreActiveProvider()
    }

    var availableProviders: [ProviderDefinition] {
        registry.availableProviders
    }

    var activeProviderId: String? {
        registry.activeProviderId
    }

    var activeProviderName: String {
        (try? activeProvider().displayName) ?? "No Provider"
    }

    func activeProvider() throws -> any AIProvider {
        try registry.activeProvider()
    }

    func selectProvider(id providerId: String) throws {
        try registry.selectProvider(id: providerId)
        appSettingsService.defaultProviderId = providerId
    }

    func capabilities(for providerId: String) throws -> ProviderCapabilities {
        try registry.capabilities(for: providerId)
    }

    private func restoreActiveProvider() {
        if let savedProviderId = appSettingsService.defaultProviderId {
            do {
                try registry.selectProvider(id: savedProviderId)
                return
            } catch {
                selectFallbackProvider()
                return
            }
        }

        if registry.activeProviderId == nil {
            selectFallbackProvider()
        }
    }

    private func selectFallbackProvider() {
        if (try? registry.provider(id: MockAIProvider.providerId)) != nil {
            try? registry.selectProvider(id: MockAIProvider.providerId)
            appSettingsService.defaultProviderId = MockAIProvider.providerId
        }
    }
}
