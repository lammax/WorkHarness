//
// ProvidersRegister.swift
// WorkHarness
//
// Created by Auto (Codex) on 07.07.2026.
//

import Swinject

extension Container {
    func registerProviders() {
        register(MCPProviderClientProtocol.self) { _ in
            MCPProviderClient()
        }.inObjectScope(.container)

        register(ProviderRegistry.self) { resolver in
            let mcpClient = resolver.resolve(MCPProviderClientProtocol.self)!
            return ProviderRegistry(
                providers: [
                    MockAIProvider(),
                    MCPBackedAIProvider(descriptor: .codexCLI, client: mcpClient),
                    MCPBackedAIProvider(descriptor: .cursorCLI, client: mcpClient)
                ],
                defaultProviderId: MockAIProvider.providerId
            )
        }.inObjectScope(.container)
    }
}
