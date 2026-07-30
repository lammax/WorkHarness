//
// HarnessEngine.swift
// WorkHarness
//
// Created by Auto (Codex) on 07.07.2026.
//

import Foundation

@MainActor
final class HarnessEngine {
    private let repository: RunRepository
    private let recorder: RunRecorder
    private let providerService: ProviderServiceProtocol
    private let projectService: ProjectServiceProtocol?
    private let contextBuilder: ContextBuilderProtocol
    private let contextFoldingService: ContextFoldingServiceProtocol
    private let memoryService: MemoryServiceProtocol?
    private let ragService: RAGServiceProtocol?
    private let appSettingsService: AppSettingsServiceProtocol?
    private let agentModelRoutingService: AgentModelRoutingServiceProtocol?
    private let agentRuntimeRegistry: AgentRuntimeRegistry
    private let multiAgentCoordinator: MultiAgentCoordinator
    private var activeRuntimeSessions: [UUID: (runtime: AgentRuntime, sessionId: UUID)] = [:]

    init(
        repository: RunRepository,
        recorder: RunRecorder,
        providerService: ProviderServiceProtocol,
        projectService: ProjectServiceProtocol? = nil,
        contextBuilder: ContextBuilderProtocol? = nil,
        contextFoldingService: ContextFoldingServiceProtocol? = nil,
        memoryService: MemoryServiceProtocol? = nil,
        ragService: RAGServiceProtocol? = nil,
        appSettingsService: AppSettingsServiceProtocol? = nil,
        agentModelRoutingService: AgentModelRoutingServiceProtocol? = nil,
        agentRuntimeRegistry: AgentRuntimeRegistry? = nil,
        multiAgentCoordinator: MultiAgentCoordinator? = nil
    ) {
        self.repository = repository
        self.recorder = recorder
        self.providerService = providerService
        self.projectService = projectService
        self.contextBuilder = contextBuilder ?? ContextBuilder()
        self.contextFoldingService = contextFoldingService ?? ContextFoldingService()
        self.memoryService = memoryService
        self.ragService = ragService
        self.appSettingsService = appSettingsService
        self.agentModelRoutingService = agentModelRoutingService
        self.agentRuntimeRegistry = agentRuntimeRegistry ?? AgentRuntimeRegistry()
        self.multiAgentCoordinator = multiAgentCoordinator ?? MultiAgentCoordinator(repository: repository, recorder: recorder)
    }

    var providerName: String {
        providerService.activeProviderName
    }

    var selectedAgentRuntimeDescriptor: AgentRuntimeDescriptor? {
        selectedAgentRuntime()?.descriptor
    }

    func compactContext(runId: UUID) -> ContextFoldSummary? {
        guard let run = repository.run(withId: runId) else { return nil }
        let summary = contextFoldingService.fold(run: run)
        let encodedSummary = (try? JSONEncoder().encode(summary)).flatMap { String(data: $0, encoding: .utf8) }
        recorder.record(
            runId: runId,
            type: .contextCompacted,
            message: summary.renderedText,
            metadata: [
                "sourceEventCount": "\(summary.sourceEventCount)",
                "summaryJSON": encodedSummary ?? ""
            ]
        )
        return summary
    }

    func startRun(
        goal: String,
        contextAttachments: [RunContextAttachment] = []
    ) async -> UUID? {
        let trimmedGoal = goal.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedGoal.isEmpty else { return nil }

        if let runtime = selectedAgentRuntime() {
            return await startAgentRuntimeRun(
                goal: trimmedGoal,
                runtime: runtime,
                contextAttachments: contextAttachments
            )
        }

        let provider: any AIProvider
        do {
            provider = try providerService.activeProvider()
        } catch {
            return createFailedRun(
                goal: trimmedGoal,
                message: error.localizedDescription,
                contextAttachments: contextAttachments
            )
        }

        let agent = Agent(
            role: .coder,
            providerId: provider.id,
            model: provider.capabilities.supportedModels.first ?? "mock",
            contextPolicy: ContextPolicy(includeRAG: appSettingsService?.ragAnswerMode == .enabled)
        )
        let run = Run(
            projectId: projectService?.currentProject?.id,
            goal: trimmedGoal,
            agents: [agent],
            contextAttachments: contextAttachments,
            executionBackend: RunExecutionBackendSnapshot(
                kind: .provider,
                id: provider.id,
                displayName: provider.displayName,
                modelId: agent.model
            )
        )

        repository.insert(run)
        recorder.record(runId: run.id, type: .runCreated, message: trimmedGoal)
        recorder.record(runId: run.id, type: .agentStarted, message: "\(agent.role.label) started with \(provider.displayName).")
        recordUserMessage(
            runId: run.id,
            message: trimmedGoal,
            contextAttachments: contextAttachments
        )

        await runSimpleChatLoop(runId: run.id, prompt: trimmedGoal, agent: agent, provider: provider)
        return run.id
    }

