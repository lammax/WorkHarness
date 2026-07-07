//
// ChatViewModel.swift
// WorkHarness
//
// Created by Auto (Codex) on 07.07.2026.
//

import Foundation
import Observation

@MainActor
@Observable
final class ChatViewModel {
    private let repository: RunRepository
    private let harnessEngine: HarnessEngine

    var selectedRunId: UUID?
    var draftMessage = ""
    var isSending = false
    var errorMessage: String?

    init(repository: RunRepository, harnessEngine: HarnessEngine) {
        self.repository = repository
        self.harnessEngine = harnessEngine
    }

    var runs: [Run] {
        repository.runs
    }

    var selectedRun: Run? {
        guard let selectedRunId else { return runs.first }
        return repository.run(withId: selectedRunId)
    }

    var selectedRunEvents: [RunEvent] {
        selectedRun?.events ?? []
    }

    var providerName: String {
        harnessEngine.providerName
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
            await harnessEngine.sendMessage(runId: selectedRunId, message: trimmedMessage)
        } else if let runId = await harnessEngine.startRun(goal: trimmedMessage) {
            selectedRunId = runId
        }
    }
}
