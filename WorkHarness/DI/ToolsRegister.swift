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
                MCPToolAdapter()
            ])
        }.inObjectScope(.container)

        register(MCPToolClientProtocol.self) { _ in
            MCPToolClient()
        }.inObjectScope(.container)

        register(ToolServiceProtocol.self) { resolver in
            ToolService(
                registry: resolver.resolve(ToolRegistry.self)!,
                mcpClient: resolver.resolve(MCPToolClientProtocol.self)!,
                approvalService: resolver.resolve(ApprovalServiceProtocol.self)!,
                recorder: resolver.resolve(RunRecorder.self)!
            )
        }.inObjectScope(.container)
    }
}
