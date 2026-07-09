//
// ProvidersRegister.swift
// WorkHarness
//
// Created by Auto (Codex) on 07.07.2026.
//

import Swinject

extension Container {
    func registerProviders() {
        register(MCPProviderClientProtocol.self) { resolver in
            let appSettings = resolver.resolve(AppSettingsServiceProtocol.self)!
            return MCPProviderClient(configuration: MCPProviderConfiguration(
                serverBasePath: appSettings.mcpServerBasePath,
                localLLMEndpointURL: appSettings.localLLMEndpoint,
                localLLMModel: appSettings.localLLMModel
            ))
        }.inObjectScope(.container)

        register(ProviderRegistry.self) { resolver in
            let mcpClient = resolver.resolve(MCPProviderClientProtocol.self)!
            return ProviderRegistry(
                providers: [
                    MockAIProvider(),
                    MCPBackedAIProvider(descriptor: .codexCLI, client: mcpClient),
                    MCPBackedAIProvider(descriptor: .cursorCLI, client: mcpClient),
                    MCPBackedAIProvider(descriptor: .localLLM, client: mcpClient)
                ],
                defaultProviderId: MockAIProvider.providerId
            )
        }.inObjectScope(.container)
    }
}
