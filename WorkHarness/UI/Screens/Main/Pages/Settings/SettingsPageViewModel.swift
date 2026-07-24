//
// SettingsPageViewModel.swift
// WorkHarness
//
// Created by Auto (Codex) on 08.07.2026.
//

import AppKit
import Foundation
import Observation

extension MainScreen {
    @MainActor
    @Observable
    final class SettingsPageViewModel {
        private let providerService: ProviderServiceProtocol
        private let appSettingsService: AppSettingsServiceProtocol
        private let agentRuntimeRegistry: AgentRuntimeRegistry
        private let remoteControlService: RemoteControlServiceProtocol?
        private let agentProfileService: AgentProfileServiceProtocol?
        private let testingConfigurationService: TestingConfigurationServiceProtocol?

        private(set) var providers: [ProviderSettingsItem] = []
        private(set) var activeProviderId: String?
        private(set) var activeAgentRuntimeId: String?
        private(set) var agentRuntimes: [AgentRuntimeItem] = []
        private(set) var agentProfiles: [AgentWorkflowProfile] = []
        var selectedAgentProfileId = ""
        private(set) var agentProfileDirectoryPath = SettingsPageDesign.AgentProfiles.noProjectDirectory
        private(set) var smokeScenarios: [SmokeScenario] = []
        private(set) var testingConfigurationDirectoryPath = SettingsPageDesign.Testing.noProjectDirectory
        var testingPlatform: SmokeTestPlatform = .iOSSimulator
        var testingXcodeContainerPath = ""
        var testingScheme = ""
        var testingBundleIdentifier = ""
        var testingDeviceName = ""
        var testingBuildCommand = ""
        var testingCodeTestCommand = ""
        var selectedAgentModelId: String
        private(set) var errorMessage: String?
        var selectedSafetyMode: SafetyMode
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
        var ragChunkingStrategy: RAGChunkingStrategy
        var ragRetrievalMode: RAGRetrievalMode
        var ragRelevanceFilterMode: RAGRelevanceFilterMode
        var ragTopKBeforeFiltering: Int
        var ragTopKAfterFiltering: Int
        var ragSimilarityThreshold: Double
        var isPromptImporterPresented = false
        private(set) var promptImportAssistantId: UUID?
        var isSmokeScenarioImporterPresented = false
        private(set) var smokeScenarioImportId: UUID?
        private var agentProfileRevision = 0
        private var smokeScenarioRevision = 0

        init(
            providerService: ProviderServiceProtocol,
            appSettingsService: AppSettingsServiceProtocol,
            agentRuntimeRegistry: AgentRuntimeRegistry? = nil,
            remoteControlService: RemoteControlServiceProtocol? = nil,
            agentProfileService: AgentProfileServiceProtocol? = nil,
            testingConfigurationService: TestingConfigurationServiceProtocol? = nil
        ) {
            self.providerService = providerService
            self.appSettingsService = appSettingsService
            self.agentRuntimeRegistry = agentRuntimeRegistry ?? AgentRuntimeRegistry()
            self.remoteControlService = remoteControlService
            self.agentProfileService = agentProfileService
            self.testingConfigurationService = testingConfigurationService
            self.selectedAgentModelId = ""
            self.selectedSafetyMode = appSettingsService.defaultSafetyMode
            self.mcpServerBasePath = appSettingsService.mcpServerBasePath
            self.localLLMEndpoint = appSettingsService.localLLMEndpoint
            self.localLLMModel = appSettingsService.localLLMModel
            self.defaultMaxInputTokens = appSettingsService.defaultMaxInputTokens
            self.defaultMaxOutputTokens = appSettingsService.defaultMaxOutputTokens
            self.remoteControlEnabled = appSettingsService.remoteControlEnabled
            self.remoteControlAllowLAN = appSettingsService.remoteControlAllowLAN
            self.remoteControlPort = appSettingsService.remoteControlPort
            self.remoteControlToken = appSettingsService.remoteControlToken
            self.ragAnswerMode = appSettingsService.ragAnswerMode
            self.ragChunkingStrategy = appSettingsService.ragRetrievalSettings.chunkingStrategy
            self.ragRetrievalMode = appSettingsService.ragRetrievalSettings.retrievalMode
            self.ragRelevanceFilterMode = appSettingsService.ragRetrievalSettings.relevanceFilterMode
            self.ragTopKBeforeFiltering = appSettingsService.ragRetrievalSettings.topKBeforeFiltering
            self.ragTopKAfterFiltering = appSettingsService.ragRetrievalSettings.topKAfterFiltering
            self.ragSimilarityThreshold = appSettingsService.ragRetrievalSettings.similarityThreshold
            reloadProviders()
            reloadAgentRuntimes()
            reloadAgentProfiles()
            reloadTestingConfiguration()
        }

