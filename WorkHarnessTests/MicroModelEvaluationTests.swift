//
// MicroModelEvaluationTests.swift
// WorkHarnessTests
//
// Created by Auto (Codex) on 31.07.2026.
//

import Foundation
import Testing
@testable import WorkHarness

@Suite
struct MicroModelEvaluationTests {
    @MainActor
    @Test func validatorRequiresExactSchemaEnumsAndConfidenceRange() throws {
        let validator = MicroModelOutputValidator()
        let result = try validator.validate(
            #"{"category":"bug","confidence":0.9,"status":"OK"}"#
        )

        #expect(result == MicroModelClassification(category: .bug, confidence: 0.9, status: .ok))
        #expect(throws: MicroModelOutputValidationError.invalidSchema) {
            try validator.validate(
                #"{"category":"bug","confidence":0.9,"status":"OK","extra":true}"#
            )
        }
        #expect(throws: MicroModelOutputValidationError.invalidCategory) {
            try validator.validate(
                #"{"category":"other","confidence":0.9,"status":"OK"}"#
            )
        }
        #expect(throws: MicroModelOutputValidationError.invalidConfidence) {
            try validator.validate(
                #"{"category":"bug","confidence":1.2,"status":"OK"}"#
            )
        }
        #expect(throws: MicroModelOutputValidationError.invalidSchema) {
            try validator.validate(
                #"{"category":"bug","confidence":true,"status":"OK"}"#
            )
        }
        #expect(throws: MicroModelOutputValidationError.invalidJSON) {
            try validator.validate("```json\n{}\n```")
        }
    }

    @Test func fallbackPolicyCoversUnsureLowConfidenceAndInvalidOutput() {
        let policy = MicroModelFallbackPolicy(confidenceThreshold: 0.8)

        #expect(policy.reason(
            classification: MicroModelClassification(category: .bug, confidence: 0.8, status: .ok),
            validationError: nil
        ) == nil)
        #expect(policy.reason(
            classification: MicroModelClassification(category: .bug, confidence: 0.99, status: .unsure),
            validationError: nil
        ) == .statusUnsure)
        #expect(policy.reason(
            classification: MicroModelClassification(category: .bug, confidence: 0.79, status: .ok),
            validationError: nil
        ) == .lowConfidence)
        #expect(policy.reason(classification: nil, validationError: .invalidJSON) == .invalidFormat)
        #expect(policy.reason(classification: nil, validationError: .invalidCategory) == .invalidCategory)
    }

    @Test func catalogContainsTwentyFourBalancedFrozenCases() {
        let cases = MicroModelEvaluationCatalog.cases

        #expect(cases.count == 24)
        #expect(Set(cases.map(\.id)).count == 24)
        #expect(cases.filter { $0.group == "simple" }.count == 8)
        #expect(cases.filter { $0.group == "boundary" }.count == 8)
        #expect(cases.filter { $0.group == "complex" }.count == 8)
        #expect(Set(cases.map(\.expectedCategory)) == Set(TaskIntentCategory.allCases))
    }

    @MainActor
    @Test func evaluationUsesFallbackOnlyForUnsureOrInvalidMicroResults() async throws {
        let cases: [MicroModelEvaluationCase] = [
            .init(id: "T1", group: "simple", input: "Fix crash", expectedCategory: .bug),
            .init(id: "T2", group: "boundary", input: "Add screen", expectedCategory: .feature),
            .init(id: "T3", group: "complex", input: "Cover flow", expectedCategory: .tests)
        ]
        let runtime = ScriptedMicroModelRuntime(scripts: [
            .success(#"{"category":"bug","confidence":0.95,"status":"OK"}"#),
            .success(#"{"category":"feature","confidence":0.45,"status":"UNSURE"}"#),
            .success(#"{"category":"feature","confidence":0.93,"status":"OK"}"#),
            .success("not-json"),
            .success(#"{"category":"tests","confidence":0.91,"status":"OK"}"#)
        ])
        let fixture = makeFixture(runtime: runtime, cases: cases)

        let runId = try fixture.service.startEvaluation()
        await fixture.service.waitForCompletion(runId: runId)
        let run = try #require(fixture.repository.run(withId: runId))
        let summary = try #require(run.events.last { $0.type == .finalSummary })

        #expect(run.status == .completed)
        #expect(runtime.configuredModels == ["haiku", "haiku", "sonnet", "haiku", "sonnet"])
        #expect(Set(runtime.configuredRunIDs.compactMap { $0 }).count == 5)
        #expect(runtime.tasks.allSatisfy { $0.context == nil && $0.workingDirectory == nil })
        #expect(runtime.tasks[0].prompt.contains("Fix crash"))
        #expect(!runtime.tasks[1].prompt.contains("Fix crash"))
        #expect(summary.metadata["totalCases"] == "3")
        #expect(summary.metadata["microModelHandledCount"] == "1")
        #expect(summary.metadata["fallbackCount"] == "2")
        #expect(summary.metadata["largeModelCallCount"] == "2")
        #expect(summary.metadata["correctCount"] == "3")
        #expect(run.artifacts.map(\.kind).sorted() == [
            "day10-micro-model-report",
            "day10-micro-model-results"
        ])
        #expect(run.tokenUsage.inputTokens == 5)
        #expect(run.tokenUsage.outputTokens == 5)
    }

    @MainActor
    @Test func fullCatalogCanBeHandledWithoutAnyLargeModelCalls() async throws {
        let scripts = MicroModelEvaluationCatalog.cases.map { testCase in
            ScriptedMicroModelRuntime.Script.success(
                #"{"category":"\#(testCase.expectedCategory.rawValue)","confidence":0.95,"status":"OK"}"#
            )
        }
        let runtime = ScriptedMicroModelRuntime(scripts: scripts)
        let fixture = makeFixture(runtime: runtime, cases: MicroModelEvaluationCatalog.cases)

        let runId = try fixture.service.startEvaluation()
        await fixture.service.waitForCompletion(runId: runId)
        let run = try #require(fixture.repository.run(withId: runId))
        let summary = try #require(run.events.last { $0.type == .finalSummary })

        #expect(run.status == .completed)
        #expect(runtime.configuredModels == Array(repeating: "haiku", count: 24))
        #expect(summary.metadata["microModelHandledCount"] == "24")
        #expect(summary.metadata["fallbackCount"] == "0")
        #expect(summary.metadata["largeModelCallCount"] == "0")
        #expect(summary.metadata["correctCount"] == "24")
    }

    @MainActor
    @Test func runtimeFailureFailsRunAndRecordsProviderFailure() async throws {
        let runtime = ScriptedMicroModelRuntime(scripts: [.failure("quota exhausted")])
        let testCase = MicroModelEvaluationCase(
            id: "T1",
            group: "simple",
            input: "Fix crash",
            expectedCategory: .bug
        )
        let fixture = makeFixture(runtime: runtime, cases: [testCase])

        let runId = try fixture.service.startEvaluation()
        await fixture.service.waitForCompletion(runId: runId)
        let run = try #require(fixture.repository.run(withId: runId))

        #expect(run.status == .failed)
        #expect(run.events.contains { $0.type == .providerRequestFailed })
        #expect(run.events.last?.type == .runFailed)
        #expect(run.artifacts.isEmpty)
    }

    @MainActor
    @Test func chatCommandStartsEvaluationThroughServiceBoundary() async throws {
        let repository = InMemoryRunRepository()
        let engine = HarnessEngine(
            repository: repository,
            recorder: RunRecorder(repository: repository),
            providerService: ProviderService(
                registry: ProviderRegistry(providers: [ChatCommandProvider()]),
                appSettingsService: InMemoryAppSettingsService()
            )
        )
        let evaluationService = RecordingMicroModelEvaluationService()
        let viewModel = MainScreen.ChatPageViewModel(
            runService: RunService(repository: repository, harnessEngine: engine),
            contextAttachmentService: RunContextAttachmentService(),
            microModelEvaluationService: evaluationService
        )
        viewModel.draftMessage = "/micro-model evaluate"

        await viewModel.submitDraftAndWait()

        #expect(evaluationService.startCount == 1)
        #expect(viewModel.selectedRunId == evaluationService.runId)
        #expect(viewModel.errorMessage == nil)
        #expect(MicroModelEvaluationCommand.parse("/micro-model other") == nil)
    }

    @MainActor
    private func makeFixture(
        runtime: ScriptedMicroModelRuntime,
        cases: [MicroModelEvaluationCase]
    ) -> MicroModelFixture {
        let repository = InMemoryRunRepository()
        let recorder = RunRecorder(repository: repository)
        let registry = AgentRuntimeRegistry()
        registry.register(runtime)
        let artifactStore = RecordingMicroModelArtifactStore()
        let service = MicroModelEvaluationService(
            runRepository: repository,
            recorder: recorder,
            runtimeRegistry: registry,
            appSettingsService: InMemoryAppSettingsService(),
            artifactStore: artifactStore,
            cases: cases
        )
        return MicroModelFixture(
            service: service,
            repository: repository,
            artifactStore: artifactStore
        )
    }
}

@MainActor
private struct MicroModelFixture {
    var service: MicroModelEvaluationService
    var repository: InMemoryRunRepository
    var artifactStore: RecordingMicroModelArtifactStore
}

@MainActor
private final class ScriptedMicroModelRuntime: @MainActor AgentRuntime {
    enum Script {
        case success(String)
        case failure(String)
    }

    let id = "claude.cli"
    let displayName = "Scripted Claude"
    let descriptor = AgentRuntimeDescriptor(
        id: "claude.cli",
        displayName: "Scripted Claude",
        transport: .cli,
        modelOptions: [
            AgentRuntimeModelOption(id: "haiku", title: "Haiku"),
            AgentRuntimeModelOption(id: "sonnet", title: "Sonnet")
        ],
        defaultModelId: "haiku"
    )
    private var scripts: [Script]
    private var configuredModel: String?
    private var configuredRunID: UUID?
    private(set) var configuredModels: [String] = []
    private(set) var configuredRunIDs: [UUID?] = []
    private(set) var tasks: [AgentTask] = []

    init(scripts: [Script]) {
        self.scripts = scripts
    }

    func configure(modelId: String?) {
        configuredModel = modelId
    }

    func configure(modelId: String?, runId: UUID?, workingDirectory: String?) {
        configuredModel = modelId
        configuredRunID = runId
    }

    func connect() async throws -> AgentSession {
        AgentSession(agentId: id, state: .connected, capabilities: AgentCapabilities())
    }

    func disconnect(sessionId: UUID) async {}
    func capabilities(sessionId: UUID) -> AgentCapabilities? { AgentCapabilities() }

    func run(task: AgentTask, sessionId: UUID) async throws -> AgentExecution {
        tasks.append(task)
        configuredModels.append(configuredModel ?? "")
        configuredRunIDs.append(configuredRunID)
        let script = scripts.removeFirst()
        return AgentExecution(
            session: AgentSession(id: sessionId, agentId: id, state: .running),
            events: AsyncThrowingStream { continuation in
                continuation.yield(.started)
                switch script {
                case .success(let response):
                    continuation.yield(.tokenUsage(TokenUsage(
                        inputTokens: 1,
                        outputTokens: 1,
                        totalCostUSD: Decimal(string: "0.001")!
                    )))
                    continuation.yield(.messageCompleted(response))
                    continuation.yield(.finished(AgentResponse(message: response, artifacts: [])))
                case .failure(let message):
                    continuation.yield(.failed(message))
                }
                continuation.finish()
            }
        )
    }

    func cancel(sessionId: UUID) async {}
    func pause(sessionId: UUID) async throws {}
    func resume(sessionId: UUID) async throws {}
}

@MainActor
private final class RecordingMicroModelArtifactStore: @MainActor RunArtifactStoreProtocol {
    private(set) var contents: [String: String] = [:]

    func storeText(
        _ content: String,
        runId: UUID,
        sourceId: UUID,
        name: String,
        kind: String,
        projectRootPath: String?
    ) throws -> RunArtifact {
        contents[kind] = content
        return RunArtifact(name: name, kind: kind)
    }
}

@MainActor
private final class RecordingMicroModelEvaluationService: @MainActor MicroModelEvaluationServiceProtocol {
    let runId = UUID()
    private(set) var startCount = 0

    func startEvaluation() throws -> UUID {
        startCount += 1
        return runId
    }

    func waitForCompletion(runId: UUID) async {}
}

@MainActor
private final class ChatCommandProvider: AIProvider {
    let id = "chat.command.provider"
    let displayName = "Chat Command Provider"
    let capabilities = ProviderCapabilities(supportedModels: ["test"])

    func send(_ request: AIRequest) async throws -> AsyncThrowingStream<AIEvent, Error> {
        AsyncThrowingStream { continuation in continuation.finish() }
    }
}
