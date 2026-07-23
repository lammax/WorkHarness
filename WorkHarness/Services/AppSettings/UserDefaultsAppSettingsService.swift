//
// UserDefaultsAppSettingsService.swift
// WorkHarness
//
// Created by Auto (Codex) on 08.07.2026.
//

import Foundation

@MainActor
final class UserDefaultsAppSettingsService: AppSettingsServiceProtocol {
    private enum Key {
        static let defaultProviderId = "appSettings.defaultProviderId"
        static let defaultAgentRuntimeId = "appSettings.defaultAgentRuntimeId"
        static let defaultAgentModelId = "appSettings.defaultAgentModelId"
        static let agentModelIds = "appSettings.agentModelIds"
        static let defaultSafetyMode = "appSettings.defaultSafetyMode"
        static let mcpServerBasePath = "appSettings.mcpServerBasePath"
        static let localLLMEndpoint = "appSettings.localLLMEndpoint"
        static let localLLMModel = "appSettings.localLLMModel"
        static let defaultMaxInputTokens = "appSettings.defaultMaxInputTokens"
        static let defaultMaxOutputTokens = "appSettings.defaultMaxOutputTokens"
        static let remoteControlEnabled = "appSettings.remoteControlEnabled"
        static let remoteControlAllowLAN = "appSettings.remoteControlAllowLAN"
        static let remoteControlPort = "appSettings.remoteControlPort"
        static let remoteControlToken = "appSettings.remoteControlToken"
        static let ragAnswerMode = "appSettings.ragAnswerMode"
        static let ragRetrievalSettings = "appSettings.ragRetrievalSettings"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var defaultProviderId: String? {
        get {
            defaults.string(forKey: Key.defaultProviderId)
        }
        set {
            if let newValue {
                defaults.set(newValue, forKey: Key.defaultProviderId)
            } else {
                defaults.removeObject(forKey: Key.defaultProviderId)
            }
        }
    }

    var defaultAgentRuntimeId: String? {
        get { defaults.string(forKey: Key.defaultAgentRuntimeId) }
        set {
            if let newValue {
                defaults.set(newValue, forKey: Key.defaultAgentRuntimeId)
            } else {
                defaults.removeObject(forKey: Key.defaultAgentRuntimeId)
            }
        }
    }

    var defaultAgentModelId: String {
        get { defaults.string(forKey: Key.defaultAgentModelId) ?? AppSettingsDefaults.defaultAgentModelId }
        set { defaults.set(newValue, forKey: Key.defaultAgentModelId) }
    }

    var defaultSafetyMode: SafetyMode {
        get {
            guard let rawValue = defaults.string(forKey: Key.defaultSafetyMode),
                  let mode = SafetyMode(rawValue: rawValue) else {
                return AppSettingsDefaults.defaultSafetyMode
            }
            return mode
        }
        set {
            defaults.set(newValue.rawValue, forKey: Key.defaultSafetyMode)
        }
    }

    var mcpServerBasePath: String {
        get {
            stringValue(forKey: Key.mcpServerBasePath, defaultValue: AppSettingsDefaults.mcpServerBasePath)
        }
        set {
            setTrimmedString(newValue, key: Key.mcpServerBasePath, defaultValue: AppSettingsDefaults.mcpServerBasePath)
        }
    }

    var localLLMEndpoint: String {
        get {
            stringValue(forKey: Key.localLLMEndpoint, defaultValue: AppSettingsDefaults.localLLMEndpoint)
        }
        set {
            setTrimmedString(newValue, key: Key.localLLMEndpoint, defaultValue: AppSettingsDefaults.localLLMEndpoint)
        }
    }

    var localLLMModel: String {
        get {
            stringValue(forKey: Key.localLLMModel, defaultValue: AppSettingsDefaults.localLLMModel)
        }
        set {
            setTrimmedString(newValue, key: Key.localLLMModel, defaultValue: AppSettingsDefaults.localLLMModel)
        }
    }

