//
// AppSettingsServiceProtocol.swift
// WorkHarness
//
// Created by Auto (Codex) on 08.07.2026.
//

@MainActor
protocol AppSettingsServiceProtocol: BaseServiceProtocol {
    var defaultProviderId: String? { get set }
    var defaultSafetyMode: SafetyMode { get set }
    var mcpServerBasePath: String { get set }
    var localLLMEndpoint: String { get set }
    var localLLMModel: String { get set }
    var defaultMaxInputTokens: Int { get set }
    var defaultMaxOutputTokens: Int { get set }
}

extension AppSettingsServiceProtocol {
    var service: AppService { .appSettings }
}

enum AppSettingsDefaults {
    static let defaultSafetyMode: SafetyMode = .askBeforeWrite
    static let mcpServerBasePath = MCPProviderConfiguration.defaultServerBasePath
    static let localLLMEndpoint = "http://127.0.0.1:3007/mcp"
    static let localLLMModel = "local-private"
    static let defaultMaxInputTokens = 16_000
    static let defaultMaxOutputTokens = 2_000
}