    func startRun(goal: String, mode: RunMode) async -> UUID? {
        await startRun(goal: goal, mode: mode, configuration: .default)
    }

    func startRun(goal: String, mode: RunMode, configuration: MultiAgentRunConfiguration) async -> UUID? {
        await startRun(
            goal: goal,
            mode: mode,
            configuration: configuration,
            contextAttachments: []
        )
    }

    func startRun(
        goal: String,
        mode: RunMode,
        configuration: MultiAgentRunConfiguration,
        contextAttachments: [RunContextAttachment],
        progressMirrorRunId: UUID? = nil,
        progressMirrorMetadata: [String: String] = [:]
    ) async -> UUID? {
        guard mode == .multiAgent else {
            return await startRun(goal: goal, contextAttachments: contextAttachments)
        }
        return await startMultiAgentRun(
            goal: goal,
            configuration: configuration,
            contextAttachments: contextAttachments,
            progressMirrorRunId: progressMirrorRunId,
            progressMirrorMetadata: progressMirrorMetadata
        )
    }

    private func startMultiAgentRun(
        goal: String,
        configuration: MultiAgentRunConfiguration,
        contextAttachments: [RunContextAttachment],
        progressMirrorRunId: UUID?,
        progressMirrorMetadata: [String: String]
    ) async -> UUID? {
        guard let runtime = selectedAgentRuntime() else {
            return createFailedRun(
                goal: goal,
                message: "Select an ACP agent runtime before starting a multi-agent run.",
                contextAttachments: contextAttachments
            )
        }

        let modelId = selectedModelId(for: runtime)
        let agent = Agent(
            role: .coder,
            providerId: "agent-runtime:\(runtime.id)",
            model: modelId ?? runtime.displayName,
            contextPolicy: ContextPolicy(includeRAG: appSettingsService?.ragAnswerMode == .enabled)
        )
        let run = Run(
            projectId: projectService?.currentProject?.id,
            goal: goal,
            mode: .multiAgent,
            agents: [agent],
            contextAttachments: contextAttachments,
            multiAgentConfiguration: configuration,
            executionBackend: RunExecutionBackendSnapshot(
                kind: .agentRuntime,
                id: runtime.id,
                displayName: runtime.displayName,
                modelId: modelId
            )
        )
        repository.insert(run)
        if let progressMirrorRunId {
            let taskId = progressMirrorMetadata["taskId"]
            recorder.beginMirroringProgress(
                from: run.id,
                to: progressMirrorRunId,
                messagePrefix: taskId.map { "[\($0)] " } ?? "",
                metadata: progressMirrorMetadata
            )
        }
        defer {
            recorder.endMirroringProgress(from: run.id)
        }
        var runMetadata = ["mode": RunMode.multiAgent.rawValue]
        if let profileId = configuration.profileId {
            runMetadata["profileId"] = profileId
        }
        if let profileName = configuration.profileName {
            runMetadata["profileName"] = profileName
        }
        recorder.record(
            runId: run.id,
            type: .runCreated,
            message: goal,
            metadata: runMetadata
        )
        recordUserMessage(runId: run.id, message: goal, contextAttachments: contextAttachments)

        let candidate = AgentCandidate(
            agent: agent,
            capabilities: AgentCapabilities([
                .canPlan, .canEditFiles, .canUseTools, .canOpenDiff, .canRunTests
            ])
        )
        do {
            let plan = try CapabilityBasedAgentPlanner().plan(
                goal: goal,
                candidates: [candidate],
                configuration: configuration
            )
            let snapshot = context(
                for: run.id,
                prompt: goal,
                agent: agent,
                providerId: runtime.id,
                deliveryMode: runtime.descriptor.contextDeliveryMode
            )
            _ = try await multiAgentCoordinator.execute(
                plan: plan,
                candidates: [candidate],
                runtimes: [agent.id: runtime],
                runId: run.id,
                context: snapshot,
                workingDirectory: projectService?.currentProject?.rootPath,
                configuration: configuration
            )
            guard repository.run(withId: run.id)?.status != .cancelled else {
                return run.id
            }
            repository.updateRun(run.id) { $0.status = .completed }
            recorder.record(
                runId: run.id,
                type: .runCompleted,
                message: "Multi-agent run completed.",
                metadata: runMetadata.merging(["planId": plan.id.uuidString]) { _, new in new }
            )
            return run.id
        } catch {
            if repository.run(withId: run.id)?.status == .cancelled ||
                (error as? MultiAgentCoordinatorError) == .cancelled {
                return run.id
            }
            failRun(run.id, message: error.localizedDescription)
            return run.id
        }
    }

