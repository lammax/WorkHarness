//
// ContextObservabilityTests.swift
// WorkHarnessTests
//
// Created by Auto (Codex) on 31.07.2026.
//

import Foundation
import Testing
@testable import WorkHarness

@Suite
struct ContextObservabilityTests {
    @MainActor
    @Test func observationMetadataUsesSafeSourceIdsAndSectionTokenEstimates() throws {
        let sensitivePath = "/Users/example/private/Secrets.swift"
        let snapshot = try ContextBuilder().buildSnapshot(from: ContextBuildInput(
            runId: UUID(),
            agent: Agent(role: .coder, providerId: "test.provider", model: "test"),
            providerId: "test.provider",
            userMessage: "Inspect private context",
            selectedFiles: [sensitivePath],
            tokenBudget: TokenBudget(maxInputTokens: 100, maxOutputTokens: 10),
            providerContextWindowTokens: 200,
            safetyMode: .askBeforeWrite
        ))

        let metadata = ContextObservationPolicy().metadata(
            for: snapshot,
            buildDurationMilliseconds: 7
        )
        let sources = try decode([ContextSourceObservation].self, metadata["selectedSourcesJSON"])
        let sections = try decode([ContextSectionObservation].self, metadata["sectionTokenEstimatesJSON"])

        #expect(metadata["contextBuildDurationMs"] == "7")
        #expect(metadata["selectedSourceObservationCount"] == "2")
        #expect(sources.map(\.kind) == [.objective, .fileReference])
        #expect(sources.allSatisfy { $0.id.count > 16 })
        #expect(!sources.contains { $0.id.contains(sensitivePath) })
        #expect(!metadata.values.contains { $0.contains(sensitivePath) })
        #expect(sources[0].selectionReason == .requiredNow)
        #expect(sources[1].selectionReason == .retrievableLater)
        #expect(sections == [
            ContextSectionObservation(
                kind: .selectedFiles,
                order: 0,
                estimatedTokenCount: snapshot.sections[0].estimatedTokenCount,
                sourceCount: 1
            )
        ])
    }

    @MainActor
    @Test func observationMetadataRecordsOmissionReasonWithoutRawSourceId() throws {
        let privateSourceId = "file:/Users/example/private/Secrets.swift"
        let snapshot = ContextSnapshot(
            runId: UUID(),
            summary: "No additional context was included.",
            omissions: [
                ContextOmission(
                    sourceId: privateSourceId,
                    sourceKind: .fileReference,
                    sectionKind: .selectedFiles,
                    reason: .budgetExceeded,
                    estimatedTokenCount: 12
                )
            ],
            tokenCount: 1,
            estimatedInputTokenCount: 1
        )

        let metadata = ContextObservationPolicy().metadata(
            for: snapshot,
            buildDurationMilliseconds: 0
        )
        let omissions = try decode(
            [ContextOmissionObservation].self,
            metadata["contextOmissionsJSON"]
        )

        #expect(omissions.count == 1)
        #expect(omissions[0].reason == .budgetExceeded)
        #expect(omissions[0].sectionKind == .selectedFiles)
        #expect(omissions[0].estimatedTokenCount == 12)
        #expect(!omissions[0].sourceId.contains(privateSourceId))
        #expect(!metadata.values.contains { $0.contains(privateSourceId) })
    }

    @MainActor
    @Test func providerRunLinksContextObservationToActualUsage() async throws {
        let repository = InMemoryRunRepository()
        let provider = ObservableUsageProvider()
        let settings = InMemoryAppSettingsService(
            defaultSafetyMode: .askBeforeWrite,
            defaultMaxInputTokens: 50,
            defaultMaxOutputTokens: 10
        )
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

        let runId = try #require(await engine.startRun(goal: "Observe context usage"))
        let run = try #require(repository.run(withId: runId))
        let contextEvent = try #require(run.events.first { $0.type == .contextBuilt })
        let usageEvent = try #require(run.events.first { $0.type == .usageUpdated })
        let sources = try decode(
            [ContextSourceObservation].self,
            contextEvent.metadata["selectedSourcesJSON"]
        )

        #expect(contextEvent.metadata["contextBuildDurationMs"] != nil)
        #expect(contextEvent.metadata["providerContextWindowTokens"] == "100")
        #expect(contextEvent.metadata["effectiveMaxInputTokens"] == "50")
        #expect(sources.count == 1)
        #expect(sources.first?.kind == .objective)
        #expect(usageEvent.metadata["contextSnapshotId"] == contextEvent.metadata["contextSnapshotId"])
        #expect(usageEvent.metadata["inputTokens"] == "9")
        #expect(usageEvent.metadata["outputTokens"] == "4")
        #expect(usageEvent.metadata["costUSD"] == "0.01")
        #expect(usageEvent.metadata["inputEstimateDelta"] != nil)
        #expect(run.tokenUsage.inputTokens == 9)
        #expect(run.costUsage.totalUSD == Decimal(string: "0.01"))
    }

    @MainActor
    @Test func mandatoryOverflowProducesSafeContextBuildFailureObservation() async throws {
        let repository = InMemoryRunRepository()
        let settings = InMemoryAppSettingsService(
            defaultSafetyMode: .askBeforeWrite,
            defaultMaxInputTokens: 1,
            defaultMaxOutputTokens: 0
        )
        let provider = ObservableUsageProvider()
        let attachment = RunContextAttachment(
            name: "private-name.txt",
            content: "PRIVATE_ATTACHMENT_VALUE"
        )
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
            goal: "Go",
            contextAttachments: [attachment]
        ))
        let event = try #require(repository.run(withId: runId)?.events.first {
            $0.type == .contextBuildFailed
        })

        #expect(event.metadata["failureKind"] == "mandatoryContentExceedsBudget")
        #expect(event.metadata["sourceId"]?.hasPrefix("context:") == true)
        #expect(event.metadata["requiredTokens"] != nil)
        #expect(event.metadata["availableTokens"] == "0")
        #expect(!event.metadata.values.contains { $0.contains(attachment.name) })
        #expect(!event.metadata.values.contains { $0.contains(attachment.content) })
        #expect(provider.requests.isEmpty)
    }

    @MainActor
    @Test func ragRetrievalRecordsSafeStartAndFinishEvents() async throws {
        let repository = InMemoryRunRepository()
        let provider = ObservableUsageProvider()
        let settings = InMemoryAppSettingsService(
            defaultSafetyMode: .askBeforeWrite,
            defaultMaxInputTokens: 100,
            defaultMaxOutputTokens: 10,
            ragAnswerMode: .enabled
        )
        let citation = RAGCitation(
            source: "/Users/example/private/Architecture.md",
            section: "Context",
            chunkID: 3,
            quote: "PRIVATE_RAG_QUOTE",
            score: 0.9
        )
        let ragService = ObservableRAGService(result: RAGSearchResult(
            answer: "Bounded evidence",
            citations: [citation],
            isUnknown: false,
            retrieval: RAGRetrievalSummary(
                originalQuestion: "private question",
                searchQuery: "context",
                candidatesBeforeFiltering: 8,
                chunksAfterFiltering: 1,
                bestScore: 0.9
            )
        ))
        let engine = HarnessEngine(
            repository: repository,
            recorder: RunRecorder(repository: repository),
            providerService: ProviderService(
                registry: ProviderRegistry(providers: [provider]),
                appSettingsService: settings
            ),
            contextBuilder: ContextBuilder(),
            ragService: ragService,
            appSettingsService: settings
        )

        let runId = try #require(await engine.startRun(goal: "Retrieve evidence"))
        let events = try #require(repository.run(withId: runId)?.events)
        let started = try #require(events.first { $0.type == .contextRetrievalStarted })
        let finished = try #require(events.first { $0.type == .contextRetrievalFinished })

        #expect(started.metadata["retrievalId"] == finished.metadata["retrievalId"])
        #expect(finished.metadata["status"] == "succeeded")
        #expect(finished.metadata["candidateCount"] == "8")
        #expect(finished.metadata["resultCount"] == "1")
        #expect(finished.metadata["durationMs"] != nil)
        #expect(finished.metadata["selectedSourceIdsJSON"]?.contains("ragCitation:") == true)
        #expect(!finished.metadata.values.contains { $0.contains(citation.source) })
        #expect(!finished.metadata.values.contains { $0.contains("PRIVATE_RAG_QUOTE") })
    }

    private func decode<T: Decodable>(_ type: T.Type, _ value: String?) throws -> T {
        let value = try #require(value)
        return try JSONDecoder().decode(T.self, from: Data(value.utf8))
    }
}

