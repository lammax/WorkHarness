//
// InMemoryAppSettingsService.swift
// WorkHarness
//
// Created by Auto (Codex) on 08.07.2026.
//

@MainActor
final class InMemoryAppSettingsService: AppSettingsServiceProtocol {
    var defaultProviderId: String?
    var defaultAgentRuntimeId: String?
    var defaultAgentModelId: String
    var defaultSafetyMode: SafetyMode
    var mcpServerBasePath: String
    var localLLMEndpoint: String
    var localLLMModel: String
    var defaultMaxInputTokens: Int
    var defaultMaxOutputTokens: Int
    var remoteControlEnabled: Bool
    var remoteControlAllowLAN: Bool
    var remoteControlPort: Int
    var remoteControlToken: String
    var ragAnswerMode: RAGAnswerMode
    var ragRetrievalSettings: RAGRetrievalSettings
    private var agentModelIds: [String: String]

    init(
        defaultProviderId: String? = nil,
        defaultAgentRuntimeId: String? = nil,
        defaultAgentModelId: String = AppSettingsDefaults.defaultAgentModelId,
        defaultSafetyMode: SafetyMode = AppSettingsDefaults.defaultSafetyMode,
        mcpServerBasePath: String = AppSettingsDefaults.mcpServerBasePath,
        localLLMEndpoint: String = AppSettingsDefaults.localLLMEndpoint,
        localLLMModel: String = AppSettingsDefaults.localLLMModel,
        defaultMaxInputTokens: Int = AppSettingsDefaults.defaultMaxInputTokens,
        defaultMaxOutputTokens: Int = AppSettingsDefaults.defaultMaxOutputTokens,
        remoteControlEnabled: Bool = AppSettingsDefaults.remoteControlEnabled,
        remoteControlAllowLAN: Bool = AppSettingsDefaults.remoteControlAllowLAN,
        remoteControlPort: Int = AppSettingsDefaults.remoteControlPort,
        remoteControlToken: String = AppSettingsDefaults.remoteControlToken,
        ragAnswerMode: RAGAnswerMode = AppSettingsDefaults.ragAnswerMode,
        ragRetrievalSettings: RAGRetrievalSettings = AppSettingsDefaults.ragRetrievalSettings
    ) {
        self.defaultProviderId = defaultProviderId
        self.defaultAgentRuntimeId = defaultAgentRuntimeId
        self.defaultAgentModelId = defaultAgentModelId
        self.agentModelIds = ["cursor.acp": defaultAgentModelId]
        self.defaultSafetyMode = defaultSafetyMode
        self.mcpServerBasePath = mcpServerBasePath
        self.localLLMEndpoint = localLLMEndpoint
        self.localLLMModel = localLLMModel
        self.defaultMaxInputTokens = defaultMaxInputTokens
        self.defaultMaxOutputTokens = defaultMaxOutputTokens
        self.remoteControlEnabled = remoteControlEnabled
        self.remoteControlAllowLAN = remoteControlAllowLAN
        self.remoteControlPort = remoteControlPort
        self.remoteControlToken = remoteControlToken
        self.ragAnswerMode = ragAnswerMode
        self.ragRetrievalSettings = ragRetrievalSettings
    }

    func agentModelId(for runtimeId: String) -> String? {
        agentModelIds[runtimeId]
    }

    func setAgentModelId(_ modelId: String?, for runtimeId: String) {
        agentModelIds[runtimeId] = modelId
        if runtimeId == "cursor.acp", let modelId {
            defaultAgentModelId = modelId
        }
    }
}
