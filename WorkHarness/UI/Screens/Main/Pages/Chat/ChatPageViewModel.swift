//
// ChatPageViewModel.swift
// WorkHarness
//
// Created by Auto (Codex) on 07.07.2026.
//

import Foundation
import Observation

extension MainScreen {
    enum FileImportPurpose: Equatable {
        case contextAttachment
        case taskPool
    }

    enum MultiAgentConfigurationSection: String, CaseIterable {
        case workflowProfile
        case inference
    }

    @MainActor
    @Observable
    final class ChatPageViewModel {
        private let runService: RunServiceProtocol
        private let contextAttachmentService: RunContextAttachmentServiceProtocol
        private let agentProfileService: AgentProfileServiceProtocol?
        private let smokeTestService: SmokeTestServiceProtocol?
        private let testingWorkflowService: TestingWorkflowServiceProtocol?
        private let executionLoopService: ExecutionLoopServiceProtocol?
        private let microModelEvaluationService: MicroModelEvaluationServiceProtocol?
        @ObservationIgnored private var taskPoolSecurityScopedURL: URL?
        private var submissionTask: Task<Void, Never>?

        var selectedRunId: UUID?
        var draftMessage = ""
        var draftContextAttachments: [RunContextAttachment] = []
        var draftRunMode: RunMode = .simpleChat
        var composerMode: ComposerMode = .chat {
            didSet {
                switch composerMode {
                case .chat: draftRunMode = .simpleChat
                case .multiAgent: draftRunMode = .multiAgent
                case .taskLoop: break
                }
            }
        }
        var selectedTaskPool: ExecutionTaskPool?
        var multiAgentConfiguration = MultiAgentRunConfiguration.default
        var multiAgentConfigurationSection: MultiAgentConfigurationSection = .workflowProfile
        var isSending = false
        var isFileImporterPresented = false
        private(set) var fileImportPurpose: FileImportPurpose?
        var errorMessage: String?

        init(
            runService: RunServiceProtocol,
            contextAttachmentService: RunContextAttachmentServiceProtocol,
            agentProfileService: AgentProfileServiceProtocol? = nil,
            smokeTestService: SmokeTestServiceProtocol? = nil,
            testingWorkflowService: TestingWorkflowServiceProtocol? = nil,
            executionLoopService: ExecutionLoopServiceProtocol? = nil,
            microModelEvaluationService: MicroModelEvaluationServiceProtocol? = nil
        ) {
            self.runService = runService
            self.contextAttachmentService = contextAttachmentService
            self.agentProfileService = agentProfileService
            self.smokeTestService = smokeTestService
            self.testingWorkflowService = testingWorkflowService
            self.executionLoopService = executionLoopService
            self.microModelEvaluationService = microModelEvaluationService
            self.multiAgentConfiguration = StandardAgentDefaults.addingInferenceRoles(
                to: agentProfileService?.configuration(for: nil) ?? .default
            )
        }

        convenience init(runService: RunServiceProtocol) {
            self.init(
                runService: runService,
                contextAttachmentService: RunContextAttachmentService(),
                agentProfileService: nil
            )
        }

        var runs: [Run] {
            runService.runs
        }

        var agentProfiles: [AgentWorkflowProfile] {
            agentProfileService?.profiles ?? []
        }

        var selectedAgentProfileId: String {
            agentProfileService?.selectedProfileId ?? multiAgentConfiguration.profileId ?? ""
        }

        var selectedAgentConfigurationId: String {
            multiAgentConfigurationSection == .inference
                ? StandardAgentDefaults.inferenceConfigurationId
                : selectedAgentProfileId
        }

        var configurationForNextMultiAgentRun: MultiAgentRunConfiguration {
            var configuration = multiAgentConfiguration
            switch multiAgentConfigurationSection {
            case .workflowProfile:
                configuration.roles.removeAll {
                    StandardAgentDefaults.isInferenceRole(id: $0.id)
                }
            case .inference:
                configuration.profileId = nil
                configuration.profileName = StandardAgentDefaults.inferenceConfigurationName
                configuration.roles = configuration.roles.filter {
                    StandardAgentDefaults.isInferenceRole(id: $0.id)
                }
            }
            return configuration
        }

        var recentRuns: [Run] {
            runs.sorted { lhs, rhs in
                if lhs.createdAt != rhs.createdAt {
                    return lhs.createdAt > rhs.createdAt
                }
                if lhs.updatedAt != rhs.updatedAt {
                    return lhs.updatedAt > rhs.updatedAt
                }
                return lhs.id.uuidString > rhs.id.uuidString
            }
        }

