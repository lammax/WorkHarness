//
// MicroModelEvaluationService.swift
// WorkHarness
//
// Created by Auto (Codex) on 31.07.2026.
//

import Foundation

@MainActor
final class MicroModelEvaluationService: MicroModelEvaluationServiceProtocol {
    private struct RuntimeAttempt {
        var response: String
        var latencyMilliseconds: Int
        var tokenUsage: TokenUsage?
    }

    private let runRepository: RunRepository
    private let recorder: RunRecorder
    private let runtimeRegistry: AgentRuntimeRegistry
    private let projectService: ProjectServiceProtocol?
    private let appSettingsService: AppSettingsServiceProtocol?
    private let artifactStore: any RunArtifactStoreProtocol
    private let configuration: MicroModelEvaluationConfiguration
    private let cases: [MicroModelEvaluationCase]
    private let validator: MicroModelOutputValidator
    private let promptBuilder: MicroModelPromptBuilder
    private let reportWriter: MicroModelEvaluationReportWriter
    private var tasks: [UUID: Task<Void, Never>] = [:]

    init(
        runRepository: RunRepository,
        recorder: RunRecorder,
        runtimeRegistry: AgentRuntimeRegistry,
        projectService: ProjectServiceProtocol? = nil,
        appSettingsService: AppSettingsServiceProtocol? = nil,
        artifactStore: (any RunArtifactStoreProtocol)? = nil,
        configuration: MicroModelEvaluationConfiguration? = nil,
        cases: [MicroModelEvaluationCase]? = nil,
        validator: MicroModelOutputValidator? = nil,
        promptBuilder: MicroModelPromptBuilder? = nil,
        reportWriter: MicroModelEvaluationReportWriter? = nil
    ) {
        self.runRepository = runRepository
        self.recorder = recorder
        self.runtimeRegistry = runtimeRegistry
        self.projectService = projectService
        self.appSettingsService = appSettingsService
        self.artifactStore = artifactStore ?? FileRunArtifactStore()
        self.configuration = configuration ?? MicroModelEvaluationConfiguration()
        self.cases = cases ?? MicroModelEvaluationCatalog.cases
        self.validator = validator ?? MicroModelOutputValidator()
        self.promptBuilder = promptBuilder ?? MicroModelPromptBuilder()
        self.reportWriter = reportWriter ?? MicroModelEvaluationReportWriter()
    }

    func startEvaluation() throws -> UUID {
        guard let runtime = runtimeRegistry.runtime(id: configuration.runtimeId) else {
            throw MicroModelEvaluationServiceError.runtimeUnavailable(configuration.runtimeId)
        }
        let modelIDs = Set(runtime.descriptor.modelOptions.map(\.id))
        for modelId in [configuration.microModelId, configuration.fallbackModelId]
            where !modelIDs.contains(modelId) {
            throw MicroModelEvaluationServiceError.modelUnavailable(modelId)
        }

        let run = Run(
            projectId: projectService?.currentProject?.id,
            goal: "Day 10 micro-model evaluation (\(cases.count) cases)",
            mode: .inferenceEvaluation,
            agents: [Agent(
                role: .decisionMaker,
                providerId: "agent-runtime:\(runtime.id)",
                model: "\(configuration.microModelId) -> \(configuration.fallbackModelId)"
            )],
            executionBackend: RunExecutionBackendSnapshot(
                kind: .agentRuntime,
                id: runtime.id,
                displayName: runtime.displayName,
                modelId: "\(configuration.microModelId) -> \(configuration.fallbackModelId)"
            )
        )
        runRepository.insert(run)
        recorder.record(
            runId: run.id,
            type: .runCreated,
            message: run.goal,
            metadata: [
                "evaluation": "day10MicroModelFirst",
                "caseCount": "\(cases.count)",
                "microModelId": configuration.microModelId,
                "fallbackModelId": configuration.fallbackModelId,
                "confidenceThreshold": "\(configuration.confidenceThreshold)"
            ]
        )
        tasks = tasks.filter { runRepository.run(withId: $0.key)?.status == .running }
        tasks[run.id] = Task { [weak self] in
            await self?.execute(runId: run.id, runtime: runtime)
        }
        return run.id
    }

    func waitForCompletion(runId: UUID) async {
        await tasks[runId]?.value
        tasks.removeValue(forKey: runId)
    }

