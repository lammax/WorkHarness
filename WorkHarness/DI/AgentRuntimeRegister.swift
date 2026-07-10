//
// AgentRuntimeRegister.swift
// WorkHarness
//
// Created by Auto (Codex) on 10.07.2026.
//

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
            return registry
        }.inObjectScope(.container)
    }
}
