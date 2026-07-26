//
// ProviderServiceProtocol.swift
// WorkHarness
//
// Created by Auto (Codex) on 08.07.2026.
//

@MainActor
protocol ProviderServiceProtocol: BaseServiceProtocol {
    var availableProviders: [ProviderDefinition] { get }
    var activeProviderId: String? { get }
    var activeProviderName: String { get }

    func activeProvider() throws -> any AIProvider
    func selectProvider(id providerId: String) throws
    func capabilities(for providerId: String) throws -> ProviderCapabilities
    func loadLocalLLMModels(endpointURL: String) async throws -> [LocalLLMModelOption]
}

extension ProviderServiceProtocol {
    var service: AppService { .providers }
}
