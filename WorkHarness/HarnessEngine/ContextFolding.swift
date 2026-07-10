//
// ContextFolding.swift
// WorkHarness
//
// Created by Auto (Codex) on 10.07.2026.
//

import Foundation

@MainActor
protocol ContextFoldingServiceProtocol: AnyObject {
    func fold(run: Run) -> ContextFoldSummary
}

@MainActor
final class ContextFoldingService: ContextFoldingServiceProtocol {
    func fold(run: Run) -> ContextFoldSummary {
        let userMessages = run.events.filter { $0.type == .userMessage }.map(\.message)
        let assistantMessages = run.events.filter { $0.type == .assistantMessage }.map(\.message)
        let decisions = run.events.compactMap(decisionText(for:))
        let failures = run.events.compactMap(failureText(for:))

        let conversationSummary = [
            userMessages.last.map { "Latest user request: \($0)" },
            assistantMessages.last.map { "Latest assistant result: \($0)" }
        ].compactMap { $0 }.joined(separator: " ")

        let currentState = "Run status: \(run.status.label). (latestStateText(in: run))"
        let nextActions = run.status == .failed
            ? ["Review the failed attempt and retry or revise the goal."]
            : ["Continue from the current state and preserve the decisions above."]

        return ContextFoldSummary(
            runSummary: "Goal: \(run.goal). Recorded events: \(run.events.count).",
            conversationSummary: conversationSummary.isEmpty ? "No conversation messages recorded." : conversationSummary,
            decisionLog: decisions,
            currentState: currentState,
            failedAttempts: failures,
            nextActions: nextActions,
            sourceEventCount: run.events.count
        )
    }

    private func decisionText(for event: RunEvent) -> String? {
        switch event.type {
        case .approvalGranted, .approvalRejected, .fileChanged, .validationFinished, .finalSummary:
            return "(event.type.label): (event.message)"
        default:
            return nil
        }
    }

    private func failureText(for event: RunEvent) -> String? {
        switch event.type {
        case .providerRequestFailed, .toolCallFailed, .error, .runFailed:
            return "(event.type.label): (event.message)"
        default:
            return nil
        }
    }

    private func latestStateText(in run: Run) -> String {
        guard let event = run.events.last else { return "No events recorded." }
        return "Last event: \(event.type.label) - \(event.message)"
    }
}
