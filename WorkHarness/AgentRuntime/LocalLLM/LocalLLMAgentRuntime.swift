//
// LocalLLMAgentRuntime.swift
// WorkHarness
//
// Created by Auto (Codex) on 02.08.2026.
//

import Foundation

enum LocalLLMAgentRuntimeError: LocalizedError, Equatable {
    case sessionNotFound(UUID)
    case sessionAlreadyRunning(UUID)
    case invalidAction(String)
    case iterationLimitReached(Int)
    case providerFailed(String)
    case pauseUnsupported

    var errorDescription: String? {
        switch self {
        case .sessionNotFound(let id):
            "Local LLM session was not found: \(id.uuidString)"
        case .sessionAlreadyRunning(let id):
            "Local LLM session is already running: \(id.uuidString)"
        case .invalidAction(let value):
            "Local LLM returned an invalid structured action: \(value.prefix(240))"
        case .iterationLimitReached(let limit):
            "Local LLM reached the \(limit)-step tool-loop limit without a final answer."
        case .providerFailed(let message):
            "Local LLM inference failed: \(message)"
        case .pauseUnsupported:
            "Local LLM does not support pausing an active inference request."
        }
    }
}

@MainActor
final class LocalLLMAgentRuntime: AgentRuntime {
    static let runtimeId = "local-llm.mcp-agent"
    static let gatewayRuntimeId = "llm-gateway.mcp-agent"

    private struct RuntimeSession {
        var session: AgentSession
        var modelId: String
        var runId: UUID?
        var workingDirectory: String?
        var worker: Task<Void, Never>?
    }

    private struct ActionEnvelope: Decodable {
        enum Kind: String, Decodable {
            case tool
            case final
        }

        var type: Kind
        var toolId: String?
        var arguments: [String: String]?
        var content: String?
    }

    private struct InferenceResult {
        var content: String
        var usage: TokenUsage
    }

    private let providerClient: MCPProviderClientProtocol
    private let toolService: ToolServiceProtocol
    private let settingsService: AppSettingsServiceProtocol
    private let runtimeId: String
    private let runtimeDisplayName: String
    private let providerId: String
    private let defaultModelId: () -> String
    private let contextWindowTokens: Int
    private let maxIterations: Int
    private let maxHistoryCharacters: Int
    private var sessions: [UUID: RuntimeSession] = [:]
    private var configuredModelId: String?
    private var configuredRunId: UUID?
    private var configuredWorkingDirectory: String?

    init(
        providerClient: MCPProviderClientProtocol,
        toolService: ToolServiceProtocol,
        settingsService: AppSettingsServiceProtocol,
        maxIterations: Int = 12,
        maxHistoryCharacters: Int = 24_000
    ) {
        self.providerClient = providerClient
        self.toolService = toolService
        self.settingsService = settingsService
        self.runtimeId = Self.runtimeId
        self.runtimeDisplayName = "Local LLM Agent"
        self.providerId = MCPProviderDescriptor.localLLM.id
        self.defaultModelId = { settingsService.localLLMModel }
        self.contextWindowTokens = 16_384
        self.maxIterations = max(1, maxIterations)
        self.maxHistoryCharacters = max(4_000, maxHistoryCharacters)
    }

    init(
        gatewayProviderClient providerClient: MCPProviderClientProtocol,
        toolService: ToolServiceProtocol,
        settingsService: AppSettingsServiceProtocol,
        maxIterations: Int = 12,
        maxHistoryCharacters: Int = 24_000
    ) {
        self.providerClient = providerClient
        self.toolService = toolService
        self.settingsService = settingsService
        self.runtimeId = Self.gatewayRuntimeId
        self.runtimeDisplayName = "LLM Gateway Agent"
        self.providerId = MCPProviderDescriptor.llmGateway.id
        self.defaultModelId = {
            MCPProviderDescriptor.llmGateway.capabilities.supportedModels.first
                ?? "gpt-4.1-mini"
        }
        self.contextWindowTokens = MCPProviderDescriptor.llmGateway.capabilities.contextWindowTokens
            ?? 16_384
        self.maxIterations = max(1, maxIterations)
        self.maxHistoryCharacters = max(4_000, maxHistoryCharacters)
    }