        var activeProviderName: String {
            selectedProvider?.name ?? SettingsPageDesign.ProviderFallback.noActiveProvider
        }

        var activeExecutionBackendName: String {
            activeExecutionBackend?.name ?? SettingsPageDesign.ExecutionBackend.noActiveBackend
        }

        var activeExecutionBackendId: String {
            activeExecutionBackend?.id ?? ""
        }

        var executionBackends: [ExecutionBackendItem] {
            let runtimes = agentRuntimes
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                .map { runtime in
                    ExecutionBackendItem(
                        id: ExecutionBackendItem.runtimeId(runtime.id),
                        sourceId: runtime.id,
                        name: runtime.name,
                        kind: .agentRuntime,
                        transport: runtime.transport,
                        availability: runtime.availability,
                        isActive: runtime.id == activeAgentRuntimeId
                    )
                }
            let providerItems = providers.map { provider in
                ExecutionBackendItem(
                    id: ExecutionBackendItem.providerId(provider.id),
                    sourceId: provider.id,
                    name: provider.name,
                    kind: .provider,
                    transport: provider.transport,
                    availability: provider.availability,
                    isActive: activeAgentRuntimeId == nil && provider.id == activeProviderId
                )
            }
            return runtimes + providerItems
        }

        var activeAgentRuntime: AgentRuntimeItem? {
            selectedRuntime
        }

        var hasUnsavedAppSettingsChanges: Bool {
            currentAppSettingsSnapshot != persistedAppSettingsSnapshot
        }

        var appSettingsStatus: String {
            hasUnsavedAppSettingsChanges ? SettingsPageDesign.AppSettings.unsavedStatus : SettingsPageDesign.AppSettings.savedStatus
        }

        var autoApproveWorkspaceActions: Bool {
            get {
                selectedSafetyMode == .autoInsideSandbox
            }
            set {
                selectedSafetyMode = newValue ? .autoInsideSandbox : AppSettingsDefaults.defaultSafetyMode
            }
        }

        var selectedAgentProfile: AgentWorkflowProfile? {
            agentProfiles.first { $0.id == selectedAgentProfileId }
        }

        var hasUnsavedTestingTargetChanges: Bool {
            guard let persistedTarget = testingConfigurationService?.catalog.target else {
                return false
            }
            return currentTestingTarget != persistedTarget
        }

        var testingTargetStatus: String {
            hasUnsavedTestingTargetChanges
                ? SettingsPageDesign.Testing.unsavedStatus
                : SettingsPageDesign.Testing.savedStatus
        }

        func selectAgentProfile(id: String) {
            agentProfileService?.selectProfile(id: id)
            selectedAgentProfileId = agentProfileService?.selectedProfileId ?? id
            errorMessage = nil
        }

        func reloadAgentProfiles() {
            agentProfileService?.reload()
            agentProfiles = agentProfileService?.profiles ?? []
            selectedAgentProfileId = agentProfileService?.selectedProfileId ?? ""
            agentProfileDirectoryPath = agentProfileService?.promptDirectoryPath
                ?? SettingsPageDesign.AgentProfiles.noProjectDirectory
            agentProfileRevision += 1
            errorMessage = nil
        }

        func presentPromptImporter(for assistantId: UUID) {
            promptImportAssistantId = assistantId
            isPromptImporterPresented = true
        }

        func openPrompt(for assistantId: UUID) {
            do {
                guard let fileURL = try agentProfileService?.promptFileURL(for: assistantId) else {
                    throw AgentProfileServiceError.promptFileUnavailable
                }
                guard NSWorkspace.shared.open(fileURL) else {
                    throw AgentProfileServiceError.promptFileUnavailable
                }
                errorMessage = nil
            } catch {
                errorMessage = error.localizedDescription
            }
        }

