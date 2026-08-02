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
    var modelOptions: [AgentRuntimeModelOption]
    var defaultModelId: String?
    var capabilities: AgentCapabilities
    var contextWindowTokens: Int?
    var supportsUsageReporting: Bool?
    var supportsCancellation: Bool?

    init(
        id: String,
        displayName: String,
        subprocess: ACPSubprocessConfiguration,
        modelOptions: [AgentRuntimeModelOption] = [],
        defaultModelId: String? = nil,
        capabilities: AgentCapabilities = AgentCapabilities(),
        contextWindowTokens: Int? = nil,
        supportsUsageReporting: Bool? = nil,
        supportsCancellation: Bool? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.subprocess = subprocess
        self.modelOptions = modelOptions
        self.defaultModelId = defaultModelId
        self.capabilities = capabilities
        self.contextWindowTokens = contextWindowTokens
        self.supportsUsageReporting = supportsUsageReporting
        self.supportsCancellation = supportsCancellation
    }

    var descriptor: AgentRuntimeDescriptor {
        AgentRuntimeDescriptor(
            id: id,
            displayName: displayName,
            transport: .acp,
            authentication: .runtimeManaged,
            modelOptions: modelOptions,
            defaultModelId: defaultModelId,
            contextDeliveryMode: .renderedPrompt,
            capabilities: capabilities,
            contextWindowTokens: contextWindowTokens,
            supportsUsageReporting: supportsUsageReporting,
            supportsCancellation: supportsCancellation
        )
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
        return ACPClientRuntime(client: client, descriptor: definition.descriptor)
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
            ),
            modelOptions: CursorACPModelOption.allCases.map {
                AgentRuntimeModelOption(id: $0.id, title: $0.title)
            },
            defaultModelId: CursorACPModelOption.defaultModel.id,
            capabilities: AgentCapabilities([
                .canEditFiles,
                .canSearch,
                .canPlan,
                .canUseTools,
                .canStreamTokens,
                .canExecuteTerminal,
                .canReadGit,
                .canRunTests,
                .canOpenDiff
            ]),
            supportsUsageReporting: true,
            supportsCancellation: true
        )
    }
}