    var id: String { runtimeId }
    var displayName: String { runtimeDisplayName }

    var descriptor: AgentRuntimeDescriptor {
        let modelId = defaultModelId()
        return AgentRuntimeDescriptor(
            id: id,
            displayName: displayName,
            transport: .mcp,
            modelOptions: [AgentRuntimeModelOption(id: modelId, title: modelId)],
            defaultModelId: modelId,
            contextDeliveryMode: .structuredMessages,
            capabilities: AgentCapabilities([
                .canEditFiles,
                .canSearch,
                .canPlan,
                .canUseTools,
                .canExecuteTerminal,
                .canReadGit,
                .canOpenDiff,
                .canRunTests
            ]),
            contextWindowTokens: contextWindowTokens,
            supportsUsageReporting: true,
            supportsCancellation: true
        )
    }

    func configure(modelId: String?) {
        configuredModelId = modelId
    }

    func configure(modelId: String?, runId: UUID?, workingDirectory: String?) {
        configuredModelId = modelId
        configuredRunId = runId
        configuredWorkingDirectory = workingDirectory
    }

    func connect() async throws -> AgentSession {
        let session = AgentSession(
            agentId: id,
            state: .connected,
            capabilities: descriptor.capabilities
        )
        sessions[session.id] = RuntimeSession(
            session: session,
            modelId: configuredModelId ?? defaultModelId(),
            runId: configuredRunId,
            workingDirectory: configuredWorkingDirectory,
            worker: nil
        )
        return session
    }

    func disconnect(sessionId: UUID) async {
        sessions[sessionId]?.worker?.cancel()
        sessions.removeValue(forKey: sessionId)
    }

    func capabilities(sessionId: UUID) -> AgentCapabilities? {
        sessions[sessionId]?.session.capabilities
    }

    func run(task: AgentTask, sessionId: UUID) async throws -> AgentExecution {
        guard var runtimeSession = sessions[sessionId] else {
            throw LocalLLMAgentRuntimeError.sessionNotFound(sessionId)
        }
        guard runtimeSession.worker == nil else {
            throw LocalLLMAgentRuntimeError.sessionAlreadyRunning(sessionId)
        }
        runtimeSession.runId = runtimeSession.runId ?? task.runId
        runtimeSession.workingDirectory = runtimeSession.workingDirectory ?? task.workingDirectory
        runtimeSession.session.state = .running
        sessions[sessionId] = runtimeSession

        let stream = AsyncThrowingStream<AgentEvent, Error> { continuation in
            let worker = Task { @MainActor [weak self] in
                guard let self else {
                    continuation.finish()
                    return
                }
                await self.performToolLoop(
                    task: task,
                    sessionId: sessionId,
                    continuation: continuation
                )
            }
            sessions[sessionId]?.worker = worker
        }
        return AgentExecution(session: runtimeSession.session, events: stream)
    }

    func cancel(sessionId: UUID) async {
        guard var runtimeSession = sessions[sessionId] else { return }
        runtimeSession.worker?.cancel()
        runtimeSession.worker = nil
        runtimeSession.session.state = .cancelled
        runtimeSession.session.finishedAt = Date()
        sessions[sessionId] = runtimeSession
    }

    func pause(sessionId: UUID) async throws {
        guard sessions[sessionId] != nil else {
            throw LocalLLMAgentRuntimeError.sessionNotFound(sessionId)
        }
        throw LocalLLMAgentRuntimeError.pauseUnsupported
    }

    func resume(sessionId: UUID) async throws {
        guard sessions[sessionId] != nil else {
            throw LocalLLMAgentRuntimeError.sessionNotFound(sessionId)
        }
    }