        func importPrompt(from url: URL) {
            guard let promptImportAssistantId else { return }
            do {
                try agentProfileService?.replacePrompt(
                    for: promptImportAssistantId,
                    withContentsOf: url
                )
                agentProfileRevision += 1
                errorMessage = nil
            } catch {
                errorMessage = error.localizedDescription
            }
            self.promptImportAssistantId = nil
        }

        func setPromptImportError(_ message: String) {
            promptImportAssistantId = nil
            errorMessage = message
        }

        func moveAssistant(id: UUID, direction: AgentProfileMoveDirection) {
            do {
                try agentProfileService?.moveAssistant(id: id, direction: direction)
                agentProfiles = agentProfileService?.profiles ?? agentProfiles
                errorMessage = nil
            } catch {
                errorMessage = error.localizedDescription
            }
        }

        func promptPreview(for assistantId: UUID) -> String {
            _ = agentProfileRevision
            let prompt = agentProfileService?.prompt(for: assistantId)
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !prompt.isEmpty else {
                return SettingsPageDesign.AgentProfiles.promptUnavailable
            }
            return prompt
        }

        func reloadTestingConfiguration() {
            testingConfigurationService?.reload()
            smokeScenarios = testingConfigurationService?.catalog.scenarios ?? []
            testingConfigurationDirectoryPath = testingConfigurationService?.configurationDirectoryPath
                ?? SettingsPageDesign.Testing.noProjectDirectory
            if let target = testingConfigurationService?.catalog.target {
                applyTestingTarget(target)
            }
            smokeScenarioRevision += 1
            errorMessage = nil
        }

        func saveTestingTarget() {
            do {
                try testingConfigurationService?.saveTarget(currentTestingTarget)
                errorMessage = nil
            } catch {
                errorMessage = error.localizedDescription
            }
        }

        func revertTestingTarget() {
            if let target = testingConfigurationService?.catalog.target {
                applyTestingTarget(target)
            }
            errorMessage = nil
        }

        func setSmokeScenarioEnabled(id: UUID, enabled: Bool) {
            do {
                try testingConfigurationService?.setScenarioEnabled(id: id, enabled: enabled)
                smokeScenarios = testingConfigurationService?.catalog.scenarios ?? smokeScenarios
                errorMessage = nil
            } catch {
                errorMessage = error.localizedDescription
            }
        }

        func moveSmokeScenario(id: UUID, direction: SmokeScenarioMoveDirection) {
            do {
                try testingConfigurationService?.moveScenario(id: id, direction: direction)
                smokeScenarios = testingConfigurationService?.catalog.scenarios ?? smokeScenarios
                errorMessage = nil
            } catch {
                errorMessage = error.localizedDescription
            }
        }

        func presentSmokeScenarioImporter(for scenarioId: UUID) {
            smokeScenarioImportId = scenarioId
            isSmokeScenarioImporterPresented = true
        }

        func openSmokeScenario(for scenarioId: UUID) {
            do {
                guard let fileURL = try testingConfigurationService?.scenarioFileURL(
                    for: scenarioId
                ), NSWorkspace.shared.open(fileURL) else {
                    throw TestingConfigurationServiceError.scenarioFileUnavailable
                }
                errorMessage = nil
            } catch {
                errorMessage = error.localizedDescription
            }
        }

        func importSmokeScenario(from url: URL) {
            guard let smokeScenarioImportId else { return }
            do {
                try testingConfigurationService?.replaceScenario(
                    for: smokeScenarioImportId,
                    withContentsOf: url
                )
                smokeScenarioRevision += 1
                errorMessage = nil
            } catch {
                errorMessage = error.localizedDescription
            }
            self.smokeScenarioImportId = nil
        }

        func setSmokeScenarioImportError(_ message: String) {
            smokeScenarioImportId = nil
            errorMessage = message
        }

        func smokeScenarioPreview(for scenarioId: UUID) -> String {
            _ = smokeScenarioRevision
            let prompt = testingConfigurationService?.scenarioPrompt(for: scenarioId)
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !prompt.isEmpty else {
                return SettingsPageDesign.Testing.scenarioUnavailable
            }
            return prompt
        }