    func sendMessage(
        runId: UUID,
        message: String,
        contextAttachments: [RunContextAttachment] = []
    ) async {
        let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedMessage.isEmpty, let run = repository.run(withId: runId), let agent = run.agents.first else { return }

        if !contextAttachments.isEmpty {
            repository.updateRun(runId) { run in
                let attachedNames = Set(contextAttachments.map(\.name))
                run.contextAttachments.removeAll { attachedNames.contains($0.name) }
                run.contextAttachments.append(contentsOf: contextAttachments)
            }
        }

        if let runtime = runtime(for: agent) {
            recordUserMessage(
                runId: runId,
                message: trimmedMessage,
                contextAttachments: contextAttachments
            )
            repository.updateRun(runId) { run in
                run.status = .running
            }
            await runAgentRuntimeTask(runId: runId, prompt: trimmedMessage, agent: agent, runtime: runtime)
            return
        }

        let provider: any AIProvider

        do {
            provider = try providerService.activeProvider()
        } catch {
            failRun(runId, message: error.localizedDescription)
            return
        }

        recordUserMessage(
            runId: runId,
            message: trimmedMessage,
            contextAttachments: contextAttachments
        )
        repository.updateRun(runId) { run in
            run.status = .running
        }
        await runSimpleChatLoop(runId: runId, prompt: trimmedMessage, agent: agent, provider: provider)
    }

    func reconcileInterruptedRuns() {
        let recoverableRuns = repository.runs.filter {
            $0.status == .running || $0.status == .waitingForApproval
        }

        for run in recoverableRuns {
            let previousStatus = run.status
            repository.updateRun(run.id) { $0.status = .interrupted }
            recorder.record(
                runId: run.id,
                type: .runInterrupted,
                message: "Execution was interrupted because WorkHarness stopped before the Run finished.",
                metadata: [
                    "reason": "app-relaunch",
                    "previousStatus": previousStatus.rawValue
                ]
            )
        }
    }

    func resumeRun(runId: UUID) async -> Bool {
        guard let run = repository.run(withId: runId),
              run.status == .interrupted,
              let agent = run.agents.first else {
            return false
        }

        let prompt = recoveryPrompt(for: run)
        repository.updateRun(runId) { $0.status = .running }
        recorder.record(
            runId: runId,
            type: .runResumed,
            message: "Started a new agent session to recover the interrupted Run.",
            metadata: ["strategy": "workspace-and-event-recovery"]
        )

        if let runtime = runtime(for: agent) {
            await runAgentRuntimeTask(runId: runId, prompt: prompt, agent: agent, runtime: runtime)
            return repository.run(withId: runId)?.status == .completed
        }

        if agent.providerId.hasPrefix("agent-runtime:") {
            repository.updateRun(runId) { $0.status = .interrupted }
            recorder.record(
                runId: runId,
                type: .error,
                message: "The original agent runtime is unavailable. Select it in Settings and try Resume again.",
                metadata: ["runtimeId": String(agent.providerId.dropFirst("agent-runtime:".count))]
            )
            return false
        }

        do {
            let provider = try providerService.activeProvider()
            await runSimpleChatLoop(runId: runId, prompt: prompt, agent: agent, provider: provider)
            return repository.run(withId: runId)?.status == .completed
        } catch {
            repository.updateRun(runId) { $0.status = .interrupted }
            recorder.record(runId: runId, type: .error, message: error.localizedDescription)
            return false
        }
    }

