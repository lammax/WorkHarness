//
// ChatPageViewModel.swift
// WorkHarness
//
// Created by Auto (Codex) on 07.07.2026.
//

import Foundation
import Observation

extension MainScreen {
    @MainActor
    @Observable
    final class ChatPageViewModel {
        private let runService: RunServiceProtocol
        private let contextAttachmentService: RunContextAttachmentServiceProtocol
        private let agentProfileService: AgentProfileServiceProtocol?
        private let smokeTestService: SmokeTestServiceProtocol?
        private let testingWorkflowService: TestingWorkflowServiceProtocol?
        private var submissionTask: Task<Void, Never>?

        var selectedRunId: UUID?
        var draftMessage = ""
        var draftContextAttachments: [RunContextAttachment] = []
        var draftRunMode: RunMode = .simpleChat
        var multiAgentConfiguration = MultiAgentRunConfiguration.default
        var isSending = false
        var isAttachmentImporterPresented = false
        var errorMessage: String?

        init(
            runService: RunServiceProtocol,
            contextAttachmentService: RunContextAttachmentServiceProtocol,
            agentProfileService: AgentProfileServiceProtocol? = nil,
            smokeTestService: SmokeTestServiceProtocol? = nil,
            testingWorkflowService: TestingWorkflowServiceProtocol? = nil
        ) {
            self.runService = runService
            self.contextAttachmentService = contextAttachmentService
            self.agentProfileService = agentProfileService
            self.smokeTestService = smokeTestService
            self.testingWorkflowService = testingWorkflowService
            self.multiAgentConfiguration = agentProfileService?.configuration(for: nil) ?? .default
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

        var agentModelOptions: [AgentRuntimeModelOption] {
            runService.selectedAgentRuntimeDescriptor?.modelOptions ?? []
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
            await send(trimmedMessage, contextAttachments: attachments)
        }

        func reloadAgentProfile() {
            multiAgentConfiguration = agentProfileService?.configuration(for: nil) ?? multiAgentConfiguration
        }

        func setAssistantEnabled(id: UUID, enabled: Bool) {
            do {
                try agentProfileService?.setAssistantEnabled(
                    id: id,
                    enabled: enabled,
                    profileId: multiAgentConfiguration.profileId
                )
                errorMessage = nil
            } catch {
                errorMessage = error.localizedDescription
                reloadAgentProfile()
            }
        }

        func setAssistantModelOverride(id: UUID, modelOverride: String?) {
            do {
                try agentProfileService?.setAssistantModelOverride(
                    id: id,
                    modelOverride: modelOverride,
                    profileId: multiAgentConfiguration.profileId
                )
                errorMessage = nil
            } catch {
                errorMessage = error.localizedDescription
                reloadAgentProfile()
            }
        }

        func presentAttachmentImporter() {
            isAttachmentImporterPresented = true
        }

        func attachFile(_ url: URL) {
            Task {
                await attachFileAndWait(url)
            }
        }

        func attachFileAndWait(_ url: URL) async {
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

        func setAttachmentError(_ message: String) {
            errorMessage = message
        }

        func stopRun() {
            Task {
                await stopRunAndWait()
            }
        }

        func stopRunAndWait() async {
            guard let run = selectedRun,
                  run.status == .running ||
                  run.status == .waitingForApproval ||
                  run.status == .interrupted else { return }

            await runService.cancelRun(runId: run.id)
            submissionTask?.cancel()
            submissionTask = nil
            isSending = false
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
                    configuration: multiAgentConfiguration,
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
    }
}
