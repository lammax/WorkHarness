//
// AgentRuntimeRegister.swift
// WorkHarness
//
// Created by Auto (Codex) on 10.07.2026.
//

import Foundation
import Swinject

extension Container {
    func registerAgentRuntime() {
        register(AgentRuntimeRegistry.self) { resolver in
            let registry = AgentRuntimeRegistry()
            if let definition = ACPAgentDefinitions.cursor() {
                registry.register(ACPAgentFactory(
                    definition: definition,
                    approvalService: resolver.resolve(ApprovalServiceProtocol.self)
                ).makeRuntime())
            }
            if let executableURL = AgentExecutableLocator.find(named: "claude"),
               let appSettingsService = resolver.resolve(AppSettingsServiceProtocol.self) {
                let configurationFactory = ClaudeMCPConfigurationFactory {
                    let port = UInt16(clamping: appSettingsService.remoteControlPort)
                    var components = URLComponents()
                    components.scheme = "http"
                    components.host = "127.0.0.1"
                    components.port = Int(port)
                    guard let baseURL = components.url else {
                        preconditionFailure("Invalid WorkHarness MCP gateway URL.")
                    }
                    let token = appSettingsService.remoteControlToken
                    return ClaudeMCPConfigurationFactory.GatewaySettings(
                        baseURL: baseURL,
                        authorizationToken: token.isEmpty ? nil : token
                    )
                }
                registry.register(ClaudeCLIRuntime(
                    executableURL: executableURL,
                    transport: CLIAgentSubprocessTransport(),
                    mcpConfigurationFactory: configurationFactory
                ))
            }
            return registry
        }.inObjectScope(.container)
    }
}
