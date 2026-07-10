//
// EngineRegister.swift
// WorkHarness
//
// Created by Auto (Codex) on 07.07.2026.
//

import Swinject

extension Container {
    func registerEngine() {
        register(ContextBuilderProtocol.self) { _ in
            ContextBuilder()
        }.inObjectScope(.container)

        register(ContextFoldingServiceProtocol.self) { _ in
            ContextFoldingService()
        }.inObjectScope(.container)

        register(RunRecorder.self) { resolver in
            RunRecorder(repository: resolver.resolve(RunRepository.self)!)
        }.inObjectScope(.container)

        register(HarnessEngine.self) { resolver in
            HarnessEngine(
                repository: resolver.resolve(RunRepository.self)!,
                recorder: resolver.resolve(RunRecorder.self)!,
                providerService: resolver.resolve(ProviderServiceProtocol.self)!,
                projectService: resolver.resolve(ProjectServiceProtocol.self)!,
                contextBuilder: resolver.resolve(ContextBuilderProtocol.self)!,
                contextFoldingService: resolver.resolve(ContextFoldingServiceProtocol.self)!,
                memoryService: resolver.resolve(MemoryServiceProtocol.self)!,
                ragService: resolver.resolve(RAGServiceProtocol.self)!,
                appSettingsService: resolver.resolve(AppSettingsServiceProtocol.self)!,
                agentRuntimeRegistry: resolver.resolve(AgentRuntimeRegistry.self)!
            )
        }.inObjectScope(.container)
    }
}