    private func execute(runId: UUID, runtime: AgentRuntime) async {
        let manualModelId = appSettingsService?.agentModelId(for: runtime.id)
        defer { runtime.configure(modelId: manualModelId, runId: nil, workingDirectory: nil) }
        do {
            var results: [MicroModelCaseResult] = []
            for (index, testCase) in cases.enumerated() {
                try Task.checkCancellation()
                guard runRepository.run(withId: runId)?.status == .running else { return }
                recorder.record(
                    runId: runId,
                    type: .agentStarted,
                    message: "Evaluating \(testCase.id) (\(index + 1)/\(cases.count)).",
                    metadata: ["caseId": testCase.id, "group": testCase.group]
                )
                let result = try await evaluate(testCase, runId: runId, runtime: runtime)
                results.append(result)
                recorder.record(
                    runId: runId,
                    type: .agentFinished,
                    message: "\(testCase.id) finished via \(result.handledByMicroModel ? "micro-model" : "fallback").",
                    metadata: [
                        "caseId": testCase.id,
                        "route": result.handledByMicroModel ? "micro" : "fallback",
                        "finalCategory": result.finalCategory?.rawValue ?? "unresolved",
                        "correct": "\(result.isCorrect)",
                        "latencyMs": "\(result.totalLatencyMilliseconds)"
                    ]
                )
            }
            let summary = MicroModelEvaluationSummary(
                runtimeId: runtime.id,
                microModelId: configuration.microModelId,
                fallbackModelId: configuration.fallbackModelId,
                confidenceThreshold: configuration.confidenceThreshold,
                results: results
            )
            try recordArtifacts(summary: summary, runId: runId)
            runRepository.updateRun(runId) { run in
                run.status = .completed
                run.tokenUsage = summary.totalTokenUsage
                run.costUsage = CostUsage(totalUSD: summary.totalTokenUsage.totalCostUSD)
            }
            recorder.record(
                runId: runId,
                type: .finalSummary,
                message: "Micro-model handled \(summary.microModelHandledCount)/\(summary.totalCases); fallback calls: \(summary.fallbackCount); average latency: \(summary.averageLatencyMilliseconds) ms.",
                metadata: summaryMetadata(summary)
            )
            recorder.record(runId: runId, type: .runCompleted, message: "Day 10 evaluation completed.")
        } catch is CancellationError {
            guard runRepository.run(withId: runId)?.status == .running else { return }
            runRepository.updateRun(runId) { $0.status = .cancelled }
            recorder.record(runId: runId, type: .runCancelled, message: "Day 10 evaluation cancelled.")
        } catch {
            runRepository.updateRun(runId) { $0.status = .failed }
            recorder.record(runId: runId, type: .error, message: error.localizedDescription)
            recorder.record(runId: runId, type: .runFailed, message: "Day 10 evaluation failed.")
        }
    }

    private func evaluate(
        _ testCase: MicroModelEvaluationCase,
        runId: UUID,
        runtime: AgentRuntime
    ) async throws -> MicroModelCaseResult {
        let microRuntimeResult = try await performAttempt(
            testCase: testCase,
            tier: "micro",
            modelId: configuration.microModelId,
            parentRunId: runId,
            runtime: runtime
        )
        let microValidation = validatedAttempt(
            microRuntimeResult,
            modelId: configuration.microModelId,
            testCase: testCase,
            runId: runId
        )
        let fallbackReason = MicroModelFallbackPolicy(
            confidenceThreshold: configuration.confidenceThreshold
        ).reason(
            classification: microValidation.result.classification,
            validationError: microValidation.error
        )
        recorder.record(
            runId: runId,
            type: .modelRoutingDecision,
            message: fallbackReason == nil
                ? "\(testCase.id) accepted the micro-model result."
                : "\(testCase.id) escalated to the fallback model.",
            metadata: [
                "caseId": testCase.id,
                "route": fallbackReason == nil ? "micro" : "fallback",
                "reason": fallbackReason?.rawValue ?? "confidenceAccepted",
                "confidence": microValidation.result.classification.map { "\($0.confidence)" } ?? "unavailable",
                "threshold": "\(configuration.confidenceThreshold)"
            ]
        )
        guard let fallbackReason else {
            return MicroModelCaseResult(
                id: testCase.id,
                group: testCase.group,
                expectedCategory: testCase.expectedCategory,
                finalCategory: microValidation.result.classification?.category,
                handledByMicroModel: true,
                fallbackReason: nil,
                microAttempt: microValidation.result,
                fallbackAttempt: nil
            )
        }

        let fallbackRuntimeResult = try await performAttempt(
            testCase: testCase,
            tier: "fallback",
            modelId: configuration.fallbackModelId,
            parentRunId: runId,
            runtime: runtime
        )
        let fallbackValidation = validatedAttempt(
            fallbackRuntimeResult,
            modelId: configuration.fallbackModelId,
            testCase: testCase,
            runId: runId
        )
        let fallbackClassification = fallbackValidation.result.classification
        let finalCategory = fallbackValidation.error == nil && fallbackClassification?.status == .ok
            ? fallbackClassification?.category
            : nil
        return MicroModelCaseResult(
            id: testCase.id,
            group: testCase.group,
            expectedCategory: testCase.expectedCategory,
            finalCategory: finalCategory,
            handledByMicroModel: false,
            fallbackReason: fallbackReason,
            microAttempt: microValidation.result,
            fallbackAttempt: fallbackValidation.result
        )
    }

