//
// AgentModelRoutingServiceProtocol.swift
// WorkHarness
//
// Created by Auto (Codex) on 29.07.2026.
//

@MainActor
protocol AgentModelRoutingServiceProtocol: BaseServiceProtocol {
    func decision(
        for prompt: String,
        runtime: AgentRuntimeDescriptor,
        manualModelId: String?
    ) -> AgentModelRoutingDecision
}

extension AgentModelRoutingServiceProtocol {
    var service: AppService { .modelRouting }
}
