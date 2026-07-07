//
//  WorkHarnessTests.swift
//  WorkHarnessTests
//
//  Created by Максим Ламанский on 7.07.26.
//

import Testing
import Swinject
@testable import WorkHarness

struct WorkHarnessTests {

    @MainActor
    @Test func startingRunRecordsInitialEvents() async throws {
        let repository = InMemoryRunRepository()
        let recorder = RunRecorder(repository: repository)
        let engine = HarnessEngine(repository: repository, recorder: recorder, providerService: makeProviderService(TestAIProvider()))

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
        let engine = HarnessEngine(repository: repository, recorder: recorder, providerService: makeProviderService(FailingAIProvider()))

        _ = await engine.startRun(goal: "Exercise failure path")

        let eventTypes = repository.runs[0].events.map(\.type)
        #expect(repository.runs[0].status == .failed)
        #expect(eventTypes.contains(.providerRequestFailed))
        #expect(eventTypes.contains(.runFailed))
        #expect(!eventTypes.contains(.runCompleted))
    }

    @MainActor
    @Test func chatPageViewModelSubmitsDraftThroughEngine() async throws {
        let repository = InMemoryRunRepository()
        let recorder = RunRecorder(repository: repository)
        let engine = HarnessEngine(repository: repository, recorder: recorder, providerService: makeProviderService(TestAIProvider()))
        let runService = RunService(repository: repository, harnessEngine: engine)
        let viewModel = MainScreen.ChatPageViewModel(runService: runService)

        viewModel.draftMessage = "Build the first architecture slice"
        await viewModel.submitDraftAndWait()

        #expect(viewModel.draftMessage.isEmpty)
        #expect(viewModel.selectedRun != nil)
        #expect(viewModel.runs.first?.events.contains { $0.type == .assistantMessage } == true)
    }

    @MainActor
    @Test func runServiceStartsRunThroughEngineAndExposesRepositoryState() async throws {
        let repository = InMemoryRunRepository()
        let recorder = RunRecorder(repository: repository)
        let engine = HarnessEngine(repository: repository, recorder: recorder, providerService: makeProviderService(TestAIProvider()))
        let runService = RunService(repository: repository, harnessEngine: engine)

        let runId = try #require(await runService.startRun(goal: "Route through service"))
        let run = try #require(runService.run(withId: runId))

        #expect(runService.providerName == "Test Provider")
        #expect(runService.runs.count == 1)
        #expect(run.goal == "Route through service")
        #expect(run.events.contains { $0.type == .runCompleted })
    }

    @MainActor
    @Test func mainScreenRoutesSectionsThroughPages() async throws {
        let repository = InMemoryRunRepository()
        let recorder = RunRecorder(repository: repository)
        let engine = HarnessEngine(repository: repository, recorder: recorder, providerService: makeProviderService(TestAIProvider()))
        let runService = RunService(repository: repository, harnessEngine: engine)
        let chatPageViewModel = MainScreen.ChatPageViewModel(runService: runService)
        let runsPageViewModel = MainScreen.RunsPageViewModel(runService: runService)
        let screenModel = MainScreen.MainScreenViewModel(
            chatPageViewModel: chatPageViewModel,
            runsPageViewModel: runsPageViewModel
        )

        #expect(screenModel.pages.first is MainScreen.MainShellPage)
        #expect(screenModel.detailPage is MainScreen.ChatPage)

        screenModel.show(section: .runs)

        #expect(screenModel.detailPage is MainScreen.RunsPage)

        _ = await engine.startRun(goal: "Review navigation")
        let run = try #require(repository.runs.first)

        screenModel.selectRun(run)

        #expect(screenModel.selectedSection == .chat)
        #expect(screenModel.detailPage is MainScreen.ChatPage)
        #expect(chatPageViewModel.selectedRun?.id == run.id)
    }