    func restartRun(runId: UUID) async -> UUID? {
        guard let run = repository.run(withId: runId) else { return nil }

        let newRunId = await startRun(
            goal: run.goal,
            mode: run.mode,
            configuration: run.multiAgentConfiguration ?? .default,
            contextAttachments: run.contextAttachments
        )
        if let newRunId {
            recorder.record(
                runId: runId,
                type: .runRestarted,
                message: "Restarted as a new Run.",
                metadata: ["newRunId": newRunId.uuidString]
            )
        }
        return newRunId
    }

    func cancelRun(runId: UUID) async {
        guard let run = repository.run(withId: runId),
              run.status == .running ||
              run.status == .waitingForApproval ||
              run.status == .interrupted else { return }

        if let activeSession = activeRuntimeSessions[runId] {
            await activeSession.runtime.cancel(sessionId: activeSession.sessionId)
            activeRuntimeSessions.removeValue(forKey: runId)
        }
        await multiAgentCoordinator.cancel(runId: runId)
        repository.updateRun(runId) { $0.status = .cancelled }
        recorder.record(runId: runId, type: .runCancelled, message: "Run cancelled.", metadata: ["reason": "user-requested"])
    }

    private func recoveryPrompt(for run: Run) -> String {
        let recentEvents = run.events.suffix(20).map { event in
            let message = String(event.message.prefix(800))
            return "[\(event.type.label)] \(message)"
        }.joined(separator: "\n")

        return """
        WorkHarness recovery mode.

        The previous execution was interrupted when the desktop app stopped. Continue the same task in the current workspace; do not restart blindly or repeat completed edits.

        Original goal:
        \(run.goal)

        Saved recent Run events:
        \(recentEvents.isEmpty ? "No events were recorded." : recentEvents)

        Inspect the current files and git diff first, determine what was already completed, then continue from the safest unfinished point. Validate the final result and summarize what was recovered.
        """
    }

    private func runSimpleChatLoop(runId: UUID, prompt: String, agent: Agent, provider: any AIProvider) async {
        recorder.record(runId: runId, type: .providerRequestStarted, message: provider.displayName, metadata: ["providerId": provider.id, "agentId": agent.id.uuidString])

        do {
            let ragResults = await ragResults(for: prompt, agent: agent, runId: runId)
            let request = AIRequest(
                runId: runId,
                agent: agent,
                messages: [.init(role: .user, content: prompt)],
                context: context(
                    for: runId,
                    prompt: prompt,
                    agent: agent,
                    providerId: provider.id,
                    deliveryMode: .structuredMessages,
                    providerContextWindowTokens: provider.capabilities.contextWindowTokens,
                    ragResults: ragResults
                ).contextItems,
                tools: agent.tools,
                budget: defaultTokenBudget(for: agent)
            )
            let stream = try await provider.send(request)
            var completedMessage = ""

            for try await event in stream {
                guard repository.run(withId: runId)?.status != .cancelled else { return }
                switch event {
                case .started:
                    recorder.record(runId: runId, type: .providerRequestStarted, message: "Provider stream opened.", metadata: ["providerId": provider.id])
                case .messageDelta(let delta):
                    recorder.record(runId: runId, type: .providerStreamDelta, message: delta)
                case .messageCompleted(let message):
                    completedMessage = message
                    recorder.record(runId: runId, type: .assistantMessage, message: message)
                case .toolCall(let name, let input):
                    recorder.record(runId: runId, type: .toolCallRequested, message: name, metadata: ["input": input])
                case .tokenUsage(let usage):
                    repository.updateRun(runId) { run in
                        run.tokenUsage = usage
                        run.costUsage = CostUsage(totalUSD: usage.totalCostUSD)
                    }
                case .finished:
                    recorder.record(runId: runId, type: .providerRequestFinished, message: completedMessage.isEmpty ? "Provider finished." : completedMessage)
                case .error(let message):
                    recorder.record(runId: runId, type: .providerRequestFailed, message: message, metadata: ["providerId": provider.id])
                    failRun(runId, message: message)
                    return
                }
            }

            guard repository.run(withId: runId)?.status != .cancelled else { return }
            repository.updateRun(runId) { run in
                run.status = .completed
            }
            recorder.record(runId: runId, type: .agentFinished, message: "\(agent.role.label) finished.")
            recorder.record(runId: runId, type: .runCompleted, message: "Run completed.")
        } catch {
            failRun(runId, message: error.localizedDescription)
        }
    }

