//
// EngineRegister.swift
// WorkHarness
//
// Created by Auto (Codex) on 07.07.2026.
//

import Swinject

extension Container {
    func registerEngine() {
        register(ContextTokenEstimatorProtocol.self) { _ in
            ApproximateContextTokenEstimator()
        }.inObjectScope(.container)

        register(ContextBuilderProtocol.self) { resolver in
            ContextBuilder(
                tokenEstimator: resolver.resolve(ContextTokenEstimatorProtocol.self)!
            )
        }.inObjectScope(.container)

        register(ContextFoldingServiceProtocol.self) { _ in
            ContextFoldingService()
        }.inObjectScope(.container)

        register(RunRecorder.self) { resolver in
            RunRecorder(repository: resolver.resolve(RunRepository.self)!)
        }.inObjectScope(.container)

        register(MultiAgentCoordinator.self) { resolver in
            MultiAgentCoordinator(
                repository: resolver.resolve(RunRepository.self)!,
                recorder: resolver.resolve(RunRecorder.self)!
            )
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
                agentModelRoutingService: resolver.resolve(AgentModelRoutingServiceProtocol.self)!,
                agentRuntimeRegistry: resolver.resolve(AgentRuntimeRegistry.self)!,
                multiAgentCoordinator: resolver.resolve(MultiAgentCoordinator.self)!
            )
        }.inObjectScope(.container)
    }
}
