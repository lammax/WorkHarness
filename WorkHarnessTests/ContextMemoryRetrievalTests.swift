//
// ContextMemoryRetrievalTests.swift
// WorkHarnessTests
//
// Created by Auto (Codex) on 31.07.2026.
//

import Foundation
import Testing
@testable import WorkHarness

@Suite
struct ContextMemoryRetrievalTests {
    @Test func defaultPolicySelectsRecentReferencesDeterministicallyWithinBothLimits() throws {
        let projectId = UUID()
        let references = (1 ... 10).map {
            makeReference(
                projectId: projectId,
                suffix: $0,
                date: TimeInterval($0),
                characters: 1_000
            )
        }

        let selection = try ContextMemoryRetrievalPolicy().select(
            from: references.reversed(),
            contextPolicy: ContextPolicy(),
            memoryPolicy: MemoryPolicy()
        )

        #expect(selection.isEnabled)
        #expect(selection.selectedReferences.map(\.id) == references.suffix(8).reversed().map(\.id))
        #expect(selection.selectedReferences.reduce(0) { $0 + $1.contentCharacterCount } == 8_000)
        #expect(selection.omittedReferenceCount == 2)
    }

    @Test func policyDoesNotSelectOrResolveMemoryWhenAgentPolicyDisablesIt() throws {
        let reference = makeReference(
            projectId: UUID(),
            suffix: 1,
            date: 1,
            characters: 4
        )
        var contextPolicy = ContextPolicy()
        contextPolicy.includeMemoryFacts = false

        let selection = try ContextMemoryRetrievalPolicy().select(
            from: [reference],
            contextPolicy: contextPolicy,
            memoryPolicy: MemoryPolicy()
        )

        #expect(!selection.isEnabled)
        #expect(selection.selectedReferences.isEmpty)
        #expect(selection.omittedReferenceCount == 1)

        var memoryPolicy = MemoryPolicy()
        memoryPolicy.canReadMemory = false
        let memoryDisabledSelection = try ContextMemoryRetrievalPolicy().select(
            from: [reference],
            contextPolicy: ContextPolicy(),
            memoryPolicy: memoryPolicy
        )

        #expect(!memoryDisabledSelection.isEnabled)
        #expect(memoryDisabledSelection.selectedReferences.isEmpty)
        #expect(memoryDisabledSelection.omittedReferenceCount == 1)
    }

