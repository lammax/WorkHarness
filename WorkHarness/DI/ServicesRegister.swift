//
// ServicesRegister.swift
// WorkHarness
//
// Created by Auto (Codex) on 07.07.2026.
//

import Swinject

extension Container {
    func registerServices() {
        register(AppSettingsServiceProtocol.self) { _ in
            UserDefaultsAppSettingsService()
        }.inObjectScope(.container)

        register(ApprovalServiceProtocol.self) { resolver in
            ApprovalService(
                repository: resolver.resolve(ApprovalRepositoryProtocol.self)!,
                runRepository: resolver.resolve(RunRepository.self)!,
                recorder: resolver.resolve(RunRecorder.self)!,
                appSettingsService: resolver.resolve(AppSettingsServiceProtocol.self)!
            )
        }.inObjectScope(.container)

        register(RemoteControlServiceProtocol.self) { resolver in
            RemoteControlService(
                runRepository: resolver.resolve(RunRepository.self)!,
                runService: resolver.resolve(RunServiceProtocol.self)!,
                projectService: resolver.resolve(ProjectServiceProtocol.self)!,
                approvalService: resolver.resolve(ApprovalServiceProtocol.self)!,
                appSettingsService: resolver.resolve(AppSettingsServiceProtocol.self)!,
                mcpApprovalGateway: resolver.resolve(MCPApprovalGatewayProtocol.self)!
            )
        }.inObjectScope(.container)

        register(ProviderServiceProtocol.self) { resolver in
            ProviderService(
                registry: resolver.resolve(ProviderRegistry.self)!,
                appSettingsService: resolver.resolve(AppSettingsServiceProtocol.self)!
            )
        }.inObjectScope(.container)

        register(ProjectServiceProtocol.self) { resolver in
            ProjectService(repository: resolver.resolve(ProjectRepositoryProtocol.self)!)
        }.inObjectScope(.container)

        register(AgentProfileServiceProtocol.self) { resolver in
            AgentProfileService(
                projectService: resolver.resolve(ProjectServiceProtocol.self)!
            )
        }.inObjectScope(.container)

        register(TestingConfigurationServiceProtocol.self) { resolver in
            TestingConfigurationService(
                projectService: resolver.resolve(ProjectServiceProtocol.self)!
            )
        }.inObjectScope(.container)

        register(TestingEnvironmentServiceProtocol.self) { resolver in
            TestingEnvironmentService(
                mcpClient: resolver.resolve(MCPToolClientProtocol.self)!
            )
        }.inObjectScope(.container)

        register(RunServiceProtocol.self) { resolver in
            RunService(
                repository: resolver.resolve(RunRepository.self)!,
                harnessEngine: resolver.resolve(HarnessEngine.self)!
            )
        }.inObjectScope(.container)

        register(RunContextAttachmentServiceProtocol.self) { _ in
            RunContextAttachmentService()
        }.inObjectScope(.container)

        register(UsageStatisticsServiceProtocol.self) { resolver in
            UsageStatisticsService(runService: resolver.resolve(RunServiceProtocol.self)!)
        }.inObjectScope(.container)

        register(MemoryServiceProtocol.self) { resolver in
            MemoryService(
                repository: resolver.resolve(MemoryRepositoryProtocol.self)!,
                recorder: resolver.resolve(RunRecorder.self)!
            )
        }.inObjectScope(.container)

        register(RAGMCPClientProtocol.self) { _ in
            RAGMCPClient()
        }.inObjectScope(.container)

        register(RAGServiceProtocol.self) { resolver in
            RAGService(client: resolver.resolve(RAGMCPClientProtocol.self)!)
        }.inObjectScope(.container)
    }
}