    @MainActor
    @Test func swinjectContainerResolvesRegisteredAppGraph() async throws {
        let container = Container()
        container.registerDependencies()

        let firstRepository = try #require(container.resolve(RunRepository.self))
        let secondRepository = try #require(container.resolve(RunRepository.self))
        let providerService = try #require(container.resolve(ProviderServiceProtocol.self))
        let runService = try #require(container.resolve(RunServiceProtocol.self))
        let scene = try #require(container.resolve(AppSceneProtocol.self))
        let mainScreen = try #require(container.resolve(MainScreenProtocol.self))

        #expect(firstRepository.runs.isEmpty)
        #expect(firstRepository === secondRepository)
        #expect(providerService.activeProviderId == MockAIProvider.providerId)
        #expect(runService.runs.isEmpty)
        #expect(scene.viewModel.activeScreen != nil)
        #expect(mainScreen.pagesModel.pages.first is MainScreen.MainShellPage)
    }

    @MainActor
    @Test func providerRegistryStoresRegisteredProviders() async throws {
        let registry = ProviderRegistry(providers: [TestAIProvider(), AlternateAIProvider()])

        #expect(registry.availableProviders.map(\.id).sorted() == ["alternate.provider", "test.provider"])
        #expect(try registry.provider(id: "test.provider").displayName == "Test Provider")
    }

    @MainActor
    @Test func providerServiceSelectsActiveProvider() async throws {
        let providerService = ProviderService(
            registry: ProviderRegistry(providers: [TestAIProvider(), AlternateAIProvider()])
        )

        try providerService.selectProvider(id: "alternate.provider")

        #expect(providerService.activeProviderId == "alternate.provider")
        #expect(try providerService.activeProvider().displayName == "Alternate Provider")
    }

    @MainActor
    @Test func selectingMissingProviderThrowsProviderError() async throws {
        let providerService = ProviderService(registry: ProviderRegistry(providers: [TestAIProvider()]))

        do {
            try providerService.selectProvider(id: "missing.provider")
            Issue.record("Selecting a missing provider should throw.")
        } catch let error as ProviderError {
            #expect(error == .providerNotFound("missing.provider"))
        }
    }

    @MainActor
    @Test func providerServiceExposesCapabilities() async throws {
        let providerService = ProviderService(registry: ProviderRegistry(providers: [AlternateAIProvider()]))

        let capabilities = try providerService.capabilities(for: "alternate.provider")

        #expect(capabilities.supportsStreaming)
        #expect(capabilities.contextWindowTokens == 2_000)
        #expect(capabilities.supportedModels == ["alternate-model"])
    }

    @MainActor
    @Test func harnessEngineUsesActiveProviderWithoutConcreteProviderType() async throws {
        let repository = InMemoryRunRepository()
        let recorder = RunRecorder(repository: repository)
        let providerService = ProviderService(
            registry: ProviderRegistry(providers: [TestAIProvider(), AlternateAIProvider()])
        )
        try providerService.selectProvider(id: "alternate.provider")
        let engine = HarnessEngine(repository: repository, recorder: recorder, providerService: providerService)

        _ = await engine.startRun(goal: "Use active provider")

        let run = try #require(repository.runs.first)
        #expect(run.agents.first?.providerId == "alternate.provider")
        #expect(run.events.contains { $0.type == .assistantMessage && $0.message == "Hello from alternate provider." })
    }
}

@MainActor
private func makeProviderService(_ provider: any AIProvider) -> ProviderService {
    ProviderService(registry: ProviderRegistry(providers: [provider]))
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

private struct AlternateAIProvider: AIProvider {
    let id = "alternate.provider"
    let displayName = "Alternate Provider"
    let capabilities = ProviderCapabilities(
        supportsStreaming: true,
        contextWindowTokens: 2_000,
        supportedModels: ["alternate-model"]
    )

    func send(_ request: AIRequest) async throws -> AsyncThrowingStream<AIEvent, Error> {
        AsyncThrowingStream { continuation in
            continuation.yield(.started)
            continuation.yield(.messageCompleted("Hello from alternate provider."))
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
