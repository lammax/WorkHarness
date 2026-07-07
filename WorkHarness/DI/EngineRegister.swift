//
// EngineRegister.swift
// WorkHarness
//
// Created by Auto (Codex) on 07.07.2026.
//

import Swinject

extension Container {
    func registerEngine() {
        register(RunRecorder.self) { resolver in
            RunRecorder(repository: resolver.resolve(RunRepository.self)!)
        }.inObjectScope(.container)

        register(HarnessEngine.self) { resolver in
            HarnessEngine(
                repository: resolver.resolve(RunRepository.self)!,
                recorder: resolver.resolve(RunRecorder.self)!,
                providerService: resolver.resolve(ProviderServiceProtocol.self)!
            )
        }.inObjectScope(.container)
    }
}
