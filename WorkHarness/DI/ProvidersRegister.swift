//
// ProvidersRegister.swift
// WorkHarness
//
// Created by Auto (Codex) on 07.07.2026.
//

import Swinject

extension Container {
    func registerProviders() {
        register(ProviderRegistry.self) { _ in
            ProviderRegistry(providers: [MockAIProvider()], defaultProviderId: MockAIProvider.providerId)
        }.inObjectScope(.container)
    }
}
