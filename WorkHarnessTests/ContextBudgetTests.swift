//
// ContextBudgetTests.swift
// WorkHarness
//
// Created by Auto (Codex) on 31.07.2026.
//

import Foundation
import Testing
@testable import WorkHarness

struct ContextBudgetTests {
    @MainActor
    @Test func contentBelowAndAtBudgetBoundaryIsIncluded() throws {
        let belowBoundary = try makeProjectSnapshot(maxInputTokens: 5)
        let exactBoundary = try makeProjectSnapshot(maxInputTokens: 4)

        #expect(belowBoundary.sections.map(\.kind) == [.projectIdentity])
        #expect(exactBoundary.sections.map(\.kind) == [.projectIdentity])
        #expect(belowBoundary.omissions.isEmpty)
        #expect(exactBoundary.omissions.isEmpty)
        #expect(exactBoundary.estimatedInputTokenCount == 4)
        #expect(exactBoundary.windowConstraint.effectiveMaxInputTokens == 4)
    }

    @MainActor
    @Test func optionalOverflowKeepsHigherPrioritySummaryAndRecordsOmission() throws {
        let input = makeInput(
            objective: "Do work",
            project: Project(name: "Project"),
            recentRunSummary: "keep summary",
            maxInputTokens: 7
        )

        let first = try ContextBuilder().buildSnapshot(from: input)
        let second = try ContextBuilder().buildSnapshot(from: input)

        #expect(first.sections.map(\.kind) == [.recentRunSummary])
        #expect(first.includedSummaries == ["keep summary"])
        #expect(first.projectName == "Project")
        #expect(first.omissions == second.omissions)
        #expect(first.sections == second.sections)
        #expect(first.omissions.contains {
            $0.sectionKind == .projectIdentity &&
                $0.sourceKind == .project &&
                $0.reason == .budgetExceeded
        })
        #expect(first.estimatedInputTokenCount == 7)
    }

    @MainActor
    @Test func mandatoryAttachmentOverflowFailsExplicitly() throws {
        let input = makeInput(
            objective: "Do",
            attachments: [
                RunContextAttachment(name: "required.txt", content: "Required attachment evidence.")
            ],
            maxInputTokens: 1
        )

        do {
            _ = try ContextBuilder().buildSnapshot(from: input)
            Issue.record("Expected mandatory context overflow.")
        } catch let error as ContextBuildError {
            guard case let .mandatoryContentExceedsBudget(
                sourceId,
                requiredTokens,
                availableTokens
            ) = error else {
                Issue.record("Unexpected context build error: \(error)")
                return
            }
            #expect(sourceId.hasPrefix("attachment:"))
            #expect(requiredTokens > 0)
            #expect(availableTokens == 0)
        }
    }

    @MainActor
    @Test func providerWindowAndOutputReservationLimitInputBudget() throws {
        let snapshot = try ContextBuilder().buildSnapshot(from: ContextBuildInput(
            runId: UUID(),
            agent: makeAgent(),
            providerId: "small.provider",
            userMessage: "Do",
            currentProject: Project(name: "Project"),
            tokenBudget: TokenBudget(maxInputTokens: 100, maxOutputTokens: 1),
            providerContextWindowTokens: 4,
            safetyMode: .askBeforeWrite
        ))

        #expect(snapshot.windowConstraint.effectiveMaxInputTokens == 3)
        #expect(snapshot.sections.isEmpty)
        #expect(snapshot.omissions.count == 1)
        #expect(snapshot.estimatedInputTokenCount == 1)
    }

    @MainActor
    @Test func estimatorFailureIsMappedToTypedContextError() throws {
        let runId = UUID()
        let builder = ContextBuilder(tokenEstimator: FailingContextTokenEstimator())

        do {
            _ = try builder.buildSnapshot(from: makeInput(runId: runId, objective: "Do"))
            Issue.record("Expected token estimator failure.")
        } catch let error as ContextBuildError {
            guard case let .tokenEstimationFailed(sourceId, message) = error else {
                Issue.record("Unexpected context build error: \(error)")
                return
            }
            #expect(sourceId == "run:\(runId.uuidString):objective")
            #expect(message.contains("estimator unavailable"))
        }
    }

    @MainActor
    @Test func cancelledBuildStopsBeforeProducingContext() async {
        let input = makeInput(objective: "Do")
        let task = Task { @MainActor in
            await Task.yield()
            return try ContextBuilder().buildSnapshot(from: input)
        }
        task.cancel()

        do {
            _ = try await task.value
            Issue.record("Expected context build cancellation.")
        } catch {
            #expect(error is CancellationError)
        }
    }

    @MainActor
    @Test func harnessRecordsSafeOverflowMetadataAndSendsOnlyIncludedContext() async throws {
        let repository = InMemoryRunRepository()
        let projectService = ProjectService(repository: InMemoryProjectRepository())
        _ = projectService.addProject(name: "Budget Project", rootPath: nil)
        let settings = InMemoryAppSettingsService(
            defaultSafetyMode: .askBeforeWrite,
            defaultMaxInputTokens: 1,
            defaultMaxOutputTokens: 0
        )
        let provider = ContextBudgetRecordingProvider()
        let engine = HarnessEngine(
            repository: repository,
            recorder: RunRecorder(repository: repository),
            providerService: ProviderService(
                registry: ProviderRegistry(providers: [provider]),
                appSettingsService: settings
            ),
            projectService: projectService,
            contextBuilder: ContextBuilder(),
            appSettingsService: settings
        )

        let runId = try #require(await engine.startRun(goal: "Run"))
        let event = try #require(repository.run(withId: runId)?.events.first {
            $0.type == .contextBuilt
        })

        #expect(provider.requests.first?.context.isEmpty == true)
        #expect(event.metadata["estimatedInputTokenCount"] == "1")
        #expect(event.metadata["effectiveMaxInputTokens"] == "1")
        #expect(event.metadata["omissionCount"] == "1")
        #expect(event.metadata["omittedTokenEstimate"] == "4")
        #expect(event.metadata["omissionReasons"] == ContextOmissionReason.budgetExceeded.rawValue)
        #expect(event.metadata["omittedSectionKinds"] == ContextSectionKind.projectIdentity.rawValue)
        #expect(!event.metadata.values.contains { $0.contains("Budget Project") })
    }

    @MainActor
    @Test func harnessFailsRunBeforeProviderWhenMandatoryContextCannotFit() async throws {
        let repository = InMemoryRunRepository()
        let settings = InMemoryAppSettingsService(
            defaultSafetyMode: .askBeforeWrite,
            defaultMaxInputTokens: 1,
            defaultMaxOutputTokens: 0
        )
        let provider = ContextBudgetRecordingProvider()
        let engine = HarnessEngine(
            repository: repository,
            recorder: RunRecorder(repository: repository),
            providerService: ProviderService(
                registry: ProviderRegistry(providers: [provider]),
                appSettingsService: settings
            ),
            contextBuilder: ContextBuilder(),
            appSettingsService: settings
        )

        let runId = try #require(await engine.startRun(
            goal: "Run",
            contextAttachments: [
                RunContextAttachment(name: "required.txt", content: "Required evidence.")
            ]
        ))
        let run = try #require(repository.run(withId: runId))

        #expect(run.status == .failed)
        #expect(provider.requests.isEmpty)
        #expect(!run.events.contains { $0.type == .contextBuilt })
        #expect(run.events.contains {
            $0.type == .runFailed &&
                $0.message.contains("Mandatory context source attachment:")
        })
    }

    @MainActor
    private func makeProjectSnapshot(maxInputTokens: Int) throws -> ContextSnapshot {
        try ContextBuilder().buildSnapshot(from: makeInput(
            objective: "Do",
            project: Project(name: "Project"),
            maxInputTokens: maxInputTokens
        ))
    }

    @MainActor
    private func makeInput(
        runId: UUID = UUID(),
        objective: String,
        project: Project? = nil,
        recentRunSummary: String? = nil,
        attachments: [RunContextAttachment] = [],
        maxInputTokens: Int = 100
    ) -> ContextBuildInput {
        ContextBuildInput(
            runId: runId,
            agent: makeAgent(),
            providerId: "test.provider",
            userMessage: objective,
            currentProject: project,
            recentRunSummary: recentRunSummary,
            contextAttachments: attachments,
            tokenBudget: TokenBudget(
                maxInputTokens: maxInputTokens,
                maxOutputTokens: 0
            ),
            safetyMode: .askBeforeWrite
        )
    }

    private func makeAgent() -> Agent {
        Agent(role: .coder, providerId: "test.provider", model: "test-model")
    }
}

private struct FailingContextTokenEstimator: ContextTokenEstimatorProtocol {
    private struct Failure: LocalizedError {
        var errorDescription: String? {
            "estimator unavailable"
        }
    }

    func estimateTokenCount(for content: String) throws -> Int {
        throw Failure()
    }
}

@MainActor
private final class ContextBudgetRecordingProvider: AIProvider {
    let id = "context.budget.provider"
    let displayName = "Context Budget Provider"
    let capabilities = ProviderCapabilities(
        supportsStreaming: true,
        contextWindowTokens: 100,
        supportedModels: ["context-budget"]
    )
    private(set) var requests: [AIRequest] = []

    func send(_ request: AIRequest) async throws -> AsyncThrowingStream<AIEvent, Error> {
        requests.append(request)
        return AsyncThrowingStream { continuation in
            continuation.yield(.started)
            continuation.yield(.messageCompleted("Done"))
            continuation.yield(.finished)
            continuation.finish()
        }
    }
}