        var selectedProvider: ProviderSettingsItem? {
            guard let activeProviderId else { return providers.first }
            return providers.first { $0.id == activeProviderId }
        }

        func reloadProviders() {
            activeProviderId = providerService.activeProviderId
            providers = providerService.availableProviders.map { provider in
                ProviderSettingsItem(
                    id: provider.id,
                    name: provider.displayName,
                    isActive: provider.id == activeProviderId,
                    transport: provider.capabilities.supportsMCP ? SettingsPageDesign.ProviderFallback.mcpBacked : SettingsPageDesign.ProviderFallback.internalProvider,
                    availability: provider.capabilities.supportsLocalExecution ? SettingsPageDesign.ProviderFallback.local : SettingsPageDesign.ProviderFallback.remote,
                    capabilities: capabilityRows(for: provider.capabilities)
                )
            }
        }

        func reloadAgentRuntimes() {
            activeAgentRuntimeId = appSettingsService.defaultAgentRuntimeId
            agentRuntimes = agentRuntimeRegistry.runtimes.map { runtime in
                AgentRuntimeItem(
                    id: runtime.id,
                    name: runtime.displayName,
                    isActive: runtime.id == activeAgentRuntimeId,
                    transport: runtime.descriptor.transport.label,
                    availability: SettingsPageDesign.AgentRuntime.availableStatus,
                    authentication: runtime.descriptor.authentication.label,
                    modelOptions: runtime.descriptor.modelOptions,
                    defaultModelId: runtime.descriptor.defaultModelId,
                    capabilities: runtime.descriptor.capabilities
                )
            }
            loadSelectedAgentModel()
        }

        func selectAgentRuntime(id runtimeId: String?) {
            guard let runtimeId, agentRuntimeRegistry.runtime(id: runtimeId) != nil else {
                appSettingsService.defaultAgentRuntimeId = nil
                activeAgentRuntimeId = nil
                reloadAgentRuntimes()
                return
            }
            appSettingsService.defaultAgentRuntimeId = runtimeId
            activeAgentRuntimeId = runtimeId
            reloadAgentRuntimes()
        }

        func selectProvider(id providerId: String) {
            do {
                try providerService.selectProvider(id: providerId)
                appSettingsService.defaultAgentRuntimeId = nil
                activeAgentRuntimeId = nil
                errorMessage = nil
                reloadProviders()
                reloadAgentRuntimes()
            } catch {
                errorMessage = error.localizedDescription
            }
        }

        func selectExecutionBackend(id backendId: String) {
            guard let backend = executionBackends.first(where: { $0.id == backendId }) else {
                return
            }
            switch backend.kind {
            case .agentRuntime:
                selectAgentRuntime(id: backend.sourceId)
            case .provider:
                selectProvider(id: backend.sourceId)
            }
        }

        func validatedAgentModelId(for runtime: AgentRuntimeItem) -> String {
            normalizedAgentModelId(selectedAgentModelId, for: runtime)
        }

        func saveSettings() {
            appSettingsService.defaultSafetyMode = selectedSafetyMode
            appSettingsService.mcpServerBasePath = mcpServerBasePath
            appSettingsService.localLLMEndpoint = localLLMEndpoint
            appSettingsService.localLLMModel = localLLMModel
            appSettingsService.defaultMaxInputTokens = defaultMaxInputTokens
            appSettingsService.defaultMaxOutputTokens = defaultMaxOutputTokens
            appSettingsService.remoteControlEnabled = remoteControlEnabled
            appSettingsService.remoteControlAllowLAN = remoteControlAllowLAN
            appSettingsService.remoteControlPort = remoteControlPort
            appSettingsService.remoteControlToken = remoteControlToken
            if let activeAgentRuntimeId {
                appSettingsService.setAgentModelId(
                    selectedAgentModelId.isEmpty ? nil : selectedAgentModelId,
                    for: activeAgentRuntimeId
                )
            }
            appSettingsService.ragAnswerMode = ragAnswerMode
            appSettingsService.ragRetrievalSettings = currentRAGRetrievalSettings

            mcpServerBasePath = appSettingsService.mcpServerBasePath
            localLLMEndpoint = appSettingsService.localLLMEndpoint
            localLLMModel = appSettingsService.localLLMModel
            defaultMaxInputTokens = appSettingsService.defaultMaxInputTokens
            defaultMaxOutputTokens = appSettingsService.defaultMaxOutputTokens
            remoteControlEnabled = appSettingsService.remoteControlEnabled
            remoteControlAllowLAN = appSettingsService.remoteControlAllowLAN
            remoteControlPort = appSettingsService.remoteControlPort
            remoteControlToken = appSettingsService.remoteControlToken
            loadSelectedAgentModel()
            loadRAGSettingsFromService()
            errorMessage = nil
            do {
                try remoteControlService?.reload()
            } catch {
                errorMessage = "Remote Control: \(error.localizedDescription)"
            }
        }

