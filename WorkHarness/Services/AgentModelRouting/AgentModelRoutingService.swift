//
// AgentModelRoutingService.swift
// WorkHarness
//
// Created by Auto (Codex) on 29.07.2026.
//

import Foundation

@MainActor
final class AgentModelRoutingService: AgentModelRoutingServiceProtocol {
    private let appSettingsService: AppSettingsServiceProtocol

    init(appSettingsService: AppSettingsServiceProtocol) {
        self.appSettingsService = appSettingsService
    }

    func decision(
        for prompt: String,
        runtime: AgentRuntimeDescriptor,
        manualModelId: String?
    ) -> AgentModelRoutingDecision {
        let promptLength = prompt.count
        guard let descriptor = runtime.modelRouting else {
            return manualDecision(modelId: manualModelId, promptLength: promptLength)
        }

        let settings = normalizedSettings(
            appSettingsService.agentModelRoutingSettings(for: runtime.id),
            descriptor: descriptor,
            availableModels: runtime.modelOptions
        )
        guard settings.isEnabled else {
            return manualDecision(modelId: manualModelId, promptLength: promptLength)
        }

        if promptLength > settings.promptLengthThreshold {
            return fallbackDecision(
                settings: settings,
                reason: "prompt_length",
                promptLength: promptLength
            )
        }

        let normalizedPrompt = prompt.lowercased()
        if let keyword = descriptor.fallbackKeywords.first(where: normalizedPrompt.contains) {
            return fallbackDecision(
                settings: settings,
                reason: "critical_keyword",
                promptLength: promptLength,
                matchedKeyword: keyword
            )
        }

        if requirementCount(in: prompt) >= descriptor.multipleRequirementsThreshold {
            return fallbackDecision(
                settings: settings,
                reason: "multiple_requirements",
                promptLength: promptLength
            )
        }

        return AgentModelRoutingDecision(
            selectedModelId: settings.fastModelId,
            route: .fast,
            reason: "short_simple_prompt",
            promptLength: promptLength,
            promptLengthThreshold: settings.promptLengthThreshold,
            matchedKeyword: nil
        )
    }

    func fallbackDecision(
        afterRuntimeFailureFor prompt: String,
        runtime: AgentRuntimeDescriptor,
        failedModelId: String?
    ) -> AgentModelRoutingDecision? {
        guard let descriptor = runtime.modelRouting else { return nil }
        let settings = normalizedSettings(
            appSettingsService.agentModelRoutingSettings(for: runtime.id),
            descriptor: descriptor,
            availableModels: runtime.modelOptions
        )
        guard settings.isEnabled,
              failedModelId == settings.fastModelId,
              settings.fastModelId != settings.fallbackModelId else {
            return nil
        }
        return fallbackDecision(
            settings: settings,
            reason: "fast_model_runtime_failure",
            promptLength: prompt.count
        )
    }

    private func normalizedSettings(
        _ savedSettings: AgentModelRoutingSettings?,
        descriptor: AgentModelRoutingDescriptor,
        availableModels: [AgentRuntimeModelOption]
    ) -> AgentModelRoutingSettings {
        let availableModelIds = Set(availableModels.map(\.id))
        let candidate = savedSettings ?? AgentModelRoutingSettings(
            isEnabled: AppSettingsDefaults.agentModelRoutingEnabled,
            fastModelId: descriptor.defaultFastModelId,
            fallbackModelId: descriptor.defaultFallbackModelId,
            promptLengthThreshold: descriptor.defaultPromptLengthThreshold
        )
        return AgentModelRoutingSettings(
            isEnabled: candidate.isEnabled,
            fastModelId: availableModelIds.contains(candidate.fastModelId)
                ? candidate.fastModelId
                : descriptor.defaultFastModelId,
            fallbackModelId: availableModelIds.contains(candidate.fallbackModelId)
                ? candidate.fallbackModelId
                : descriptor.defaultFallbackModelId,
            promptLengthThreshold: max(1, candidate.promptLengthThreshold)
        )
    }

    private func manualDecision(
        modelId: String?,
        promptLength: Int
    ) -> AgentModelRoutingDecision {
        AgentModelRoutingDecision(
            selectedModelId: modelId,
            route: .manual,
            reason: "routing_disabled",
            promptLength: promptLength,
            promptLengthThreshold: nil,
            matchedKeyword: nil
        )
    }

    private func fallbackDecision(
        settings: AgentModelRoutingSettings,
        reason: String,
        promptLength: Int,
        matchedKeyword: String? = nil
    ) -> AgentModelRoutingDecision {
        AgentModelRoutingDecision(
            selectedModelId: settings.fallbackModelId,
            route: .fallback,
            reason: reason,
            promptLength: promptLength,
            promptLengthThreshold: settings.promptLengthThreshold,
            matchedKeyword: matchedKeyword
        )
    }

    private func requirementCount(in prompt: String) -> Int {
        prompt.split(whereSeparator: \.isNewline).reduce(into: 0) { count, line in
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            if trimmedLine.hasPrefix("-")
                || trimmedLine.hasPrefix("•")
                || trimmedLine.range(of: #"^\d+[\.\)]\s"#, options: .regularExpression) != nil {
                count += 1
            }
        }
    }
}