@MainActor
private final class ObservableUsageProvider: AIProvider {
    let id = "observable.provider"
    let displayName = "Observable Provider"
    let capabilities = ProviderCapabilities(
        supportsStreaming: true,
        contextWindowTokens: 100,
        supportedModels: ["observable"]
    )
    private(set) var requests: [AIRequest] = []

    func send(_ request: AIRequest) async throws -> AsyncThrowingStream<AIEvent, Error> {
        requests.append(request)
        return AsyncThrowingStream { continuation in
            continuation.yield(.started)
            continuation.yield(.tokenUsage(TokenUsage(
                inputTokens: 9,
                outputTokens: 4,
                totalCostUSD: Decimal(string: "0.01")!
            )))
            continuation.yield(.messageCompleted("Done"))
            continuation.yield(.finished)
            continuation.finish()
        }
    }
}

@MainActor
private final class ObservableRAGService: @MainActor RAGServiceProtocol {
    private let result: RAGSearchResult

    init(result: RAGSearchResult) {
        self.result = result
    }

    func index(
        zipURL: URL,
        strategy: RAGChunkingStrategy,
        replaceExisting: Bool
    ) async throws -> RAGIndexingSummary {
        RAGIndexingSummary(
            strategy: strategy,
            documentCount: 0,
            chunkCount: 0,
            averageTokens: 0,
            minTokens: 0,
            maxTokens: 0,
            embeddingModel: "fake",
            databasePath: "",
            duration: 0
        )
    }

    func search(question: String, settings: RAGRetrievalSettings) async throws -> RAGSearchResult {
        result
    }

    func clearIndex() async throws {}
}