        var selectedRun: Run? {
            if let selectedRunId {
                return runService.run(withId: selectedRunId)
            }
            guard isSending else { return nil }
            return runs.first {
                $0.status == .running || $0.status == .waitingForApproval
            }
        }

        var selectedRunEvents: [RunEvent] {
            selectedRun?.events ?? []
        }

        var displayEvents: [RunEvent] {
            selectedRunEvents.reduce(into: [RunEvent]()) { result, event in
                guard event.type == .providerStreamDelta else {
                    result.append(event)
                    return
                }

                guard let lastIndex = result.indices.last,
                      canMergeStreamDelta(result[lastIndex], with: event) else {
                    result.append(event)
                    return
                }

                result[lastIndex].message += event.message
            }
        }

        private func canMergeStreamDelta(_ current: RunEvent, with next: RunEvent) -> Bool {
            guard current.type == .providerStreamDelta else { return false }

            if current.metadata["source"] == "acp", next.metadata["source"] == "acp" {
                return true
            }

            guard let currentStepId = current.metadata["planStepId"],
                  let nextStepId = next.metadata["planStepId"] else {
                return false
            }
            return currentStepId == nextStepId
        }

        var providerName: String {
            runService.providerName
        }

        var nextExecutionBackendName: String {
            runService.selectedAgentRuntimeDescriptor?.displayName ?? providerName
        }

        var agentModelOptions: [AgentRuntimeModelOption] {
            runService.selectedAgentRuntimeDescriptor?.modelOptions ?? []
        }

        var activeExecutionLoopAttempt: ExecutionLoopAttempt? {
            executionLoopService?.activeAttempt
        }

        var currentExecutionLoopTaskTitle: String? {
            selectedRun?.events.last(where: {
                $0.type == .agentStarted && $0.metadata["executionLoopProgress"] == "true"
            })?.metadata["taskTitle"]
        }

        func selectRun(_ run: Run) {
            selectedRunId = run.id
        }

        func startNewChat() {
            guard !isSending else { return }
            selectedRunId = nil
            draftMessage = ""
            draftContextAttachments = []
            draftRunMode = .simpleChat
            composerMode = .chat
            errorMessage = nil
        }

        func submitDraft() {
            submissionTask = Task { [weak self] in
                await self?.submitDraftAndWait()
            }
        }

        func submitDraftAndWait() async {
            let trimmedMessage = draftMessage.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedMessage.isEmpty, !isSending else { return }

            let attachments = draftContextAttachments
            draftMessage = ""
            draftContextAttachments = []
            if let selection = SmokeTestCommand.selection(from: trimmedMessage) {
                await runSmokeCommand(selection)
                return
            }
            if let command = TestingWorkflowCommand.parse(trimmedMessage) {
                await runTestingWorkflow(command)
                return
            }
            if let command = ExecutionLoopCommand.parse(trimmedMessage) {
                await runExecutionLoopCommand(command)
                return
            }
            if MicroModelEvaluationCommand.parse(trimmedMessage) != nil {
                runMicroModelEvaluationCommand()
                return
            }
            await send(trimmedMessage, contextAttachments: attachments)
        }

        func reloadAgentProfile() {
            agentProfileService?.reload()
            multiAgentConfiguration = StandardAgentDefaults.addingInferenceRoles(
                to: agentProfileService?.configuration(for: nil) ?? .default,
                preserving: multiAgentConfiguration
            )
        }

        func selectAgentProfile(id: String) {
            agentProfileService?.selectProfile(id: id)
            multiAgentConfigurationSection = .workflowProfile
            reloadAgentProfile()
        }

        func selectAgentConfiguration(id: String) {
            if id == StandardAgentDefaults.inferenceConfigurationId {
                selectMultiAgentConfigurationSection(.inference)
            } else {
                selectAgentProfile(id: id)
            }
        }

        func selectMultiAgentConfigurationSection(_ section: MultiAgentConfigurationSection) {
            multiAgentConfigurationSection = section
            guard section == .inference else { return }
            for index in multiAgentConfiguration.roles.indices where
                StandardAgentDefaults.isInferenceRole(id: multiAgentConfiguration.roles[index].id) {
                multiAgentConfiguration.roles[index].enabled = true
            }
        }