    private func performToolLoop(
        task: AgentTask,
        sessionId: UUID,
        continuation: AsyncThrowingStream<AgentEvent, Error>.Continuation
    ) async {
        guard let runtimeSession = sessions[sessionId] else {
            continuation.finish(throwing: LocalLLMAgentRuntimeError.sessionNotFound(sessionId))
            return
        }
        var messages = initialMessages(for: task)
        var totalUsage = TokenUsage()
        continuation.yield(.started)

        do {
            for iteration in 1...maxIterations {
                try Task.checkCancellation()
                let bounded = boundedHistory(messages)
                if bounded.wasCompacted {
                    continuation.yield(.thinking(
                        "MCP LLM history was compacted to the \(maxHistoryCharacters)-character runtime limit."
                    ))
                }
                messages = bounded.messages
                let inference = try await infer(
                    messages: messages,
                    task: task,
                    modelId: runtimeSession.modelId
                )
                totalUsage.inputTokens += inference.usage.inputTokens
                totalUsage.outputTokens += inference.usage.outputTokens
                let action = try decodeAction(inference.content)

                switch action.type {
                case .final:
                    guard let content = action.content?.trimmingCharacters(in: .whitespacesAndNewlines),
                          !content.isEmpty else {
                        throw LocalLLMAgentRuntimeError.invalidAction(inference.content)
                    }
                    continuation.yield(.messageCompleted(content))
                    continuation.yield(.tokenUsage(totalUsage))
                    continuation.yield(.finished(AgentResponse(
                        message: content,
                        tokenUsage: totalUsage,
                        artifacts: []
                    )))
                    finish(sessionId: sessionId, state: .completed, usage: totalUsage)
                    continuation.finish()
                    return
                case .tool:
                    guard let toolId = action.toolId,
                          let arguments = action.arguments else {
                        throw LocalLLMAgentRuntimeError.invalidAction(inference.content)
                    }
                    continuation.yield(.thinking("MCP LLM step \(iteration): \(toolId)"))
                    let result = try await toolService.executeAwaitingApproval(.init(
                        runId: task.runId,
                        toolId: toolId,
                        arguments: arguments,
                        projectRootPath: runtimeSession.workingDirectory
                    ))
                    messages.append(.init(role: .assistant, content: canonicalAction(action)))
                    messages.append(.init(
                        role: .tool,
                        content: "tool_id=\(toolId) status=\(result.status.rawValue)\n\(result.output)"
                    ))
                    if result.status != .succeeded {
                        messages.append(.init(
                            role: .user,
                            content: "The tool did not succeed. Recover safely or return a final explanation."
                        ))
                    }
                }
            }
            throw LocalLLMAgentRuntimeError.iterationLimitReached(maxIterations)
        } catch is CancellationError {
            finish(sessionId: sessionId, state: .cancelled, usage: totalUsage)
            continuation.finish()
        } catch {
            finish(sessionId: sessionId, state: .failed, usage: totalUsage)
            continuation.yield(.failed(error.localizedDescription))
            continuation.finish()
        }
    }

    private func infer(
        messages: [ProviderMessage],
        task: AgentTask,
        modelId: String
    ) async throws -> InferenceResult {
        let agent = Agent(
            role: .coder,
            providerId: providerId,
            model: modelId
        )
        let request = AIRequest(
            runId: task.runId,
            agent: agent,
            messages: messages,
            context: task.context?.contextItems ?? [],
            model: modelId,
            temperature: 0.1,
            budget: TokenBudget(maxInputTokens: 12_000, maxOutputTokens: 2_048),
            workingDirectory: task.workingDirectory,
            metadata: [
                "agentRuntimeId": id,
                "llmGatewayGuardMode": "block"
            ]
        )
        let stream = try await providerClient.streamEvents(for: .init(
            providerId: providerId,
            aiRequest: request
        ))
        var content = ""
        var usage = TokenUsage()
        for try await event in stream {
            switch event {
            case .messageDelta(let delta):
                content += delta
            case .messageCompleted(let message):
                content = message
            case .tokenUsage(let reported):
                usage = reported
            case .failed(let message):
                throw LocalLLMAgentRuntimeError.providerFailed(message)
            case .started, .finished:
                break
            }
        }
        return InferenceResult(content: content, usage: usage)
    }