    var defaultMaxInputTokens: Int {
        get {
            positiveIntValue(forKey: Key.defaultMaxInputTokens, defaultValue: AppSettingsDefaults.defaultMaxInputTokens)
        }
        set {
            setPositiveInt(newValue, key: Key.defaultMaxInputTokens, defaultValue: AppSettingsDefaults.defaultMaxInputTokens)
        }
    }

    var defaultMaxOutputTokens: Int {
        get {
            positiveIntValue(forKey: Key.defaultMaxOutputTokens, defaultValue: AppSettingsDefaults.defaultMaxOutputTokens)
        }
        set {
            setPositiveInt(newValue, key: Key.defaultMaxOutputTokens, defaultValue: AppSettingsDefaults.defaultMaxOutputTokens)
        }
    }

    var remoteControlEnabled: Bool {
        get { defaults.object(forKey: Key.remoteControlEnabled) as? Bool ?? AppSettingsDefaults.remoteControlEnabled }
        set { defaults.set(newValue, forKey: Key.remoteControlEnabled) }
    }

    var remoteControlAllowLAN: Bool {
        get { defaults.object(forKey: Key.remoteControlAllowLAN) as? Bool ?? AppSettingsDefaults.remoteControlAllowLAN }
        set { defaults.set(newValue, forKey: Key.remoteControlAllowLAN) }
    }

    var remoteControlPort: Int {
        get { positiveIntValue(forKey: Key.remoteControlPort, defaultValue: AppSettingsDefaults.remoteControlPort) }
        set { setPositiveInt(newValue, key: Key.remoteControlPort, defaultValue: AppSettingsDefaults.remoteControlPort) }
    }

    var remoteControlToken: String {
        get { defaults.string(forKey: Key.remoteControlToken) ?? AppSettingsDefaults.remoteControlToken }
        set { defaults.set(newValue.trimmingCharacters(in: .whitespacesAndNewlines), forKey: Key.remoteControlToken) }
    }

    var ragAnswerMode: RAGAnswerMode {
        get {
            guard let rawValue = defaults.string(forKey: Key.ragAnswerMode),
                  let value = RAGAnswerMode(rawValue: rawValue) else {
                return AppSettingsDefaults.ragAnswerMode
            }
            return value
        }
        set {
            defaults.set(newValue.rawValue, forKey: Key.ragAnswerMode)
        }
    }

    var ragRetrievalSettings: RAGRetrievalSettings {
        get {
            guard let data = defaults.data(forKey: Key.ragRetrievalSettings),
                  let value = try? JSONDecoder().decode(RAGRetrievalSettings.self, from: data) else {
                return AppSettingsDefaults.ragRetrievalSettings
            }
            return value
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue) else { return }
            defaults.set(data, forKey: Key.ragRetrievalSettings)
        }
    }

    func agentModelId(for runtimeId: String) -> String? {
        if let value = agentModelIds[runtimeId] {
            return value
        }
        return runtimeId == "cursor.acp" ? defaultAgentModelId : nil
    }

    func setAgentModelId(_ modelId: String?, for runtimeId: String) {
        var values = agentModelIds
        values[runtimeId] = modelId
        agentModelIds = values
        if runtimeId == "cursor.acp", let modelId {
            defaultAgentModelId = modelId
        }
    }

    private var agentModelIds: [String: String] {
        get {
            guard let data = defaults.data(forKey: Key.agentModelIds),
                  let values = try? JSONDecoder().decode([String: String].self, from: data) else {
                return [:]
            }
            return values
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue) else { return }
            defaults.set(data, forKey: Key.agentModelIds)
        }
    }

    private func stringValue(forKey key: String, defaultValue: String) -> String {
        guard let value = defaults.string(forKey: key),
              !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return defaultValue
        }
        return value
    }

    private func setTrimmedString(_ value: String, key: String, defaultValue: String) {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        defaults.set(trimmedValue.isEmpty ? defaultValue : trimmedValue, forKey: key)
    }

    private func positiveIntValue(forKey key: String, defaultValue: Int) -> Int {
        let value = defaults.integer(forKey: key)
        return value > 0 ? value : defaultValue
    }

    private func setPositiveInt(_ value: Int, key: String, defaultValue: Int) {
        defaults.set(value > 0 ? value : defaultValue, forKey: key)
    }
}