        func revertSettings() {
            loadSettingsFromService()
            errorMessage = nil
        }

        func restoreDefaultSettingsDraft() {
            selectedSafetyMode = AppSettingsDefaults.defaultSafetyMode
            mcpServerBasePath = AppSettingsDefaults.mcpServerBasePath
            localLLMEndpoint = AppSettingsDefaults.localLLMEndpoint
            localLLMModel = AppSettingsDefaults.localLLMModel
            defaultMaxInputTokens = AppSettingsDefaults.defaultMaxInputTokens
            defaultMaxOutputTokens = AppSettingsDefaults.defaultMaxOutputTokens
            remoteControlEnabled = AppSettingsDefaults.remoteControlEnabled
            remoteControlAllowLAN = AppSettingsDefaults.remoteControlAllowLAN
            remoteControlPort = AppSettingsDefaults.remoteControlPort
            remoteControlToken = AppSettingsDefaults.remoteControlToken
            selectedAgentModelId = selectedRuntime?.defaultModelId ?? ""
            ragAnswerMode = AppSettingsDefaults.ragAnswerMode
            ragChunkingStrategy = AppSettingsDefaults.ragRetrievalSettings.chunkingStrategy
            ragRetrievalMode = AppSettingsDefaults.ragRetrievalSettings.retrievalMode
            ragRelevanceFilterMode = AppSettingsDefaults.ragRetrievalSettings.relevanceFilterMode
            ragTopKBeforeFiltering = AppSettingsDefaults.ragRetrievalSettings.topKBeforeFiltering
            ragTopKAfterFiltering = AppSettingsDefaults.ragRetrievalSettings.topKAfterFiltering
            ragSimilarityThreshold = AppSettingsDefaults.ragRetrievalSettings.similarityThreshold
            errorMessage = nil
        }

        func resetSettings() {
            restoreDefaultSettingsDraft()
        }

        private func capabilityRows(for capabilities: ProviderCapabilities) -> [ProviderCapabilityRow] {
            [
                .init(title: SettingsPageDesign.Capability.streaming, value: label(for: capabilities.supportsStreaming)),
                .init(title: SettingsPageDesign.Capability.toolCalls, value: label(for: capabilities.supportsToolCalls)),
                .init(title: SettingsPageDesign.Capability.fileEditing, value: label(for: capabilities.supportsFileEditing)),
                .init(title: SettingsPageDesign.Capability.shellExecution, value: label(for: capabilities.supportsShellExecution)),
                .init(title: SettingsPageDesign.Capability.vision, value: label(for: capabilities.supportsVision)),
                .init(title: SettingsPageDesign.Capability.embeddings, value: label(for: capabilities.supportsEmbeddings)),
                .init(title: SettingsPageDesign.Capability.reasoning, value: label(for: capabilities.supportsReasoningMode)),
                .init(title: SettingsPageDesign.Capability.localExecution, value: label(for: capabilities.supportsLocalExecution)),
                .init(title: SettingsPageDesign.Capability.approvals, value: label(for: capabilities.supportsApprovals)),
                .init(title: SettingsPageDesign.Capability.mcp, value: label(for: capabilities.supportsMCP)),
                .init(title: SettingsPageDesign.Capability.contextWindow, value: contextWindowLabel(for: capabilities.contextWindowTokens)),
                .init(title: SettingsPageDesign.Capability.costModel, value: capabilities.costModel ?? SettingsPageDesign.ProviderFallback.notAvailable),
                .init(title: SettingsPageDesign.Capability.models, value: modelsLabel(for: capabilities.supportedModels))
            ]
        }

