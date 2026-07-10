//
// ACPAgentFactory.swift
// WorkHarness
//
// Created by Auto (Codex) on 10.07.2026.
//

import Foundation

struct ACPAgentDefinition: Equatable {
    var id: String
    var displayName: String
    var subprocess: ACPSubprocessConfiguration

    init(id: String, displayName: String, subprocess: ACPSubprocessConfiguration) {
        self.id = id
        self.displayName = displayName
        self.subprocess = subprocess
    }
}

@MainActor
final class ACPAgentFactory: AgentFactory {
    private let definition: ACPAgentDefinition

    init(definition: ACPAgentDefinition) {
        self.definition = definition
    }

    func makeRuntime() -> AgentRuntime {
        let transport = ACPSubprocessTransport(configuration: definition.subprocess)
        let client = ACPSubprocessClient(
            id: definition.id,
            displayName: definition.displayName,
            transport: transport
        )
        return ACPClientRuntime(client: client)
    }
}