    private func performAttempt(
        testCase: MicroModelEvaluationCase,
        tier: String,
        modelId: String,
        parentRunId: UUID,
        runtime: AgentRuntime
    ) async throws -> RuntimeAttempt {
        let attemptId = UUID()
        runtime.configure(modelId: modelId, runId: attemptId, workingDirectory: nil)
        let session = try await runtime.connect()
        recorder.record(
            runId: parentRunId,
            type: .providerRequestStarted,
            message: "\(testCase.id) started \(tier) inference with \(modelId).",
            metadata: ["caseId": testCase.id, "tier": tier, "modelId": modelId]
        )
        let startedAt = ProcessInfo.processInfo.systemUptime
        do {
            let execution = try await runtime.run(
                task: AgentTask(
                    runId: attemptId,
                    prompt: promptBuilder.prompt(for: testCase.input, tier: tier),
                    context: nil,
                    workingDirectory: nil
                ),
                sessionId: session.id
            )
            var streamedResponse = ""
            var completedResponse: String?
            var usage: TokenUsage?
            for try await event in execution.events {
                try Task.checkCancellation()
                switch event {
                case .textDelta(let delta):
                    appendBounded(delta, to: &streamedResponse)
                case .messageCompleted(let message):
                    completedResponse = bounded(message)
                case .tokenUsage(let reportedUsage):
                    usage = reportedUsage
                case .finished(let response):
                    if completedResponse == nil, !response.message.isEmpty {
                        completedResponse = bounded(response.message)
                    }
                    usage = response.tokenUsage ?? usage
                case .toolCallRequested:
                    throw MicroModelEvaluationServiceError.toolUseNotAllowed
                case .failed(let message):
                    throw MicroModelEvaluationServiceError.runtimeFailed(message)
                case .started, .thinking, .fileChanged, .approvalRequested, .artifactCreated:
                    break
                }
            }
            await runtime.disconnect(sessionId: session.id)
            let response = completedResponse ?? streamedResponse
            guard !response.isEmpty else { throw MicroModelEvaluationServiceError.missingResponse }
            let latency = elapsedMilliseconds(since: startedAt)
            recorder.record(
                runId: parentRunId,
                type: .providerRequestFinished,
                message: "\(testCase.id) finished \(tier) inference.",
                metadata: [
                    "caseId": testCase.id,
                    "tier": tier,
                    "modelId": modelId,
                    "latencyMs": "\(latency)",
                    "responseCharacterCount": "\(response.count)"
                ]
            )
            if let usage {
                recorder.record(
                    runId: parentRunId,
                    type: .usageUpdated,
                    message: "\(testCase.id) reported \(tier) usage.",
                    metadata: ContextUsageObservation.metadata(
                        usage: usage,
                        snapshot: nil,
                        providerId: runtime.id,
                        source: "microModelEvaluation",
                        additionalMetadata: ["caseId": testCase.id, "tier": tier, "modelId": modelId]
                    )
                )
            }
            return RuntimeAttempt(
                response: response,
                latencyMilliseconds: latency,
                tokenUsage: usage
            )
        } catch {
            await runtime.disconnect(sessionId: session.id)
            recorder.record(
                runId: parentRunId,
                type: .providerRequestFailed,
                message: "\(testCase.id) failed \(tier) inference.",
                metadata: ["caseId": testCase.id, "tier": tier, "modelId": modelId]
            )
            throw error
        }
    }