    private func context(
        for runId: UUID,
        prompt: String,
        agent: Agent,
        providerId: String,
        deliveryMode: ContextDeliveryMode,
        providerContextWindowTokens: Int? = nil,
        ragResults: [RAGCitation] = []
    ) -> ContextSnapshot {
        let currentProject = projectService?.currentProject
        let safetyMode = appSettingsService?.defaultSafetyMode ?? AppSettingsDefaults.defaultSafetyMode
        let contextAttachments = repository.run(withId: runId)?.contextAttachments ?? []
        let memoryItems = currentProjectMemory(for: currentProject)
        let snapshot = contextBuilder.buildSnapshot(from: ContextBuildInput(
            runId: runId,
            agent: agent,
            providerId: providerId,
            userMessage: prompt,
            currentProject: currentProject,
            rootPath: currentProject?.rootPath,
            contextFoldSummary: latestContextFoldSummary(for: runId),
            contextAttachments: contextAttachments,
            memoryItems: memoryItems,
            ragResults: ragResults,
            tokenBudget: defaultTokenBudget(for: agent),
            providerContextWindowTokens: providerContextWindowTokens,
            safetyMode: safetyMode,
            deliveryMode: deliveryMode
        ))

        let contextSourceCount = snapshot.sections.flatMap(\.sources).count +
            (snapshot.objectiveSource == nil ? 0 : 1)
        var metadata = [
            "contextSnapshotId": snapshot.id.uuidString,
            "providerId": providerId,
            "agentId": agent.id.uuidString,
            "tokenEstimate": "\(snapshot.tokenCount)",
            "contextItemCount": "\(snapshot.contextItems.count)",
            "contextSectionCount": "\(snapshot.sections.count)",
            "contextSourceCount": "\(contextSourceCount)",
            "contextSectionOrder": snapshot.sections.map(\.kind.rawValue).joined(separator: ","),
            "attachmentCount": "\(contextAttachments.count)",
            "memoryItemCount": "\(memoryItems.count)",
            "ragResultCount": "\(snapshot.includedRAGResults.count)",
            "summaryCount": "\(snapshot.includedSummaries.count)",
            "deliveryMode": snapshot.deliveryMode.rawValue,
            "safetyMode": safetyMode.rawValue
        ]
        if let configuredMaxInputTokens = snapshot.windowConstraint.configuredMaxInputTokens {
            metadata["configuredMaxInputTokens"] = "\(configuredMaxInputTokens)"
        }
        if let reservedOutputTokens = snapshot.windowConstraint.reservedOutputTokens {
            metadata["reservedOutputTokens"] = "\(reservedOutputTokens)"
        }
        if let providerContextWindowTokens = snapshot.windowConstraint.providerContextWindowTokens {
            metadata["providerContextWindowTokens"] = "\(providerContextWindowTokens)"
        }

        recorder.record(
            runId: runId,
            type: .contextBuilt,
            message: "Context prepared: \(snapshot.contextItems.count) item(s), estimated \(snapshot.tokenCount) tokens.",
            metadata: metadata
        )

        return snapshot
    }

    private func startAgentRuntimeRun(
        goal: String,
        runtime: AgentRuntime,
        contextAttachments: [RunContextAttachment]
    ) async -> UUID {
        let manualModelId = selectedModelId(for: runtime)
        let routingDecision = agentModelRoutingService?.decision(
            for: goal,
            runtime: runtime.descriptor,
            manualModelId: manualModelId
        ) ?? AgentModelRoutingDecision(
            selectedModelId: manualModelId,
            route: .manual,
            reason: "routing_unavailable",
            promptLength: goal.count,
            promptLengthThreshold: nil,
            matchedKeyword: nil
        )
        let modelId = routingDecision.selectedModelId
        let agent = Agent(
            role: .coder,
            providerId: "agent-runtime:\(runtime.id)",
            model: modelId ?? runtime.displayName,
            contextPolicy: ContextPolicy(includeRAG: appSettingsService?.ragAnswerMode == .enabled)
        )
        let run = Run(
            projectId: projectService?.currentProject?.id,
            goal: goal,
            mode: .codingLoop,
            agents: [agent],
            contextAttachments: contextAttachments,
            executionBackend: RunExecutionBackendSnapshot(
                kind: .agentRuntime,
                id: runtime.id,
                displayName: runtime.displayName,
                modelId: modelId
            )
        )
        repository.insert(run)
        recorder.record(runId: run.id, type: .runCreated, message: goal)
        recordModelRoutingDecision(routingDecision, runId: run.id, runtime: runtime)
        recordUserMessage(runId: run.id, message: goal, contextAttachments: contextAttachments)
        await runAgentRuntimeTask(runId: run.id, prompt: goal, agent: agent, runtime: runtime)
        return run.id
    }

