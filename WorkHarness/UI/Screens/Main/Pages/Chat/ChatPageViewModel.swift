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

        var selectedRunId: UUID?
        var draftMessage = ""
        var draftRunMode: RunMode = .simpleChat
        var multiAgentConfiguration = MultiAgentRunConfiguration.default
        var isSending = false
        var errorMessage: String?

        init(runService: RunServiceProtocol) {
            self.runService = runService
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
                guard event.type == .providerStreamDelta, event.metadata["source"] == "acp" else {
                    result.append(event)
                    return
                }

                guard let lastIndex = result.indices.last,
                      result[lastIndex].type == .providerStreamDelta,
                      result[lastIndex].metadata["source"] == "acp" else {
                    result.append(event)
                    return
                }

                result[lastIndex].message += event.message
            }
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
            Task {
                await submitDraftAndWait()
            }
        }

        func submitDraftAndWait() async {
            let message = consumeDraft()
            await send(message)
        }

        private func consumeDraft() -> String {
            let message = draftMessage
            draftMessage = ""
            return message
        }

        private func send(_ message: String) async {
            let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedMessage.isEmpty, !isSending else { return }

            isSending = true
            errorMessage = nil
            defer { isSending = false }

            if let selectedRunId {
                await runService.sendMessage(runId: selectedRunId, message: trimmedMessage)
            } else if let runId = await runService.startRun(goal: trimmedMessage, mode: draftRunMode, configuration: multiAgentConfiguration) {
                selectedRunId = runId
            }
        }
    }
}
