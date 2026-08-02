//
// SettingsPageViewModel.swift
// WorkHarness
//
// Created by Auto (Codex) on 08.07.2026.
//

import AppKit
import Foundation
import Observation
import RemoteModels

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
        private let testingEnvironmentService: TestingEnvironmentServiceProtocol?
        private let smokeTestService: SmokeTestServiceProtocol?

        private(set) var providers: [ProviderSettingsItem] = []
        private(set) var activeProviderId: String?
        private(set) var activeAgentRuntimeId: String?
        private(set) var agentRuntimes: [AgentRuntimeItem] = []
        private(set) var agentProfiles: [AgentWorkflowProfile] = []
        var selectedAgentProfileId = ""
        var isInferenceConfigurationSelected = false
        private(set) var agentProfileDirectoryPath = SettingsPageDesign.AgentProfiles.noProjectDirectory
        private(set) var smokeScenarios: [SmokeScenario] = []
        private(set) var testingConfigurationDirectoryPath = SettingsPageDesign.Testing.noProjectDirectory
        private(set) var testingEnvironmentDiagnostics: TestingEnvironmentDiagnostics?
        private(set) var isCheckingTestingEnvironment = false
        private(set) var isRunningSmokeTests = false
        private(set) var lastSmokeRunId: UUID?
        var testingPlatform: SmokeTestPlatform = .iOSSimulator
        var testingXcodeContainerPath = ""
        var testingScheme = ""
        var testingBundleIdentifier = ""
        var testingDeviceName = ""
        var testingBuildCommand = ""
        var testingCodeTestCommand = ""
        var selectedAgentModelId: String
        var agentModelRoutingEnabled = AppSettingsDefaults.agentModelRoutingEnabled
        var agentModelRoutingFastModelId = ""
        var agentModelRoutingFallbackModelId = ""
        var agentModelRoutingPromptLengthThreshold =
            AppSettingsDefaults.agentModelRoutingPromptLengthThreshold
        private(set) var errorMessage: String?
        private(set) var executionBackendNotice: String?
        var selectedSafetyMode: SafetyMode
        var mcpServerBasePath: String
        var localLLMEndpoint: String
        var localLLMModel: String
        private(set) var localLLMModels: [LocalLLMModelOption] = []
        private(set) var isLoadingLocalLLMModels = false
        private(set) var localLLMModelStatus = SettingsPageDesign.LocalLLM.modelsNotLoaded
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
        private var persistedLocalLLMSettingsSnapshot: LocalLLMSettingsSnapshot

        init(
            providerService: ProviderServiceProtocol,
            appSettingsService: AppSettingsServiceProtocol,
            agentRuntimeRegistry: AgentRuntimeRegistry? = nil,
            remoteControlService: RemoteControlServiceProtocol? = nil,
            agentProfileService: AgentProfileServiceProtocol? = nil,
            testingConfigurationService: TestingConfigurationServiceProtocol? = nil,
            testingEnvironmentService: TestingEnvironmentServiceProtocol? = nil,
            smokeTestService: SmokeTestServiceProtocol? = nil
        ) {
            self.providerService = providerService
            self.appSettingsService = appSettingsService
            self.agentRuntimeRegistry = agentRuntimeRegistry ?? AgentRuntimeRegistry()
            self.remoteControlService = remoteControlService
            self.agentProfileService = agentProfileService
            self.testingConfigurationService = testingConfigurationService
            self.testingEnvironmentService = testingEnvironmentService
            self.smokeTestService = smokeTestService
            self.selectedAgentModelId = ""
            self.selectedSafetyMode = appSettingsService.defaultSafetyMode
            self.mcpServerBasePath = appSettingsService.mcpServerBasePath
            self.localLLMEndpoint = appSettingsService.localLLMEndpoint
            self.localLLMModel = appSettingsService.localLLMModel
            self.persistedLocalLLMSettingsSnapshot = LocalLLMSettingsSnapshot(
                endpoint: appSettingsService.localLLMEndpoint,
                model: appSettingsService.localLLMModel
            )
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

        var localLLMModelOptions: [LocalLLMModelOption] {
            if localLLMModels.contains(where: { $0.id == localLLMModel }) {
                return localLLMModels
            }
            return [
                LocalLLMModelOption(
                    id: localLLMModel,
                    displayName: localLLMModel,
                    provider: SettingsPageDesign.LocalLLM.configuredModelProvider,
                    contextWindowTokens: defaultMaxInputTokens,
                    maxOutputTokens: defaultMaxOutputTokens,
                    supportsStreaming: false
                )
            ] + localLLMModels
        }

        var hasUnsavedAppSettingsChanges: Bool {
            currentAppSettingsSnapshot != persistedAppSettingsSnapshot
        }

        var hasUnsavedAgentModelChanges: Bool {
            currentAgentModelSettingsSnapshot != persistedAgentModelSettingsSnapshot
        }

        var appSettingsStatus: String {
            hasUnsavedAppSettingsChanges ? SettingsPageDesign.AppSettings.unsavedStatus : SettingsPageDesign.AppSettings.savedStatus
        }

        var remoteControlStatus: String {
            guard let remoteControlService else {
                return SettingsPageDesign.AppSettings.remoteControlUnavailableStatus
            }
            switch remoteControlService.state {
            case .disabled:
                return SettingsPageDesign.AppSettings.remoteControlDisabledStatus
            case .starting:
                return SettingsPageDesign.AppSettings.remoteControlStartingStatus
            case .running:
                return SettingsPageDesign.AppSettings.remoteControlRunningStatus
            case .stopping:
                return SettingsPageDesign.AppSettings.remoteControlStoppingStatus
            case .failed:
                return SettingsPageDesign.AppSettings.remoteControlFailedStatus
            default:
                return remoteControlService.state.rawValue
            }
        }

        var remoteControlStatusDetail: String {
            if let lastErrorMessage = remoteControlService?.lastErrorMessage,
               !lastErrorMessage.isEmpty {
                return lastErrorMessage
            }
            return "http://127.0.0.1:\(remoteControlPort)/api/v1/status"
        }

        var hasUnsavedLocalLLMChanges: Bool {
            currentLocalLLMSettingsSnapshot != persistedLocalLLMSettingsSnapshot
        }

        var localLLMSettingsStatus: String {
            hasUnsavedLocalLLMChanges
                ? SettingsPageDesign.LocalLLM.unsavedStatus
                : SettingsPageDesign.LocalLLM.savedStatus
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

        var selectedAgentProfileConfigurationId: String {
            isInferenceConfigurationSelected
                ? StandardAgentDefaults.inferenceConfigurationId
                : selectedAgentProfileId
        }

        var selectedWorkflowAssistants: [AgentProfileAssistant] {
            selectedAgentProfile?.assistants.filter {
                !StandardAgentDefaults.isInferenceRole(id: $0.id)
            } ?? []
        }

        var inferenceAssistants: [AgentProfileAssistant] {
            var seenIds: Set<UUID> = []
            return agentProfiles
                .flatMap(\.assistants)
                .filter { assistant in
                    StandardAgentDefaults.isInferenceRole(id: assistant.id)
                        && seenIds.insert(assistant.id).inserted
                }
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

        var testingEnvironmentStatus: String {
            guard let testingEnvironmentDiagnostics else {
                return SettingsPageDesign.Testing.diagnosticsNotChecked
            }
            return testingEnvironmentDiagnostics.canStartSmokeTests
                ? SettingsPageDesign.Testing.diagnosticsReady
                : SettingsPageDesign.Testing.diagnosticsNeedsAttention
        }

        var canRunSmokeTests: Bool {
            smokeTestService != nil
                && !isRunningSmokeTests
                && !hasUnsavedTestingTargetChanges
                && smokeScenarios.contains(where: \.enabled)
                && testingEnvironmentDiagnostics?.canStartSmokeTests == true
        }

        var smokeTestStatus: String {
            if isRunningSmokeTests {
                return SettingsPageDesign.Testing.smokeRunningStatus
            }
            if let lastSmokeRunId {
                return "\(SettingsPageDesign.Testing.smokeFinishedStatus) \(lastSmokeRunId.uuidString)"
            }
            return canRunSmokeTests
                ? SettingsPageDesign.Testing.smokeReadyStatus
                : SettingsPageDesign.Testing.smokeNotReadyStatus
        }

        func selectAgentProfile(id: String) {
            agentProfileService?.selectProfile(id: id)
            selectedAgentProfileId = agentProfileService?.selectedProfileId ?? id
            isInferenceConfigurationSelected = false
            errorMessage = nil
        }

        func selectAgentProfileConfiguration(id: String) {
            if id == StandardAgentDefaults.inferenceConfigurationId {
                isInferenceConfigurationSelected = true
                errorMessage = nil
            } else {
                selectAgentProfile(id: id)
            }
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

        func checkTestingEnvironment() {
            guard !isCheckingTestingEnvironment,
                  let testingEnvironmentService else { return }
            isCheckingTestingEnvironment = true
            errorMessage = nil

            Task {
                do {
                    testingEnvironmentDiagnostics = try await testingEnvironmentService
                        .checkEnvironment()
                } catch {
                    testingEnvironmentDiagnostics = nil
                    errorMessage = error.localizedDescription
                }
                isCheckingTestingEnvironment = false
            }
        }

        func runSmokeTests() {
            guard canRunSmokeTests, let smokeTestService else { return }
            isRunningSmokeTests = true
            lastSmokeRunId = nil
            errorMessage = nil

            Task {
                do {
                    lastSmokeRunId = try await smokeTestService.startEnabledScenarios()
                } catch {
                    errorMessage = error.localizedDescription
                }
                isRunningSmokeTests = false
            }
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
                    modelRouting: runtime.descriptor.modelRouting,
                    capabilities: runtime.descriptor.capabilities
                )
            }
            loadSelectedAgentModel()
        }

        func selectAgentRuntime(id runtimeId: String?) {
            let previousRuntimeId = activeAgentRuntimeId
            guard let runtimeId, agentRuntimeRegistry.runtime(id: runtimeId) != nil else {
                appSettingsService.defaultAgentRuntimeId = nil
                activeAgentRuntimeId = nil
                reloadAgentRuntimes()
                if previousRuntimeId != nil {
                    executionBackendNotice = SettingsPageDesign.ExecutionBackend.nextRunNotice
                }
                return
            }
            appSettingsService.defaultAgentRuntimeId = runtimeId
            activeAgentRuntimeId = runtimeId
            reloadAgentRuntimes()
            if previousRuntimeId != runtimeId {
                executionBackendNotice = SettingsPageDesign.ExecutionBackend.nextRunNotice
            }
        }

        func selectProvider(id providerId: String) {
            let previousBackendId = activeExecutionBackend?.id
            do {
                try providerService.selectProvider(id: providerId)
                appSettingsService.defaultAgentRuntimeId = nil
                activeAgentRuntimeId = nil
                errorMessage = nil
                reloadProviders()
                reloadAgentRuntimes()
                if previousBackendId != ExecutionBackendItem.providerId(providerId) {
                    executionBackendNotice = SettingsPageDesign.ExecutionBackend.nextRunNotice
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }

        func reloadLocalLLMModels() {
            guard !isLoadingLocalLLMModels else { return }
            isLoadingLocalLLMModels = true
            localLLMModelStatus = SettingsPageDesign.LocalLLM.modelsLoading
            errorMessage = nil

            Task {
                do {
                    let models = try await providerService.loadLocalLLMModels(
                        endpointURL: localLLMEndpoint
                    )
                    localLLMModels = models.sorted {
                        $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
                    }
                    localLLMModelStatus = localLLMModels.isEmpty
                        ? SettingsPageDesign.LocalLLM.modelsEmpty
                        : "\(localLLMModels.count) \(SettingsPageDesign.LocalLLM.modelsLoadedSuffix)"
                } catch {
                    localLLMModels = []
                    localLLMModelStatus = SettingsPageDesign.LocalLLM.modelsFailed
                    errorMessage = error.localizedDescription
                }
                isLoadingLocalLLMModels = false
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

        func saveAgentModelSelection() {
            guard let activeAgentRuntimeId, hasUnsavedAgentModelChanges else { return }
            appSettingsService.setAgentModelId(
                selectedAgentModelId.isEmpty ? nil : selectedAgentModelId,
                for: activeAgentRuntimeId
            )
            if selectedRuntime?.modelRouting != nil {
                appSettingsService.setAgentModelRoutingSettings(
                    currentAgentModelRoutingSettings,
                    for: activeAgentRuntimeId
                )
            }
            loadSelectedAgentModel()
            executionBackendNotice = SettingsPageDesign.ExecutionBackend.nextRunNotice
        }

        func revertAgentModelSelection() {
            loadSelectedAgentModel()
            errorMessage = nil
        }

        func restoreAgentModelDefaults() {
            guard let selectedRuntime else { return }
            selectedAgentModelId = normalizedAgentModelId(
                selectedRuntime.defaultModelId ?? "",
                for: selectedRuntime
            )
            guard let routing = selectedRuntime.modelRouting else { return }
            agentModelRoutingEnabled = AppSettingsDefaults.agentModelRoutingEnabled
            agentModelRoutingFastModelId = routing.defaultFastModelId
            agentModelRoutingFallbackModelId = routing.defaultFallbackModelId
            agentModelRoutingPromptLengthThreshold = routing.defaultPromptLengthThreshold
        }

        func saveSettings() {
            let agentModelChanged = hasUnsavedAgentModelChanges
            appSettingsService.defaultSafetyMode = selectedSafetyMode
            appSettingsService.mcpServerBasePath = mcpServerBasePath
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
                if selectedRuntime?.modelRouting != nil {
                    appSettingsService.setAgentModelRoutingSettings(
                        currentAgentModelRoutingSettings,
                        for: activeAgentRuntimeId
                    )
                }
            }
            appSettingsService.ragAnswerMode = ragAnswerMode
            appSettingsService.ragRetrievalSettings = currentRAGRetrievalSettings

            mcpServerBasePath = appSettingsService.mcpServerBasePath
            defaultMaxInputTokens = appSettingsService.defaultMaxInputTokens
            defaultMaxOutputTokens = appSettingsService.defaultMaxOutputTokens
            remoteControlEnabled = appSettingsService.remoteControlEnabled
            remoteControlAllowLAN = appSettingsService.remoteControlAllowLAN
            remoteControlPort = appSettingsService.remoteControlPort
            remoteControlToken = appSettingsService.remoteControlToken
            loadSelectedAgentModel()
            loadRAGSettingsFromService()
            if agentModelChanged {
                executionBackendNotice = SettingsPageDesign.ExecutionBackend.nextRunNotice
            }
            errorMessage = nil
            remoteControlService?.reload()
            if remoteControlService?.state == .failed {
                errorMessage = "Remote Control: \(remoteControlService?.lastErrorMessage ?? SettingsPageDesign.AppSettings.remoteControlFailedStatus)"
            }
        }

        func revertSettings() {
            loadApplicationSettingsFromService()
            errorMessage = nil
        }

        func restoreDefaultSettingsDraft() {
            selectedSafetyMode = AppSettingsDefaults.defaultSafetyMode
            mcpServerBasePath = AppSettingsDefaults.mcpServerBasePath
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

        func saveLocalLLMSettings() {
            appSettingsService.localLLMEndpoint = localLLMEndpoint
            appSettingsService.localLLMModel = localLLMModel
            loadLocalLLMSettingsFromService()
            persistedLocalLLMSettingsSnapshot = currentLocalLLMSettingsSnapshot
            errorMessage = nil
        }

        func revertLocalLLMSettings() {
            loadLocalLLMSettingsFromService()
            errorMessage = nil
        }

        func restoreDefaultLocalLLMSettingsDraft() {
            localLLMEndpoint = AppSettingsDefaults.localLLMEndpoint
            localLLMModel = AppSettingsDefaults.localLLMModel
            errorMessage = nil
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

        private func loadApplicationSettingsFromService() {
            selectedSafetyMode = appSettingsService.defaultSafetyMode
            mcpServerBasePath = appSettingsService.mcpServerBasePath
            defaultMaxInputTokens = appSettingsService.defaultMaxInputTokens
            defaultMaxOutputTokens = appSettingsService.defaultMaxOutputTokens
            remoteControlEnabled = appSettingsService.remoteControlEnabled
            remoteControlAllowLAN = appSettingsService.remoteControlAllowLAN
            remoteControlPort = appSettingsService.remoteControlPort
            remoteControlToken = appSettingsService.remoteControlToken
            loadSelectedAgentModel()
            loadRAGSettingsFromService()
        }

        private func loadLocalLLMSettingsFromService() {
            localLLMEndpoint = appSettingsService.localLLMEndpoint
            localLLMModel = appSettingsService.localLLMModel
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

        private var currentLocalLLMSettingsSnapshot: LocalLLMSettingsSnapshot {
            LocalLLMSettingsSnapshot(
                endpoint: localLLMEndpoint,
                model: localLLMModel
            )
        }

        private var currentAgentModelRoutingSettings: AgentModelRoutingSettings {
            AgentModelRoutingSettings(
                isEnabled: agentModelRoutingEnabled,
                fastModelId: agentModelRoutingFastModelId,
                fallbackModelId: agentModelRoutingFallbackModelId,
                promptLengthThreshold: max(1, agentModelRoutingPromptLengthThreshold)
            )
        }

        private var currentAgentModelSettingsSnapshot: AgentModelSettingsSnapshot {
            AgentModelSettingsSnapshot(
                modelId: selectedAgentModelId,
                routing: selectedRuntime?.modelRouting == nil
                    ? nil
                    : currentAgentModelRoutingSettings
            )
        }

        private var persistedAgentModelSettingsSnapshot: AgentModelSettingsSnapshot {
            AgentModelSettingsSnapshot(
                modelId: persistedAgentModelId,
                routing: persistedAgentModelRoutingSettings
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
                agentModelRoutingEnabled = AppSettingsDefaults.agentModelRoutingEnabled
                agentModelRoutingFastModelId = ""
                agentModelRoutingFallbackModelId = ""
                agentModelRoutingPromptLengthThreshold =
                    AppSettingsDefaults.agentModelRoutingPromptLengthThreshold
                return
            }
            selectedAgentModelId = normalizedAgentModelId(persistedAgentModelId, for: selectedRuntime)
            if let settings = persistedAgentModelRoutingSettings {
                agentModelRoutingEnabled = settings.isEnabled
                agentModelRoutingFastModelId = settings.fastModelId
                agentModelRoutingFallbackModelId = settings.fallbackModelId
                agentModelRoutingPromptLengthThreshold = settings.promptLengthThreshold
            } else {
                agentModelRoutingEnabled = AppSettingsDefaults.agentModelRoutingEnabled
                agentModelRoutingFastModelId = ""
                agentModelRoutingFallbackModelId = ""
                agentModelRoutingPromptLengthThreshold =
                    AppSettingsDefaults.agentModelRoutingPromptLengthThreshold
            }
        }

        private var persistedAgentModelRoutingSettings: AgentModelRoutingSettings? {
            guard let activeAgentRuntimeId,
                  let routing = selectedRuntime?.modelRouting else {
                return nil
            }
            let saved = appSettingsService.agentModelRoutingSettings(for: activeAgentRuntimeId)
            return AgentModelRoutingSettings(
                isEnabled: saved?.isEnabled ?? AppSettingsDefaults.agentModelRoutingEnabled,
                fastModelId: normalizedRoutingModelId(
                    saved?.fastModelId,
                    fallback: routing.defaultFastModelId
                ),
                fallbackModelId: normalizedRoutingModelId(
                    saved?.fallbackModelId,
                    fallback: routing.defaultFallbackModelId
                ),
                promptLengthThreshold: max(
                    1,
                    saved?.promptLengthThreshold ?? routing.defaultPromptLengthThreshold
                )
            )
        }

        private func normalizedRoutingModelId(
            _ candidate: String?,
            fallback: String
        ) -> String {
            guard let selectedRuntime else { return fallback }
            if let candidate,
               selectedRuntime.modelOptions.contains(where: { $0.id == candidate }) {
                return candidate
            }
            if selectedRuntime.modelOptions.contains(where: { $0.id == fallback }) {
                return fallback
            }
            return selectedRuntime.modelOptions.first?.id ?? fallback
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

    private struct LocalLLMSettingsSnapshot: Equatable {
        var endpoint: String
        var model: String
    }

    private struct AgentModelSettingsSnapshot: Equatable {
        var modelId: String
        var routing: AgentModelRoutingSettings?
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
        var modelRouting: AgentModelRoutingDescriptor?
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