    private func recordModelRoutingDecision(
        _ decision: AgentModelRoutingDecision,
        runId: UUID,
        runtime: AgentRuntime
    ) {
        guard decision.usesAutomaticRouting else { return }
        var metadata = [
            "runtimeId": runtime.id,
            "selectedModelId": decision.selectedModelId ?? "",
            "route": decision.route.rawValue,
            "reason": decision.reason,
            "promptLength": "\(decision.promptLength)"
        ]
        if let threshold = decision.promptLengthThreshold {
            metadata["promptLengthThreshold"] = "\(threshold)"
        }
        if let matchedKeyword = decision.matchedKeyword {
            metadata["matchedKeyword"] = matchedKeyword
        }
        recorder.record(
            runId: runId,
            type: .modelRoutingDecision,
            message: "Automatic routing selected \(decision.selectedModelId ?? runtime.displayName).",
            metadata: metadata
        )
    }

    private func runAgentRuntimeTask(runId: UUID, prompt: String, agent: Agent, runtime: AgentRuntime) async {
        do {
            let ragResults = await ragResults(for: prompt, agent: agent, runId: runId)
            let snapshot = context(
                for: runId,
                prompt: prompt,
                agent: agent,
                providerId: runtime.id,
                deliveryMode: runtime.descriptor.contextDeliveryMode,
                ragResults: ragResults
            )
            runtime.configure(
                modelId: capturedModelId(for: agent, runtime: runtime, runId: runId),
                runId: runId,
                workingDirectory: projectService?.currentProject?.rootPath
            )
            let session = try await runtime.connect()
            activeRuntimeSessions[runId] = (runtime, session.id)
            recorder.record(
                runId: runId,
                type: .agentStarted,
                message: "\(runtime.displayName) session started.",
                metadata: ["runtimeId": runtime.id, "sessionId": session.id.uuidString]
            )
            let execution = try await runtime.run(
                task: AgentTask(
                    runId: runId,
                    prompt: prompt,
                    context: snapshot,
                    workingDirectory: projectService?.currentProject?.rootPath
                ),
                sessionId: session.id
            )
            let mapper = ACPRunEventMapper(recorder: recorder)
            var assistantMessage = ""
            var hasStreamedText = false

            for try await event in execution.events {
                guard repository.run(withId: runId)?.status != .cancelled else { break }
                switch event {
                case .textDelta(let delta):
                    assistantMessage += delta
                    hasStreamedText = true
                    recorder.record(runId: runId, type: .providerStreamDelta, message: delta, metadata: ["source": "acp"])
                case .messageCompleted(let message):
                    assistantMessage = message
                case .tokenUsage(let usage):
                    mapper.record(runId: runId, event: event)
                    repository.updateRun(runId) { run in
                        run.tokenUsage = usage
                        run.costUsage = CostUsage(totalUSD: usage.totalCostUSD)
                    }
                case .finished(let response):
                    guard repository.run(withId: runId)?.status != .cancelled else { break }
                    if !assistantMessage.isEmpty && !hasStreamedText {
                        recorder.record(runId: runId, type: .assistantMessage, message: assistantMessage, metadata: ["source": "acp"])
                    }
                    mapper.record(runId: runId, event: event)
                    repository.updateRun(runId) { run in
                        run.status = .completed
                        if let usage = response.tokenUsage {
                            run.tokenUsage = usage
                            run.costUsage = CostUsage(totalUSD: usage.totalCostUSD)
                        }
                        run.artifacts.append(contentsOf: response.artifacts)
                    }
                case .failed(let message):
                    mapper.record(runId: runId, event: event)
                    failRun(runId, message: message)
                case .started, .thinking, .toolCallRequested, .fileChanged, .approvalRequested, .artifactCreated:
                    mapper.record(runId: runId, event: event)
                    break
                }
            }
            activeRuntimeSessions.removeValue(forKey: runId)
            if repository.run(withId: runId)?.status == .completed {
                recorder.record(runId: runId, type: .runCompleted, message: "Run completed through \(runtime.displayName).")
            }
            await runtime.disconnect(sessionId: session.id)
        } catch {
            activeRuntimeSessions.removeValue(forKey: runId)
            if repository.run(withId: runId)?.status != .cancelled {
                failRun(runId, message: error.localizedDescription)
            }
        }
    }

