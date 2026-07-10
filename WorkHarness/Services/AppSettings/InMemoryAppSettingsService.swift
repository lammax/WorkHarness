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
    var ragAnswerMode: RAGAnswerMode
    var ragRetrievalSettings: RAGRetrievalSettings

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
        ragAnswerMode: RAGAnswerMode = AppSettingsDefaults.ragAnswerMode,
        ragRetrievalSettings: RAGRetrievalSettings = AppSettingsDefaults.ragRetrievalSettings
    ) {
        self.defaultProviderId = defaultProviderId
        self.defaultAgentRuntimeId = defaultAgentRuntimeId
        self.defaultAgentModelId = defaultAgentModelId
        self.defaultSafetyMode = defaultSafetyMode
        self.mcpServerBasePath = mcpServerBasePath
        self.localLLMEndpoint = localLLMEndpoint
        self.localLLMModel = localLLMModel
        self.defaultMaxInputTokens = defaultMaxInputTokens
        self.defaultMaxOutputTokens = defaultMaxOutputTokens
        self.ragAnswerMode = ragAnswerMode
        self.ragRetrievalSettings = ragRetrievalSettings
    }
}
