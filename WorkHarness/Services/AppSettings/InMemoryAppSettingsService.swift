//
// InMemoryAppSettingsService.swift
// WorkHarness
//
// Created by Auto (Codex) on 08.07.2026.
//

@MainActor
final class InMemoryAppSettingsService: AppSettingsServiceProtocol {
    var defaultProviderId: String?
    var defaultSafetyMode: SafetyMode
    var mcpServerBasePath: String
    var localLLMEndpoint: String
    var localLLMModel: String
    var defaultMaxInputTokens: Int
    var defaultMaxOutputTokens: Int

    init(
        defaultProviderId: String? = nil,
        defaultSafetyMode: SafetyMode = AppSettingsDefaults.defaultSafetyMode,
        mcpServerBasePath: String = AppSettingsDefaults.mcpServerBasePath,
        localLLMEndpoint: String = AppSettingsDefaults.localLLMEndpoint,
        localLLMModel: String = AppSettingsDefaults.localLLMModel,
        defaultMaxInputTokens: Int = AppSettingsDefaults.defaultMaxInputTokens,
        defaultMaxOutputTokens: Int = AppSettingsDefaults.defaultMaxOutputTokens
    ) {
        self.defaultProviderId = defaultProviderId
        self.defaultSafetyMode = defaultSafetyMode
        self.mcpServerBasePath = mcpServerBasePath
        self.localLLMEndpoint = localLLMEndpoint
        self.localLLMModel = localLLMModel
        self.defaultMaxInputTokens = defaultMaxInputTokens
        self.defaultMaxOutputTokens = defaultMaxOutputTokens
    }
}