        private func label(for flag: Bool) -> String {
            flag ? SettingsPageDesign.ProviderFallback.yes : SettingsPageDesign.ProviderFallback.no
        }

        private func contextWindowLabel(for tokenCount: Int?) -> String {
            guard let tokenCount else { return SettingsPageDesign.ProviderFallback.notAvailable }
            return "\(tokenCount) \(SettingsPageDesign.ProviderFallback.tokensSuffix)"
        }

        private func modelsLabel(for models: [String]) -> String {
            models.isEmpty ? SettingsPageDesign.ProviderFallback.notAvailable : models.joined(separator: SettingsPageDesign.ProviderFallback.listSeparator)
        }

        private func loadSettingsFromService() {
            selectedSafetyMode = appSettingsService.defaultSafetyMode
            mcpServerBasePath = appSettingsService.mcpServerBasePath
            localLLMEndpoint = appSettingsService.localLLMEndpoint
            localLLMModel = appSettingsService.localLLMModel
            defaultMaxInputTokens = appSettingsService.defaultMaxInputTokens
            defaultMaxOutputTokens = appSettingsService.defaultMaxOutputTokens
            remoteControlEnabled = appSettingsService.remoteControlEnabled
            remoteControlAllowLAN = appSettingsService.remoteControlAllowLAN
            remoteControlPort = appSettingsService.remoteControlPort
            remoteControlToken = appSettingsService.remoteControlToken
            loadSelectedAgentModel()
            loadRAGSettingsFromService()
        }

        private func loadRAGSettingsFromService() {
            let settings = appSettingsService.ragRetrievalSettings
            ragAnswerMode = appSettingsService.ragAnswerMode
            ragChunkingStrategy = settings.chunkingStrategy
            ragRetrievalMode = settings.retrievalMode
            ragRelevanceFilterMode = settings.relevanceFilterMode
            ragTopKBeforeFiltering = settings.topKBeforeFiltering
            ragTopKAfterFiltering = settings.topKAfterFiltering
            ragSimilarityThreshold = settings.similarityThreshold
        }

        private var currentRAGRetrievalSettings: RAGRetrievalSettings {
            RAGRetrievalSettings(
                chunkingStrategy: ragChunkingStrategy,
                retrievalMode: ragRetrievalMode,
                topKBeforeFiltering: ragTopKBeforeFiltering,
                topKAfterFiltering: ragTopKAfterFiltering,
                similarityThreshold: ragSimilarityThreshold,
                relevanceFilterMode: ragRelevanceFilterMode
            )
        }

        private var currentAppSettingsSnapshot: EditableAppSettingsSnapshot {
            EditableAppSettingsSnapshot(
                safetyMode: selectedSafetyMode,
                mcpServerBasePath: mcpServerBasePath,
                localLLMEndpoint: localLLMEndpoint,
                localLLMModel: localLLMModel,
                defaultMaxInputTokens: defaultMaxInputTokens,
                defaultMaxOutputTokens: defaultMaxOutputTokens,
                remoteControlEnabled: remoteControlEnabled,
                remoteControlAllowLAN: remoteControlAllowLAN,
                remoteControlPort: remoteControlPort,
                remoteControlToken: remoteControlToken,
                agentModelId: selectedAgentModelId,
                ragAnswerMode: ragAnswerMode,
                ragRetrievalSettings: currentRAGRetrievalSettings
            )
        }

        private var persistedAppSettingsSnapshot: EditableAppSettingsSnapshot {
            EditableAppSettingsSnapshot(
                safetyMode: appSettingsService.defaultSafetyMode,
                mcpServerBasePath: appSettingsService.mcpServerBasePath,
                localLLMEndpoint: appSettingsService.localLLMEndpoint,
                localLLMModel: appSettingsService.localLLMModel,
                defaultMaxInputTokens: appSettingsService.defaultMaxInputTokens,
                defaultMaxOutputTokens: appSettingsService.defaultMaxOutputTokens,
                remoteControlEnabled: appSettingsService.remoteControlEnabled,
                remoteControlAllowLAN: appSettingsService.remoteControlAllowLAN,
                remoteControlPort: appSettingsService.remoteControlPort,
                remoteControlToken: appSettingsService.remoteControlToken,
                agentModelId: persistedAgentModelId,
                ragAnswerMode: appSettingsService.ragAnswerMode,
                ragRetrievalSettings: appSettingsService.ragRetrievalSettings
            )
        }

