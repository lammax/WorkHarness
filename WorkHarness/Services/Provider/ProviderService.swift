//
// ProviderService.swift
// WorkHarness
//
// Created by Auto (Codex) on 08.07.2026.
//

@MainActor
final class ProviderService: ProviderServiceProtocol {
    private let registry: ProviderRegistry

    init(registry: ProviderRegistry) {
        self.registry = registry
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
    }

    func capabilities(for providerId: String) throws -> ProviderCapabilities {
        try registry.capabilities(for: providerId)
    }
}
