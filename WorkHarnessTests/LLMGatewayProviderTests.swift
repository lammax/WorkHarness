//
// LLMGatewayProviderTests.swift
// WorkHarness
//
// Created by Auto (Codex) on 08.08.2026.
//

import Foundation
import Testing
@testable import WorkHarness

@Suite("LLM Gateway provider")
@MainActor
struct LLMGatewayProviderTests {
    @Test func descriptorUsesMCPBoundaryAndReportsUsageSupport() {
        let descriptor = MCPProviderDescriptor.llmGateway
        #expect(descriptor.id == "mcp.llm.gateway")
        #expect(descriptor.mcpEndpointURL == "http://127.0.0.1:3013/mcp")
        #expect(descriptor.capabilities.supportsMCP)
        #expect(descriptor.capabilities.supportsUsageReporting == true)
        #expect(descriptor.capabilities.costModel == "gateway-estimated")
    }

    @Test func configurationIncludesGatewayByDefault() {
        let configuration = MCPProviderConfiguration()
        #expect(configuration.providerDescriptors.contains { $0.id == MCPProviderDescriptor.llmGateway.id })
        #expect(configuration.llmGatewayEndpointURL == "http://127.0.0.1:3013/mcp")
    }

    @Test func gatewayContextIsDeliveredAsOneDeterministicSystemMessage() {
        let client = MCPProviderClient(configuration: MCPProviderConfiguration())
        let agent = Agent(
            role: .coder,
            providerId: MCPProviderDescriptor.llmGateway.id,
            model: "gpt-4.1-mini"
        )
        let request = AIRequest(
            runId: UUID(),
            agent: agent,
            messages: [.init(role: .user, content: "Hello")],
            context: ["Objective", "Constraint"]
        )

        let messages = client.localLLMMessages(from: request)

        #expect(messages == [
            LocalLLMMessage(role: "system", content: "Objective\n\nConstraint"),
            LocalLLMMessage(role: "user", content: "Hello")
        ])
    }
}