    private func validatedAttempt(
        _ attempt: RuntimeAttempt,
        modelId: String,
        testCase: MicroModelEvaluationCase,
        runId: UUID
    ) -> (result: MicroModelAttemptResult, error: MicroModelOutputValidationError?) {
        recorder.record(
            runId: runId,
            type: .validationStarted,
            message: "Validating \(testCase.id) output from \(modelId).",
            metadata: ["caseId": testCase.id, "modelId": modelId]
        )
        do {
            let classification = try validator.validate(attempt.response)
            recorder.record(
                runId: runId,
                type: .validationFinished,
                message: "\(testCase.id) produced valid structured output.",
                metadata: [
                    "caseId": testCase.id,
                    "modelId": modelId,
                    "status": classification.status.rawValue,
                    "category": classification.category.rawValue,
                    "confidence": "\(classification.confidence)"
                ]
            )
            return (MicroModelAttemptResult(
                modelId: modelId,
                classification: classification,
                validationError: nil,
                latencyMilliseconds: attempt.latencyMilliseconds,
                tokenUsage: attempt.tokenUsage
            ), nil)
        } catch let error as MicroModelOutputValidationError {
            recorder.record(
                runId: runId,
                type: .validationFinished,
                message: "\(testCase.id) produced invalid structured output.",
                metadata: [
                    "caseId": testCase.id,
                    "modelId": modelId,
                    "status": "invalid",
                    "reason": String(describing: error)
                ]
            )
            return (MicroModelAttemptResult(
                modelId: modelId,
                classification: nil,
                validationError: error.localizedDescription,
                latencyMilliseconds: attempt.latencyMilliseconds,
                tokenUsage: attempt.tokenUsage
            ), error)
        } catch {
            preconditionFailure("MicroModelOutputValidator returned an unsupported error type.")
        }
    }

    private func recordArtifacts(summary: MicroModelEvaluationSummary, runId: UUID) throws {
        let projectRoot = projectService?.currentProject?.rootPath
        let markdownArtifact = try artifactStore.storeText(
            reportWriter.markdown(for: summary),
            runId: runId,
            sourceId: UUID(),
            name: "day10-micro-model-report.md",
            kind: "day10-micro-model-report",
            projectRootPath: projectRoot
        )
        let jsonArtifact = try artifactStore.storeText(
            reportWriter.json(for: summary),
            runId: runId,
            sourceId: UUID(),
            name: "day10-micro-model-results.json",
            kind: "day10-micro-model-results",
            projectRootPath: projectRoot
        )
        for artifact in [markdownArtifact, jsonArtifact] {
            recorder.recordArtifact(runId: runId, artifact: artifact)
            recorder.record(
                runId: runId,
                type: .artifactCreated,
                message: artifact.name,
                metadata: ["artifactId": artifact.id.uuidString, "kind": artifact.kind]
            )
        }
    }

    private func summaryMetadata(_ summary: MicroModelEvaluationSummary) -> [String: String] {
        [
            "totalCases": "\(summary.totalCases)",
            "microModelHandledCount": "\(summary.microModelHandledCount)",
            "fallbackCount": "\(summary.fallbackCount)",
            "largeModelCallCount": "\(summary.largeModelCallCount)",
            "unresolvedCount": "\(summary.unresolvedCount)",
            "correctCount": "\(summary.correctCount)",
            "averageLatencyMs": "\(summary.averageLatencyMilliseconds)"
        ]
    }

    private func appendBounded(_ value: String, to result: inout String) {
        guard result.count < configuration.maximumResponseCharacters else { return }
        result += value.prefix(configuration.maximumResponseCharacters - result.count)
    }

    private func bounded(_ value: String) -> String {
        String(value.prefix(configuration.maximumResponseCharacters))
    }

    private func elapsedMilliseconds(since startedAt: TimeInterval) -> Int {
        Int(max(0, (ProcessInfo.processInfo.systemUptime - startedAt) * 1_000))
    }
}
