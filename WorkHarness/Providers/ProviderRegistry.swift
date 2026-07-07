//
// ProviderRegistry.swift
// WorkHarness
//
// Created by Auto (Codex) on 08.07.2026.
//

@MainActor
final class ProviderRegistry {
    private var providersById: [String: any AIProvider] = [:]
    private(set) var activeProviderId: String?

    init(providers: [any AIProvider] = [], defaultProviderId: String? = nil) {
        providers.forEach { provider in
            providersById[provider.id] = provider
        }

        if let defaultProviderId {
            activeProviderId = providersById[defaultProviderId] == nil ? providers.first?.id : defaultProviderId
        } else {
            activeProviderId = providers.first?.id
        }
    }

    var availableProviders: [ProviderDefinition] {
        providersById.values
            .map {
                ProviderDefinition(
                    id: $0.id,
                    displayName: $0.displayName,
                    capabilities: $0.capabilities
                )
            }
            .sorted { $0.displayName < $1.displayName }
    }

    func register(_ provider: any AIProvider, makeActive: Bool = false) {
        providersById[provider.id] = provider

        if activeProviderId == nil || makeActive {
            activeProviderId = provider.id
        }
    }

    func selectProvider(id providerId: String) throws {
        guard providersById[providerId] != nil else {
            throw ProviderError.providerNotFound(providerId)
        }

        activeProviderId = providerId
    }

    func provider(id providerId: String) throws -> any AIProvider {
        guard let provider = providersById[providerId] else {
            throw ProviderError.providerNotFound(providerId)
        }

        return provider
    }

    func activeProvider() throws -> any AIProvider {
        guard let activeProviderId else {
            throw ProviderError.noActiveProvider
        }

        return try provider(id: activeProviderId)
    }

    func capabilities(for providerId: String) throws -> ProviderCapabilities {
        try provider(id: providerId).capabilities
    }
}