        private var selectedRuntime: AgentRuntimeItem? {
            guard let activeAgentRuntimeId else { return nil }
            return agentRuntimes.first { $0.id == activeAgentRuntimeId }
        }

        private var activeExecutionBackend: ExecutionBackendItem? {
            if let activeAgentRuntimeId {
                return executionBackends.first {
                    $0.kind == .agentRuntime && $0.sourceId == activeAgentRuntimeId
                }
            }
            return executionBackends.first {
                $0.kind == .provider && $0.sourceId == activeProviderId
            }
        }

        private var persistedAgentModelId: String {
            guard let activeAgentRuntimeId else { return "" }
            return appSettingsService.agentModelId(for: activeAgentRuntimeId)
                ?? selectedRuntime?.defaultModelId
                ?? ""
        }

        private func loadSelectedAgentModel() {
            guard let selectedRuntime else {
                selectedAgentModelId = ""
                return
            }
            selectedAgentModelId = normalizedAgentModelId(persistedAgentModelId, for: selectedRuntime)
        }

        private func normalizedAgentModelId(
            _ candidate: String,
            for runtime: AgentRuntimeItem
        ) -> String {
            if runtime.modelOptions.contains(where: { $0.id == candidate }) {
                return candidate
            }
            if let defaultModelId = runtime.defaultModelId,
               runtime.modelOptions.contains(where: { $0.id == defaultModelId }) {
                return defaultModelId
            }
            return runtime.modelOptions.first?.id ?? ""
        }

        private var currentTestingTarget: TestingTargetConfiguration {
            TestingTargetConfiguration(
                platform: testingPlatform,
                xcodeContainerPath: testingXcodeContainerPath,
                scheme: testingScheme,
                bundleIdentifier: testingBundleIdentifier,
                deviceName: testingDeviceName,
                buildCommand: testingBuildCommand,
                codeTestCommand: testingCodeTestCommand
            )
        }

        private func applyTestingTarget(_ target: TestingTargetConfiguration) {
            testingPlatform = target.platform
            testingXcodeContainerPath = target.xcodeContainerPath
            testingScheme = target.scheme
            testingBundleIdentifier = target.bundleIdentifier
            testingDeviceName = target.deviceName
            testingBuildCommand = target.buildCommand
            testingCodeTestCommand = target.codeTestCommand
        }
    }

    private struct EditableAppSettingsSnapshot: Equatable {
        var safetyMode: SafetyMode
        var mcpServerBasePath: String
        var localLLMEndpoint: String
        var localLLMModel: String
        var defaultMaxInputTokens: Int
        var defaultMaxOutputTokens: Int
        var remoteControlEnabled: Bool
        var remoteControlAllowLAN: Bool
        var remoteControlPort: Int
        var remoteControlToken: String
        var agentModelId: String
        var ragAnswerMode: RAGAnswerMode
        var ragRetrievalSettings: RAGRetrievalSettings
    }

    struct ProviderSettingsItem: Identifiable, Equatable {
        var id: String
        var name: String
        var isActive: Bool
        var transport: String
        var availability: String
        var capabilities: [ProviderCapabilityRow]
    }

    struct AgentRuntimeItem: Identifiable, Equatable {
        var id: String
        var name: String
        var isActive: Bool
        var transport: String
        var availability: String
        var authentication: String
        var modelOptions: [AgentRuntimeModelOption]
        var defaultModelId: String?
        var capabilities: AgentCapabilities
    }

    struct ExecutionBackendItem: Identifiable, Equatable {
        enum Kind: Equatable {
            case agentRuntime
            case provider
        }

        var id: String
        var sourceId: String
        var name: String
        var kind: Kind
        var transport: String
        var availability: String
        var isActive: Bool

        static func runtimeId(_ sourceId: String) -> String {
            "runtime:\(sourceId)"
        }

        static func providerId(_ sourceId: String) -> String {
            "provider:\(sourceId)"
        }
    }

    struct ProviderCapabilityRow: Identifiable, Equatable {
        var id: String { title }
        var title: String
        var value: String
    }
}
