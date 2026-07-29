//
// AppSettingsServiceProtocol.swift
// WorkHarness
//
// Created by Auto (Codex) on 08.07.2026.
//

@MainActor
protocol AppSettingsServiceProtocol: BaseServiceProtocol {
    var defaultProviderId: String? { get set }
    var defaultAgentRuntimeId: String? { get set }
    var defaultAgentModelId: String { get set }
    var defaultSafetyMode: SafetyMode { get set }
    var mcpServerBasePath: String { get set }
    var localLLMEndpoint: String { get set }
    var localLLMModel: String { get set }
    var defaultMaxInputTokens: Int { get set }
    var defaultMaxOutputTokens: Int { get set }
    var remoteControlEnabled: Bool { get set }
    var remoteControlAllowLAN: Bool { get set }
    var remoteControlPort: Int { get set }
    var remoteControlToken: String { get set }
    var ragAnswerMode: RAGAnswerMode { get set }
    var ragRetrievalSettings: RAGRetrievalSettings { get set }

    func agentModelId(for runtimeId: String) -> String?
    func setAgentModelId(_ modelId: String?, for runtimeId: String)
    func agentModelRoutingSettings(for runtimeId: String) -> AgentModelRoutingSettings?
    func setAgentModelRoutingSettings(
        _ settings: AgentModelRoutingSettings?,
        for runtimeId: String
    )
}

extension AppSettingsServiceProtocol {
    var service: AppService { .appSettings }
}

enum AppSettingsDefaults {
    nonisolated static let defaultSafetyMode: SafetyMode = .askBeforeWrite
    nonisolated static let defaultAgentModelId = "gpt-5.4-nano[reasoning=medium]"
    nonisolated static let agentModelRoutingEnabled = false
    nonisolated static let agentModelRoutingPromptLengthThreshold = 240
    nonisolated static let mcpServerBasePath = "/Users/lammax/Documents/ThisIsMy/Programming/AI/MCP_server"
    nonisolated static let localLLMEndpoint = "http://127.0.0.1:3007/mcp"
    nonisolated static let localLLMModel = "qwen2.5-coder:1.5b"
    nonisolated static let defaultMaxInputTokens = 16_000
    nonisolated static let defaultMaxOutputTokens = 2_000
    nonisolated static let remoteControlEnabled = true
    nonisolated static let remoteControlAllowLAN = false
    nonisolated static let remoteControlPort = 8787
    nonisolated static let remoteControlToken = ""
    nonisolated static let ragAnswerMode: RAGAnswerMode = .disabled
    nonisolated static let ragRetrievalSettings = RAGRetrievalSettings()
}
