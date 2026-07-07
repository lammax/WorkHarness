//
//  WorkHarnessTests.swift
//  WorkHarnessTests
//
//  Created by Максим Ламанский on 7.07.26.
//

import Testing
@testable import WorkHarness

struct WorkHarnessTests {

    @MainActor
    @Test func startingRunRecordsInitialEvents() async throws {
        let repository = InMemoryRunRepository()
        let recorder = RunRecorder(repository: repository)
        let engine = HarnessEngine(repository: repository, recorder: recorder, provider: TestAIProvider())

        _ = await engine.startRun(goal: "Create a harness run")

        #expect(repository.runs.count == 1)
        #expect(repository.runs[0].goal == "Create a harness run")
        #expect(repository.runs[0].events.map(\.type).contains(.runCreated))
        #expect(repository.runs[0].events.map(\.type).contains(.userMessage))
        #expect(repository.runs[0].events.map(\.type).contains(.providerStreamDelta))
        #expect(repository.runs[0].events.map(\.type).contains(.assistantMessage))
        #expect(repository.runs[0].events.map(\.type).contains(.runCompleted))
        #expect(repository.runs[0].status == .completed)
    }

    @MainActor
    @Test func providerErrorLeavesRunFailed() async throws {
        let repository = InMemoryRunRepository()
        let recorder = RunRecorder(repository: repository)
        let engine = HarnessEngine(repository: repository, recorder: recorder, provider: FailingAIProvider())

        _ = await engine.startRun(goal: "Exercise failure path")

        let eventTypes = repository.runs[0].events.map(\.type)
        #expect(repository.runs[0].status == .failed)
        #expect(eventTypes.contains(.providerRequestFailed))
        #expect(eventTypes.contains(.runFailed))
        #expect(!eventTypes.contains(.runCompleted))
    }

    @MainActor
    @Test func chatViewModelSubmitsDraftThroughEngine() async throws {
        let repository = InMemoryRunRepository()
        let recorder = RunRecorder(repository: repository)
        let engine = HarnessEngine(repository: repository, recorder: recorder, provider: TestAIProvider())
        let viewModel = ChatViewModel(repository: repository, harnessEngine: engine)

        viewModel.draftMessage = "Build the first architecture slice"
        await viewModel.submitDraftAndWait()

        #expect(viewModel.draftMessage.isEmpty)
        #expect(viewModel.selectedRun != nil)
        #expect(viewModel.runs.first?.events.contains { $0.type == .assistantMessage } == true)
    }
}

private struct TestAIProvider: AIProvider {
    let id = "test.provider"
    let displayName = "Test Provider"
    let capabilities = ProviderCapabilities(
        supportsStreaming: true,
        contextWindowTokens: 1_000,
        costModel: "test",
        supportedModels: ["test-model"]
    )

    func send(_ request: AIRequest) async throws -> AsyncThrowingStream<AIEvent, Error> {
        AsyncThrowingStream { continuation in
            continuation.yield(.started)
            continuation.yield(.messageDelta("Hello"))
            continuation.yield(.messageCompleted("Hello from test provider."))
            continuation.yield(.tokenUsage(TokenUsage(inputTokens: 3, outputTokens: 5)))
            continuation.yield(.finished)
            continuation.finish()
        }
    }
}

private struct FailingAIProvider: AIProvider {
    let id = "failing.provider"
    let displayName = "Failing Provider"
    let capabilities = ProviderCapabilities(supportsStreaming: true, supportedModels: ["failing-model"])

    func send(_ request: AIRequest) async throws -> AsyncThrowingStream<AIEvent, Error> {
        AsyncThrowingStream { continuation in
            continuation.yield(.started)
            continuation.yield(.error("Provider failed."))
            continuation.finish()
        }
    }
}