    private func selectedModelId(for runtime: AgentRuntime) -> String? {
        let descriptor = runtime.descriptor
        let savedModelId = appSettingsService?.agentModelId(for: runtime.id)
        guard !descriptor.modelOptions.isEmpty else {
            return savedModelId ?? descriptor.defaultModelId
        }
        if let savedModelId,
           descriptor.modelOptions.contains(where: { $0.id == savedModelId }) {
            return savedModelId
        }
        if let defaultModelId = descriptor.defaultModelId,
           descriptor.modelOptions.contains(where: { $0.id == defaultModelId }) {
            return defaultModelId
        }
        return descriptor.modelOptions.first?.id
    }

    private func capturedModelId(
        for agent: Agent,
        runtime: AgentRuntime,
        runId: UUID
    ) -> String? {
        if let modelId = repository.run(withId: runId)?.executionBackend?.modelId {
            return modelId
        }
        return runtime.descriptor.modelOptions.contains { $0.id == agent.model }
            ? agent.model
            : nil
    }

    private func selectedAgentRuntime() -> AgentRuntime? {
        guard let runtimeId = appSettingsService?.defaultAgentRuntimeId else { return nil }
        return agentRuntimeRegistry.runtime(id: runtimeId)
    }

    private func runtime(for agent: Agent) -> AgentRuntime? {
        let prefix = "agent-runtime:"
        guard agent.providerId.hasPrefix(prefix) else { return nil }
        return agentRuntimeRegistry.runtime(id: String(agent.providerId.dropFirst(prefix.count)))
    }

    private func ragResults(for prompt: String, agent: Agent, runId: UUID) async -> [RAGCitation] {
        guard agent.contextPolicy.includeRAG, let ragService else { return [] }
        do {
            return try await ragService.search(
                question: prompt,
                settings: appSettingsService?.ragRetrievalSettings ?? .default
            ).citations
        } catch {
            recorder.record(
                runId: runId,
                type: .toolCallFailed,
                message: error.localizedDescription,
                metadata: ["toolId": "rag.search"]
            )
            return []
        }
    }

    private func currentProjectMemory(for project: Project?) -> [String] {
        guard let project else { return [] }
        return memoryService?.items(for: project.id).map(\.content) ?? []
    }

    private func latestContextFoldSummary(for runId: UUID) -> ContextFoldSummary? {
        guard let event = repository.run(withId: runId)?.events.last(where: { $0.type == .contextCompacted }),
              let data = event.metadata["summaryJSON"]?.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(ContextFoldSummary.self, from: data)
    }

    private func defaultTokenBudget(for agent: Agent) -> TokenBudget {
        TokenBudget(
            maxInputTokens: appSettingsService?.defaultMaxInputTokens ?? agent.contextPolicy.maxInputTokens,
            maxOutputTokens: appSettingsService?.defaultMaxOutputTokens
        )
    }

    private func failRun(_ runId: UUID, message: String) {
        recorder.record(runId: runId, type: .error, message: message)
        repository.updateRun(runId) { run in
            run.status = .failed
        }
        recorder.record(runId: runId, type: .runFailed, message: message)
    }

    private func recordUserMessage(
        runId: UUID,
        message: String,
        contextAttachments: [RunContextAttachment]
    ) {
        var metadata: [String: String] = [:]
        if !contextAttachments.isEmpty {
            metadata["attachmentCount"] = "\(contextAttachments.count)"
            metadata["attachmentNames"] = contextAttachments.map(\.name).joined(separator: ", ")
        }
        recorder.record(runId: runId, type: .userMessage, message: message, metadata: metadata)
    }

    private func createFailedRun(
        goal: String,
        message: String,
        contextAttachments: [RunContextAttachment] = []
    ) -> UUID {
        let run = Run(
            projectId: projectService?.currentProject?.id,
            goal: goal,
            status: .failed,
            contextAttachments: contextAttachments
        )
        repository.insert(run)
        recorder.record(runId: run.id, type: .runCreated, message: goal)
        recorder.record(runId: run.id, type: .error, message: message)
        recorder.record(runId: run.id, type: .runFailed, message: message)
        return run.id
    }
}
