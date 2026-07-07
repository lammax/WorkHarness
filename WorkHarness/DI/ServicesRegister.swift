//
// ServicesRegister.swift
// WorkHarness
//
// Created by Auto (Codex) on 07.07.2026.
//

import Swinject

extension Container {
    func registerServices() {
        register(ProviderServiceProtocol.self) { resolver in
            ProviderService(registry: resolver.resolve(ProviderRegistry.self)!)
        }.inObjectScope(.container)

        register(RunServiceProtocol.self) { resolver in
            RunService(
                repository: resolver.resolve(RunRepository.self)!,
                harnessEngine: resolver.resolve(HarnessEngine.self)!
            )
        }.inObjectScope(.container)
    }
}