        func setAssistantEnabled(id: UUID, enabled: Bool) {
            if let index = multiAgentConfiguration.roles.firstIndex(where: { $0.id == id }) {
                multiAgentConfiguration.roles[index].enabled = enabled
            }
            errorMessage = nil
        }

        func setAssistantModelOverride(id: UUID, modelOverride: String?) {
            if let index = multiAgentConfiguration.roles.firstIndex(where: { $0.id == id }) {
                multiAgentConfiguration.roles[index].modelOverride = modelOverride
            }
            errorMessage = nil
        }

        func presentAttachmentImporter() {
            presentFileImporter(for: .contextAttachment)
        }

        func presentTaskPoolImporter() {
            presentFileImporter(for: .taskPool)
        }

        func handleImportedFile(_ url: URL) {
            let purpose = fileImportPurpose
            dismissFileImporter()

            switch purpose {
            case .contextAttachment:
                attachFile(url)
            case .taskPool:
                selectTaskPool(url)
            case nil:
                break
            }
        }

        func handleFileImportFailure(_ message: String) {
            dismissFileImporter()
            errorMessage = message
        }

        private func presentFileImporter(for purpose: FileImportPurpose) {
            fileImportPurpose = purpose
            isFileImporterPresented = true
        }

        private func dismissFileImporter() {
            isFileImporterPresented = false
            fileImportPurpose = nil
        }

        func selectTaskPool(_ url: URL) {
            guard let executionLoopService else {
                errorMessage = ChatPageDesign.Command.executionLoopUnavailable
                return
            }
            if let taskPoolSecurityScopedURL {
                taskPoolSecurityScopedURL.stopAccessingSecurityScopedResource()
                self.taskPoolSecurityScopedURL = nil
            }
            let didAccessSecurityScopedResource = url.startAccessingSecurityScopedResource()
            do {
                selectedTaskPool = try executionLoopService.preview(sourcePath: url.path)
                if didAccessSecurityScopedResource {
                    taskPoolSecurityScopedURL = url
                }
                errorMessage = nil
            } catch {
                if didAccessSecurityScopedResource {
                    url.stopAccessingSecurityScopedResource()
                }
                selectedTaskPool = nil
                errorMessage = error.localizedDescription
            }
        }

        func startSelectedTaskLoop() {
            guard let selectedTaskPool else { return }
            submissionTask = Task { [weak self] in
                await self?.startTaskLoop(sourcePath: selectedTaskPool.sourcePath)
            }
        }

        func pauseExecutionLoopAfterCurrentTask() {
            executionLoopService?.pauseAfterCurrentTask()
        }