    @MainActor
    @Test func engineRetrievesOnlySelectedMemoryIDsAndRecordsSafeMeasurements() async throws {
        let fixture = makeEngineFixture(
            policy: ContextMemoryRetrievalPolicy(
                maximumItemCount: 2,
                maximumCharacterCount: 80
            )
        )

        let runId = try #require(await fixture.engine.startRun(goal: "Use bounded memory"))
        let request = try #require(fixture.provider.requests.first)
        let run = try #require(fixture.runRepository.run(withId: runId))
        let retrieval = try #require(run.events.first {
            $0.type == .contextRetrievalFinished &&
                $0.metadata["retrievalKind"] == "projectMemory"
        })
        let contextBuilt = try #require(run.events.first { $0.type == .contextBuilt })

        #expect(fixture.memoryService.requestedIDs == Array(fixture.memoryService.references.prefix(2).map(\.id)))
        #expect(request.context.contains { $0.contains("RECENT_MEMORY") })
        #expect(request.context.contains { $0.contains("MIDDLE_MEMORY") })
        #expect(!request.context.contains { $0.contains("OLD_MEMORY") })
        #expect(retrieval.metadata["candidateReferenceCount"] == "3")
        #expect(retrieval.metadata["selectedReferenceCount"] == "2")
        #expect(retrieval.metadata["resolvedItemCount"] == "2")
        #expect(retrieval.metadata["omittedReferenceCount"] == "1")
        #expect(retrieval.metadata["status"] == "succeeded")
        #expect(retrieval.metadata["durationMs"] != nil)
        #expect(!retrieval.metadata.values.contains { $0.contains("RECENT_MEMORY") })
        #expect(!contextBuilt.metadata.values.contains { $0.contains("RECENT_MEMORY") })
    }

    @MainActor
    @Test func missingSelectedMemoryReferenceFailsSafelyWithoutBlockingProvider() async throws {
        let fixture = makeEngineFixture(
            policy: ContextMemoryRetrievalPolicy(
                maximumItemCount: 1,
                maximumCharacterCount: 80
            )
        )
        fixture.memoryService.missingIDs = [fixture.memoryService.references[0].id]

        let runId = try #require(await fixture.engine.startRun(goal: "Handle missing memory"))
        let run = try #require(fixture.runRepository.run(withId: runId))
        let retrieval = try #require(run.events.first {
            $0.type == .contextRetrievalFinished &&
                $0.metadata["retrievalKind"] == "projectMemory"
        })

        #expect(retrieval.metadata["status"] == "partial")
        #expect(retrieval.metadata["invalidReferenceCount"] == "1")
        #expect(retrieval.metadata["resolvedItemCount"] == "0")
        #expect(fixture.provider.requests.count == 1)
        #expect(!fixture.provider.requests[0].context.contains { $0.contains("RECENT_MEMORY") })
    }

    @MainActor
    @Test func contextBuilderPreservesResolvedMemoryIdentityAsSourceProvenance() throws {
        let project = Project(name: "Memory Project")
        let memory = MemoryItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000777")!,
            projectId: project.id,
            content: "Use MCP boundaries.",
            createdAt: Date(timeIntervalSince1970: 100)
        )

        let snapshot = try ContextBuilder().buildSnapshot(from: ContextBuildInput(
            runId: UUID(),
            agent: Agent(role: .coder, providerId: "test.provider", model: "test"),
            providerId: "test.provider",
            userMessage: "Continue",
            currentProject: project,
            memoryItems: [memory]
        ))
        let source = try #require(snapshot.sections.first {
            $0.kind == .projectMemory
        }?.sources.first)

        #expect(source.id == "memory:\(memory.id.uuidString)")
        #expect(source.informationClass == .persistentState)
        #expect(snapshot.includedMemories == [memory.content])
    }

    private func makeReference(
        projectId: UUID,
        suffix: Int,
        date: TimeInterval,
        characters: Int
    ) -> MemoryReference {
        MemoryReference(
            id: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", suffix))!,
            projectId: projectId,
            createdAt: Date(timeIntervalSince1970: date),
            contentCharacterCount: characters
        )
    }

    @MainActor
    private func makeEngineFixture(
        policy: ContextMemoryRetrievalPolicy
    ) -> MemoryRetrievalFixture {
        let projectRepository = InMemoryProjectRepository()
        let projectService = ProjectService(repository: projectRepository)
        let project = projectService.addProject(name: "Memory Project", rootPath: "/tmp/memory-project")
        let recent = MemoryItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000301")!,
            projectId: project.id,
            content: "RECENT_MEMORY",
            createdAt: Date(timeIntervalSince1970: 3)
        )
        let middle = MemoryItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000302")!,
            projectId: project.id,
            content: "MIDDLE_MEMORY",
            createdAt: Date(timeIntervalSince1970: 2)
        )
        let old = MemoryItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000303")!,
            projectId: project.id,
            content: "OLD_MEMORY",
            createdAt: Date(timeIntervalSince1970: 1)
        )
        let memoryService = RecordingMemoryService(
            projectId: project.id,
            items: [recent, middle, old]
        )
        let runRepository = InMemoryRunRepository()
        let provider = MemoryRecordingProvider()
        let settings = InMemoryAppSettingsService(
            defaultMaxInputTokens: 1_000,
            defaultMaxOutputTokens: 100
        )
        let engine = HarnessEngine(
            repository: runRepository,
            recorder: RunRecorder(repository: runRepository),
            providerService: ProviderService(
                registry: ProviderRegistry(providers: [provider]),
                appSettingsService: settings
            ),
            projectService: projectService,
            contextBuilder: ContextBuilder(),
            memoryService: memoryService,
            appSettingsService: settings,
            contextMemoryRetrievalPolicy: policy
        )
        return MemoryRetrievalFixture(
            engine: engine,
            runRepository: runRepository,
            provider: provider,
            memoryService: memoryService
        )
    }
}

@MainActor
private struct MemoryRetrievalFixture {
    var engine: HarnessEngine
    var runRepository: InMemoryRunRepository
    var provider: MemoryRecordingProvider
    var memoryService: RecordingMemoryService
}

@MainActor
private final class RecordingMemoryService: @MainActor MemoryServiceProtocol {
    let references: [MemoryReference]
    var missingIDs: Set<UUID> = []
    private(set) var requestedIDs: [UUID] = []
    private let projectId: UUID
    private let storedItems: [MemoryItem]

    init(projectId: UUID, items: [MemoryItem]) {
        self.projectId = projectId
        self.storedItems = items
        self.references = items.map {
            MemoryReference(
                id: $0.id,
                projectId: projectId,
                createdAt: $0.createdAt,
                contentCharacterCount: $0.content.count
            )
        }
    }

    func items(for projectId: UUID) -> [MemoryItem] {
        guard projectId == self.projectId else { return [] }
        return storedItems
    }

    func references(for projectId: UUID) -> [MemoryReference] {
        guard projectId == self.projectId else { return [] }
        return references
    }

    func items(withIDs ids: [UUID], for projectId: UUID) -> [MemoryItem] {
        guard projectId == self.projectId else { return [] }
        requestedIDs = ids
        let itemsByID = Dictionary(uniqueKeysWithValues: storedItems.map { ($0.id, $0) })
        return ids.compactMap { id in
            guard !missingIDs.contains(id) else { return nil }
            return itemsByID[id]
        }
    }

    func saveProjectMemory(content: String, projectId: UUID, runId: UUID?) throws -> MemoryItem {
        MemoryItem(projectId: projectId, content: content)
    }

    func removeMemory(id: UUID) {}
}

@MainActor
private final class MemoryRecordingProvider: AIProvider {
    let id = "memory.recording.provider"
    let displayName = "Memory Recording Provider"
    let capabilities = ProviderCapabilities(
        supportsStreaming: true,
        contextWindowTokens: 2_000,
        supportedModels: ["memory-test"]
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
