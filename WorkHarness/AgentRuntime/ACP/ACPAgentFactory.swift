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
    private let approvalService: ApprovalServiceProtocol?

    init(definition: ACPAgentDefinition, approvalService: ApprovalServiceProtocol? = nil) {
        self.definition = definition
        self.approvalService = approvalService
    }

    func makeRuntime() -> AgentRuntime {
        let transport = ACPSubprocessTransport(configuration: definition.subprocess)
        let client = ACPSubprocessClient(
            id: definition.id,
            displayName: definition.displayName,
            transport: transport,
            workingDirectory: definition.subprocess.workingDirectoryURL,
            approvalService: approvalService
        )
        return ACPClientRuntime(client: client)
    }
}

enum ACPAgentDefinitions {
    static func cursor() -> ACPAgentDefinition? {
        guard let executableURL = AgentExecutableLocator.find(named: "cursor-agent") else { return nil }
        return ACPAgentDefinition(
            id: "cursor.acp",
            displayName: "Cursor ACP",
            subprocess: ACPSubprocessConfiguration(
                executableURL: executableURL,
                arguments: ["acp"]
            )
        )
    }
}
