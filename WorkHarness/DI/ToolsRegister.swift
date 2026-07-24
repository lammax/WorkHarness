//
// ToolsRegister.swift
// WorkHarness
//
// Created by Auto (Codex) on 09.07.2026.
//

import Swinject

extension Container {
    func registerTools() {
        register(ToolRegistry.self) { resolver in
            ToolRegistry(tools: [
                FileReadTool(),
                FileWriteTool(),
                ShellTool(),
                GitTool(),
                RAGSearchTool()
            ] + MobileAutomationTool.approvedTools)
        }.inObjectScope(.container)

        register(MCPServerProcessSupervisorProtocol.self) { resolver in
            let settings = resolver.resolve(AppSettingsServiceProtocol.self)!
            return MCPServerProcessSupervisor {
                settings.mcpServerBasePath
            }
        }.inObjectScope(.container)

        register(MCPToolClientProtocol.self) { resolver in
            MCPToolClient(transport: MCPHTTPToolTransport(
                serverSupervisor: resolver.resolve(MCPServerProcessSupervisorProtocol.self)!
            ))
        }.inObjectScope(.container)

        register(ToolServiceProtocol.self) { resolver in
            ToolService(
                registry: resolver.resolve(ToolRegistry.self)!,
                mcpClient: resolver.resolve(MCPToolClientProtocol.self)!,
                approvalService: resolver.resolve(ApprovalServiceProtocol.self)!,
                recorder: resolver.resolve(RunRecorder.self)!
            )
        }.inObjectScope(.container)

        register(MCPApprovalGatewayProtocol.self) { resolver in
            MCPApprovalGateway(toolService: resolver.resolve(ToolServiceProtocol.self)!)
        }.inObjectScope(.container)
    }
}