    private func initialMessages(for task: AgentTask) -> [ProviderMessage] {
        [
            .init(role: .system, content: toolProtocolPrompt()),
            .init(role: .user, content: task.prompt)
        ]
    }

    private func toolProtocolPrompt() -> String {
        let tools = toolService.availableTools
            .filter { ["file.read", "file.write", "shell.run", "git.run", "rag.search"].contains($0.id) }
            .map { tool in
                let fields = tool.inputSchema.map {
                    "\($0.name)\($0.required ? " (required)" : ""): \($0.description)"
                }.joined(separator: "; ")
                return "- \(tool.id): \(tool.description) Inputs: \(fields)"
            }
            .joined(separator: "\n")
        return """
        You are an MCP-backed coding agent controlled by WorkHarness.
        Return exactly one compact JSON object per inference, without Markdown.
        To request a tool: {"type":"tool","toolId":"file.read","arguments":{"path":"README.md"}}
        To finish: {"type":"final","content":"concise verified result"}
        Never invent tool results. WorkHarness executes tools through MCP and approvals.
        Use narrow reads and avoid returning large file contents in the final answer.

        Available tools:
        \(tools)
        """
    }

    private func decodeAction(_ raw: String) throws -> ActionEnvelope {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let json: String
        if trimmed.hasPrefix("```") {
            json = trimmed
                .replacingOccurrences(of: #"^```(?:json)?\s*"#, with: "", options: .regularExpression)
                .replacingOccurrences(of: #"\s*```$"#, with: "", options: .regularExpression)
        } else {
            json = trimmed
        }
        guard let data = json.data(using: .utf8),
              let action = try? JSONDecoder().decode(ActionEnvelope.self, from: data) else {
            throw LocalLLMAgentRuntimeError.invalidAction(trimmed)
        }
        return action
    }

    private func canonicalAction(_ action: ActionEnvelope) -> String {
        guard action.type == .tool else { return "{\"type\":\"final\"}" }
        let arguments = (action.arguments ?? [:])
            .sorted { $0.key < $1.key }
            .map { key, value in
                "\"\(escaped(key))\":\"\(escaped(value))\""
            }
            .joined(separator: ",")
        return "{\"type\":\"tool\",\"toolId\":\"\(escaped(action.toolId ?? ""))\",\"arguments\":{\(arguments)}}"
    }

    private func escaped(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
    }

    private func boundedHistory(_ messages: [ProviderMessage]) -> (
        messages: [ProviderMessage],
        wasCompacted: Bool
    ) {
        let total = messages.map(\.content.count).reduce(0, +)
        guard total > maxHistoryCharacters, messages.count > 3 else {
            return (messages, false)
        }
        let fixed = Array(messages.prefix(2))
        var retained: [ProviderMessage] = []
        var retainedCharacters = fixed.map(\.content.count).reduce(0, +)
        for message in messages.dropFirst(2).reversed() {
            guard retainedCharacters + message.content.count <= maxHistoryCharacters else { continue }
            retained.insert(message, at: 0)
            retainedCharacters += message.content.count
        }
        let summary = ProviderMessage(
            role: .system,
            content: "Earlier consumed tool observations were discarded after exceeding the local runtime history limit. Re-read only the evidence still required."
        )
        return (fixed + [summary] + retained, true)
    }

    private func finish(
        sessionId: UUID,
        state: AgentSessionState,
        usage: TokenUsage
    ) {
        guard var runtimeSession = sessions[sessionId] else { return }
        runtimeSession.worker = nil
        runtimeSession.session.state = state
        runtimeSession.session.finishedAt = Date()
        runtimeSession.session.tokenUsage = usage
        sessions[sessionId] = runtimeSession
    }
}
