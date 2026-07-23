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
            contextAttachmentService: RunContextAttachmentServiceProtocol
        ) {
            self.runService = runService
            self.contextAttachmentService = contextAttachmentService
        }

        convenience init(runService: RunServiceProtocol) {
            self.init(
                runService: runService,
                contextAttachmentService: RunContextAttachmentService()
            )
        }

        var runs: [Run] {
            runService.runs
        }

        var selectedRun: Run? {
            guard let selectedRunId else { return runs.first }
            return runService.run(withId: selectedRunId)
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
            await send(trimmedMessage, contextAttachments: attachments)
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
                  run.status == .running || run.status == .waitingForApproval else { return }

            await runService.cancelRun(runId: run.id)
            submissionTask?.cancel()
            submissionTask = nil
            isSending = false
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
            } else if let runId = await runService.startRun(
                goal: message,
                mode: draftRunMode,
                configuration: multiAgentConfiguration,
                contextAttachments: contextAttachments
            ) {
                selectedRunId = runId
            }
        }
    }
}
