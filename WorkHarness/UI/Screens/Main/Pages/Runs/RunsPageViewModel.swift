//
// RunsPageViewModel.swift
// WorkHarness
//
// Created by Auto (Codex) on 07.07.2026.
//

import Foundation
import Observation

extension MainScreen {
    @MainActor
    @Observable
    final class RunsPageViewModel {
        private let runService: RunServiceProtocol

        init(runService: RunServiceProtocol) {
            self.runService = runService
        }

        var selectedRunId: Run.ID?
        var selectedEventId: RunEvent.ID?
        var isRecovering = false
        var recoveryError: String?
        var artifactError: String?

        var runs: [Run] {
            runService.runs
        }

        var runRows: [RunRowState] {
            runs.map { run in
                RunRowState(
                    id: run.id,
                    title: run.goal,
                    subtitle: summary(for: run),
                    status: run.status.label,
                    isSelected: selectedRun?.id == run.id
                )
            }
        }

        var selectedRun: Run? {
            if let selectedRunId, let run = runService.run(withId: selectedRunId) {
                return run
            }

            return runs.first
        }

        var selectedEvent: RunEvent? {
            guard let run = selectedRun else { return nil }
            guard let selectedEventId else { return orderedEvents(for: run).last }
            return run.events.first { $0.id == selectedEventId }
        }

        var selectedRunDetail: RunDetailState? {
            guard let run = selectedRun else { return nil }

            return RunDetailState(
                id: run.id,
                title: run.goal,
                status: run.status.label,
                mode: run.mode.label,
                createdAt: run.createdAt,
                updatedAt: run.updatedAt,
                metrics: metrics(for: run),
                events: orderedEvents(for: run).map(eventState(for:)),
                hasEvents: !run.events.isEmpty,
                artifacts: artifactStates(for: run),
                selectedEvent: selectedEvent.map(eventInspectorState(for:))
            )
        }

        func summary(for run: Run) -> String {
            let totalTokens = run.tokenUsage.inputTokens + run.tokenUsage.outputTokens
            return "\(run.events.count)\(RunsPageDesign.Row.eventsSuffix)\(RunsPageDesign.Row.eventsTokensSeparator)\(totalTokens)\(RunsPageDesign.Row.tokensSuffix)"
        }

        func selectRun(id runId: Run.ID?) {
            selectedRunId = runId
            selectedEventId = nil
        }

        func selectEvent(id eventId: RunEvent.ID?) {
            selectedEventId = eventId
        }

        func openArtifact(id artifactId: RunArtifact.ID) {
            artifactError = nil
            guard
                let artifact = selectedRun?.artifacts.first(where: { $0.id == artifactId }),
                runService.openArtifact(artifact)
            else {
                artifactError = RunsPageDesign.Detail.artifactOpenFailure
                return
            }
        }

        func isEventSelected(_ event: RunEventState) -> Bool {
            selectedEvent?.id == event.id
        }

        func resumeSelectedRun() {
            guard !isRecovering, let run = selectedRun, run.status == .interrupted else { return }
            isRecovering = true
            recoveryError = nil
            Task { [weak self] in
                guard let self else { return }
                let didResume = await runService.resumeRun(runId: run.id)
                if !didResume {
                    recoveryError = RunsPageDesign.Header.resumeFailure
                }
                isRecovering = false
            }
        }

        func restartSelectedRun() {
            guard !isRecovering, let run = selectedRun, run.status == .interrupted else { return }
            isRecovering = true
            recoveryError = nil
            Task { [weak self] in
                guard let self else { return }
                guard let newRunId = await runService.restartRun(runId: run.id) else {
                    recoveryError = RunsPageDesign.Header.restartFailure
                    isRecovering = false
                    return
                }
                selectedRunId = newRunId
                selectedEventId = nil
                isRecovering = false
            }
        }

        func cancelSelectedRun() {
            guard !isRecovering, let run = selectedRun, run.status == .interrupted else { return }
            Task {
                await runService.cancelRun(runId: run.id)
            }
        }

        private func orderedEvents(for run: Run) -> [RunEvent] {
            run.events.sorted { first, second in
                first.createdAt < second.createdAt
            }
        }

        private func metrics(for run: Run) -> [MetricState] {
            let totalTokens = run.tokenUsage.inputTokens + run.tokenUsage.outputTokens
            return [
                MetricState(title: RunsPageDesign.Metric.eventsTitle, value: "\(run.events.count)"),
                MetricState(title: RunsPageDesign.Metric.inputTokensTitle, value: "\(run.tokenUsage.inputTokens)"),
                MetricState(title: RunsPageDesign.Metric.outputTokensTitle, value: "\(run.tokenUsage.outputTokens)"),
                MetricState(title: RunsPageDesign.Metric.totalTokensTitle, value: "\(totalTokens)"),
                MetricState(title: RunsPageDesign.Metric.costTitle, value: costLabel(for: run.costUsage.totalUSD))
            ]
        }

        private func eventState(for event: RunEvent) -> RunEventState {
            RunEventState(
                id: event.id,
                title: event.type.label,
                message: RunEventDisplayFormatter.message(for: event),
                type: event.type,
                createdAt: event.createdAt,
                metadata: event.metadata
            )
        }

        private func eventInspectorState(for event: RunEvent) -> EventInspectorState {
            EventInspectorState(
                id: event.id,
                title: event.type.label,
                message: RunEventDisplayFormatter.message(for: event),
                createdAt: event.createdAt,
                metadata: event.metadata.sorted { $0.key < $1.key }.map { key, value in
                    MetadataState(key: key, value: value)
                }
            )
        }

        private func artifactStates(for run: Run) -> [ArtifactState] {
            run.artifacts.map { artifact in
                ArtifactState(
                    id: artifact.id,
                    title: artifact.name,
                    subtitle: artifact.path ?? artifact.kind,
                    canOpen: artifact.path != nil,
                    createdAt: artifact.createdAt
                )
            }
        }

        private func costLabel(for cost: Decimal) -> String {
            guard cost != 0 else { return RunsPageDesign.Metric.zeroCostValue }
            return "\(RunsPageDesign.Metric.costPrefix)\(NSDecimalNumber(decimal: cost).stringValue)"
        }
    }

    struct RunRowState: Identifiable, Equatable {
        let id: Run.ID
        var title: String
        var subtitle: String
        var status: String
        var isSelected: Bool
    }

    struct RunDetailState: Identifiable, Equatable {
        let id: Run.ID
        var title: String
        var status: String
        var mode: String
        var createdAt: Date
        var updatedAt: Date
        var metrics: [MetricState]
        var events: [RunEventState]
        var hasEvents: Bool
        var artifacts: [ArtifactState]
        var selectedEvent: EventInspectorState?
    }

    struct MetricState: Identifiable, Equatable {
        var id: String { title }
        var title: String
        var value: String
    }

    struct RunEventState: Identifiable, Equatable {
        let id: RunEvent.ID
        var title: String
        var message: String
        var type: RunEventType
        var createdAt: Date
        var metadata: [String: String]
    }

    struct EventInspectorState: Identifiable, Equatable {
        let id: RunEvent.ID
        var title: String
        var message: String
        var createdAt: Date
        var metadata: [MetadataState]
    }

    struct MetadataState: Identifiable, Equatable {
        var id: String { key }
        var key: String
        var value: String
    }

    struct ArtifactState: Identifiable, Equatable {
        let id: RunArtifact.ID
        var title: String
        var subtitle: String
        var canOpen: Bool
        var createdAt: Date
    }
}
