//
// ProvidersRegister.swift
// WorkHarness
//
// Created by Auto (Codex) on 07.07.2026.
//

import Swinject

extension Container {
    func registerProviders() {
        register(ProviderRegistry.self) { resolver in
            ProviderRegistry(
                providers: [
                    MockAIProvider(),
                    CodexCLIProvider(processRunner: resolver.resolve(ProcessRunnerProtocol.self)!)
                ],
                defaultProviderId: MockAIProvider.providerId
            )
        }.inObjectScope(.container)
    }
}