        func resumeExecutionLoop() {
            submissionTask = Task { [weak self] in
                guard let self, let executionLoopService else { return }
                do {
                    selectedRunId = try await executionLoopService.resume()
                    errorMessage = nil
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        }

        func endExecutionLoop() {
            Task { [weak self] in
                await self?.executionLoopService?.stop()
            }
        }

        private func startTaskLoop(sourcePath: String) async {
            guard let executionLoopService else { return }
            do {
                selectedRunId = try await executionLoopService.start(sourcePath: sourcePath)
                errorMessage = nil
            } catch {
                errorMessage = error.localizedDescription
            }
        }

        func attachFile(_ url: URL) {
            loadAttachment(from: url)
        }

        func attachFileAndWait(_ url: URL) async {
            loadAttachment(from: url)
        }

        private func loadAttachment(from url: URL) {
            do {
                let attachment = try contextAttachmentService.loadAttachment(from: url)
                draftContextAttachments.removeAll { $0.name == attachment.name }
                draftContextAttachments.append(attachment)
                errorMessage = nil
            } catch {
                errorMessage = error.localizedDescription
            }
        }

        func removeAttachment(_ attachment: RunContextAttachment) {
            draftContextAttachments.removeAll { $0.id == attachment.id }
        }

        func stopRun() {
            Task {
                await stopRunAndWait()
            }
        }

        func stopRunAndWait() async {
            if let executionLoopService,
               let activeAttempt = executionLoopService.activeAttempt,
               activeAttempt.controllerRunId == selectedRunId,
               activeAttempt.finishedAt == nil {
                await executionLoopService.stop()
                submissionTask?.cancel()
                submissionTask = nil
                isSending = false
                return
            }
            guard let run = await activeRunAwaitingStartup(),
                  run.status == .running ||
                  run.status == .waitingForApproval ||
                  run.status == .interrupted else { return }

            await runService.cancelRun(runId: run.id)
            submissionTask?.cancel()
            submissionTask = nil
            isSending = false
        }

        private func activeRunAwaitingStartup() async -> Run? {
            if let selectedRun {
                return selectedRun
            }
            guard isSending else { return nil }

            for _ in 0..<50 {
                await Task.yield()
                if let selectedRun {
                    return selectedRun
                }
                try? await Task.sleep(for: .milliseconds(10))
            }
            return nil
        }

        func resumeInterruptedRun() {
            guard !isSending, selectedRun?.status == .interrupted else { return }
            submissionTask = Task { [weak self] in
                await self?.resumeInterruptedRunAndWait()
            }
        }

        func restartInterruptedRun() {
            guard !isSending, selectedRun?.status == .interrupted else { return }
            submissionTask = Task { [weak self] in
                await self?.restartInterruptedRunAndWait()
            }
        }

        private func resumeInterruptedRunAndWait() async {
            guard let runId = selectedRun?.id else { return }
            isSending = true
            errorMessage = nil
            defer { isSending = false }

            let didResume = await runService.resumeRun(runId: runId)
            if !didResume {
                errorMessage = ChatPageDesign.Header.resumeFailure
            }
        }

        private func restartInterruptedRunAndWait() async {
            guard let runId = selectedRun?.id else { return }
            isSending = true
            errorMessage = nil
            defer { isSending = false }

            guard let restartedRunId = await runService.restartRun(runId: runId) else {
                errorMessage = ChatPageDesign.Header.restartFailure
                return
            }
            selectedRunId = restartedRunId
        }

        private func send(
            _ message: String,
            contextAttachments: [RunContextAttachment]
        ) async {
            guard !isSending else { return }

            isSending = true
            errorMessage = nil
            defer { isSending = false }

            if let selectedRunId {
                await runService.sendMessage(
                    runId: selectedRunId,
                    message: message,
                    contextAttachments: contextAttachments
                )
            } else {
                if draftRunMode == .multiAgent {
                    reloadAgentProfile()
                }
                guard let runId = await runService.startRun(
                    goal: message,
                    mode: draftRunMode,
                    configuration: configurationForNextMultiAgentRun,
                    contextAttachments: contextAttachments
                ) else { return }
                selectedRunId = runId
            }
        }

        private func runSmokeCommand(_ selection: SmokeTestSelection) async {
            guard !isSending else { return }
            guard let smokeTestService else {
                errorMessage = ChatPageDesign.Command.smokeUnavailable
                return
            }

            isSending = true
            errorMessage = nil
            defer { isSending = false }

            do {
                selectedRunId = try await smokeTestService.startScenarios(selection)
            } catch {
                errorMessage = error.localizedDescription
            }
        }

        private func runTestingWorkflow(_ command: TestingWorkflowCommand) async {
            guard !isSending else { return }
            guard let testingWorkflowService else {
                errorMessage = ChatPageDesign.Command.testingUnavailable
                return
            }

            isSending = true
            errorMessage = nil
            defer { isSending = false }

            do {
                selectedRunId = try await testingWorkflowService.startFullRun(
                    request: command.request
                )
            } catch {
                errorMessage = error.localizedDescription
            }
        }

        private func runExecutionLoopCommand(_ command: ExecutionLoopCommand) async {
            guard let executionLoopService else {
                errorMessage = ChatPageDesign.Command.executionLoopUnavailable
                return
            }

            isSending = true
            errorMessage = nil
            defer { isSending = false }

            do {
                switch command.action {
                case .start(let sourcePath):
                    selectedRunId = try await executionLoopService.start(sourcePath: sourcePath)
                case .pause:
                    executionLoopService.pauseAfterCurrentTask()
                case .resume:
                    selectedRunId = try await executionLoopService.resume()
                case .stop:
                    await executionLoopService.stop()
                    if let controllerRunId = executionLoopService.activeAttempt?.controllerRunId {
                        selectedRunId = controllerRunId
                    }
                case .status:
                    guard let controllerRunId = executionLoopService.activeAttempt?.controllerRunId else {
                        throw ExecutionLoopServiceError.noAttempt
                    }
                    selectedRunId = controllerRunId
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }

        private func runMicroModelEvaluationCommand() {
            guard let microModelEvaluationService else {
                errorMessage = ChatPageDesign.Command.microModelEvaluationUnavailable
                return
            }
            do {
                selectedRunId = try microModelEvaluationService.startEvaluation()
                errorMessage = nil
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
