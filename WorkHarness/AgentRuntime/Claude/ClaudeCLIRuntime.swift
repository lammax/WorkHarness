//
// ClaudeCLIRuntime.swift
// WorkHarness
//
// Created by Auto (Codex) on 23.07.2026.
//

import Foundation

enum ClaudeCLIRuntimeError: LocalizedError, Equatable {
    case sessionNotFound(UUID)
    case sessionAlreadyRunning(UUID)
    case processFailed(String)
    case missingResult
    case pauseUnsupported

    var errorDescription: String? {
        switch self {
        case .sessionNotFound(let id):
            "Claude CLI session was not found: \(id.uuidString)"
        case .sessionAlreadyRunning(let id):
            "Claude CLI session is already running: \(id.uuidString)"
        case .processFailed(let message):
            "Claude CLI failed: \(message)"
        case .missingResult:
            "Claude CLI finished without a result event."
        case .pauseUnsupported:
            "Claude CLI does not support pausing an active request."
        }
    }
}

@MainActor
final class ClaudeCLIRuntime: AgentRuntime {
    static let runtimeId = "claude.cli"

    static let runtimeDescriptor = AgentRuntimeDescriptor(
        id: runtimeId,
        displayName: "Claude Code CLI",
        transport: .cli,
        authentication: .runtimeManaged,
        modelOptions: [
            AgentRuntimeModelOption(id: "haiku", title: "Haiku"),
            AgentRuntimeModelOption(id: "sonnet", title: "Sonnet"),
            AgentRuntimeModelOption(id: "opus", title: "Opus"),
            AgentRuntimeModelOption(id: "fable", title: "Fable")
        ],
        defaultModelId: "haiku",
        modelRouting: AgentModelRoutingDescriptor(
            defaultFastModelId: "haiku",
            defaultFallbackModelId: "sonnet",
            defaultPromptLengthThreshold: 240,
            fallbackKeywords: [
                "architecture",
                "authentication",
                "authorization",
                "concurrency",
                "credential",
                "migration",
                "security",
                "token",
                "архитектур",
                "аутентификац",
                "авторизац",
                "безопасност",
                "миграц",
                "токен"
            ],
            multipleRequirementsThreshold: 3
        ),
        capabilities: AgentCapabilities([
            .canEditFiles,
            .canSearch,
            .canPlan,
            .canUseTools,
            .canStreamTokens,
            .canExecuteTerminal,
            .canReadGit,
            .canRunTests,
            .canOpenDiff
        ])
    )

    let descriptor = runtimeDescriptor

    private struct RuntimeSession {
        var session: AgentSession
        var runId: UUID?
        var modelId: String?
        var process: CLIAgentProcessSession?
        var mcpConfigurationURL: URL?
    }

    private let executableURL: URL
    private let transport: CLIAgentProcessTransport
    private let mcpConfigurationFactory: ClaudeMCPConfigurationFactoryProtocol
    private var sessions: [UUID: RuntimeSession] = [:]
    private var continuationIdsByRunId: [UUID: String] = [:]
    private var configuredModelId: String?
    private var configuredRunId: UUID?

    init(
        executableURL: URL,
        transport: CLIAgentProcessTransport,
        mcpConfigurationFactory: ClaudeMCPConfigurationFactoryProtocol
    ) {
        self.executableURL = executableURL
        self.transport = transport
        self.mcpConfigurationFactory = mcpConfigurationFactory
    }

    convenience init(executableURL: URL) {
        self.init(
            executableURL: executableURL,
            transport: CLIAgentSubprocessTransport(),
            mcpConfigurationFactory: ClaudeMCPConfigurationFactory()
        )
    }

    convenience init(
        executableURL: URL,
        transport: CLIAgentProcessTransport
    ) {
        self.init(
            executableURL: executableURL,
            transport: transport,
            mcpConfigurationFactory: ClaudeMCPConfigurationFactory()
        )
    }

    var id: String { descriptor.id }
    var displayName: String { descriptor.displayName }

    func configure(modelId: String?) {
        configuredModelId = modelId
    }

    func configure(modelId: String?, runId: UUID?) {
        configuredModelId = modelId
        configuredRunId = runId
    }

    func connect() async throws -> AgentSession {
        let session = AgentSession(
            agentId: id,
            state: .connected,
            capabilities: descriptor.capabilities
        )
        sessions[session.id] = RuntimeSession(
            session: session,
            runId: configuredRunId,
            modelId: configuredModelId ?? descriptor.defaultModelId,
            process: nil,
            mcpConfigurationURL: nil
        )
        return session
    }

    func disconnect(sessionId: UUID) async {
        sessions[sessionId]?.process?.cancel()
        removeMCPConfiguration(sessionId: sessionId)
        sessions.removeValue(forKey: sessionId)
    }

    func capabilities(sessionId: UUID) -> AgentCapabilities? {
        sessions[sessionId]?.session.capabilities
    }

    func run(task: AgentTask, sessionId: UUID) async throws -> AgentExecution {
        guard var runtimeSession = sessions[sessionId] else {
            throw ClaudeCLIRuntimeError.sessionNotFound(sessionId)
        }
        guard runtimeSession.process == nil else {
            throw ClaudeCLIRuntimeError.sessionAlreadyRunning(sessionId)
        }

        runtimeSession.runId = runtimeSession.runId ?? task.runId
        runtimeSession.session.state = .running
        let mcpConfiguration = try mcpConfigurationFactory.makeConfiguration(
            runId: runtimeSession.runId ?? task.runId
        )
        runtimeSession.mcpConfigurationURL = mcpConfiguration.fileURL
        let configuration = processConfiguration(
            for: task,
            runtimeSession: runtimeSession,
            mcpConfiguration: mcpConfiguration
        )
        let process: CLIAgentProcessSession
        do {
            process = try transport.start(configuration)
        } catch {
            mcpConfigurationFactory.removeConfiguration(at: mcpConfiguration.fileURL)
            runtimeSession.mcpConfigurationURL = nil
            sessions[sessionId] = runtimeSession
            throw error
        }
        runtimeSession.process = process
        sessions[sessionId] = runtimeSession

        let events = makeEventStream(
            process: process,
            sessionId: sessionId,
            runId: runtimeSession.runId ?? task.runId
        )
        return AgentExecution(session: runtimeSession.session, events: events)
    }

    func cancel(sessionId: UUID) async {
        guard var runtimeSession = sessions[sessionId] else { return }
        runtimeSession.process?.cancel()
        runtimeSession.process = nil
        if let fileURL = runtimeSession.mcpConfigurationURL {
            mcpConfigurationFactory.removeConfiguration(at: fileURL)
            runtimeSession.mcpConfigurationURL = nil
        }
        runtimeSession.session.state = .cancelled
        runtimeSession.session.finishedAt = Date()
        sessions[sessionId] = runtimeSession
    }

    func pause(sessionId: UUID) async throws {
        guard sessions[sessionId] != nil else {
            throw ClaudeCLIRuntimeError.sessionNotFound(sessionId)
        }
        throw ClaudeCLIRuntimeError.pauseUnsupported
    }

    func resume(sessionId: UUID) async throws {
        guard sessions[sessionId] != nil else {
            throw ClaudeCLIRuntimeError.sessionNotFound(sessionId)
        }
    }

    private func processConfiguration(
        for task: AgentTask,
        runtimeSession: RuntimeSession,
        mcpConfiguration: ClaudeMCPRunConfiguration
    ) -> CLIAgentProcessConfiguration {
        var arguments = [
            "--print",
            "--verbose",
            "--output-format", "stream-json",
            "--include-partial-messages",
            "--strict-mcp-config",
            "--mcp-config", mcpConfiguration.fileURL.path,
            "--tools", "",
            "--allowedTools", "mcp__workharness__*",
            "--permission-mode", "dontAsk",
            "--disable-slash-commands",
            "--no-chrome"
        ]
        if let modelId = runtimeSession.modelId, !modelId.isEmpty {
            arguments += ["--model", modelId]
        }
        if let runId = runtimeSession.runId,
           let continuationId = continuationIdsByRunId[runId] {
            arguments += ["--resume", continuationId]
        }
        arguments.append(prompt(for: task))

        return CLIAgentProcessConfiguration(
            executableURL: executableURL,
            arguments: arguments,
            workingDirectoryURL: task.workingDirectory.map { URL(fileURLWithPath: $0) }
        )
    }

    private func prompt(for task: AgentTask) -> String {
        guard let context = task.context else { return task.prompt }
        var sections: [String] = []
        if !context.summary.isEmpty {
            sections.append("Run context:\n\(context.summary)")
        }
        if !context.contextItems.isEmpty {
            sections.append("Additional context:\n\(context.contextItems.joined(separator: "\n"))")
        }
        sections.append("Task:\n\(task.prompt)")
        return sections.joined(separator: "\n\n")
    }

    private func makeEventStream(
        process: CLIAgentProcessSession,
        sessionId: UUID,
        runId: UUID
    ) -> AsyncThrowingStream<AgentEvent, Error> {
        AsyncThrowingStream { continuation in
            Task { @MainActor in
                let parser = ClaudeStreamJSONParser()
                var standardError = ""
                var agentFailure: String?

                do {
                    for try await processEvent in process.events {
                        switch processEvent {
                        case .started:
                            break
                        case .stdout(let output):
                            let events = try parser.parse(output)
                            for event in events {
                                continuation.yield(event)
                                update(sessionId: sessionId, event: event)
                                if case .failed(let message) = event {
                                    agentFailure = message
                                }
                            }
                        case .stderr(let output):
                            standardError += output
                        case .finished(let exit):
                            for event in try parser.finish() {
                                continuation.yield(event)
                                update(sessionId: sessionId, event: event)
                                if case .failed(let message) = event {
                                    agentFailure = message
                                }
                            }
                            if let externalSessionId = parser.sessionId {
                                continuationIdsByRunId[runId] = externalSessionId
                            }
                            removeMCPConfiguration(sessionId: sessionId)
                            clearProcess(sessionId: sessionId)

                            if exit.status == .cancelled {
                                continuation.finish()
                            } else if let agentFailure {
                                continuation.finish(throwing: ClaudeCLIRuntimeError.processFailed(agentFailure))
                            } else if exit.status != .succeeded {
                                let message = standardError.trimmingCharacters(in: .whitespacesAndNewlines)
                                continuation.finish(throwing: ClaudeCLIRuntimeError.processFailed(
                                    message.isEmpty ? "Exit code \(exit.exitCode ?? -1)." : message
                                ))
                            } else if !parser.didReceiveResult {
                                continuation.finish(throwing: ClaudeCLIRuntimeError.missingResult)
                            } else {
                                continuation.finish()
                            }
                        }
                    }
                } catch {
                    removeMCPConfiguration(sessionId: sessionId)
                    clearProcess(sessionId: sessionId)
                    markFailed(sessionId: sessionId)
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { @Sendable _ in
                Task { @MainActor in
                    process.cancel()
                }
            }
        }
    }

    private func update(sessionId: UUID, event: AgentEvent) {
        guard var runtimeSession = sessions[sessionId] else { return }
        switch event {
        case .tokenUsage(let usage):
            runtimeSession.session.tokenUsage = usage
        case .artifactCreated(let artifact):
            runtimeSession.session.artifacts.append(artifact)
        case .finished(let response):
            runtimeSession.session.state = .completed
            runtimeSession.session.finishedAt = Date()
            runtimeSession.session.tokenUsage = response.tokenUsage ?? runtimeSession.session.tokenUsage
            runtimeSession.session.artifacts.append(contentsOf: response.artifacts)
        case .failed:
            runtimeSession.session.state = .failed
            runtimeSession.session.finishedAt = Date()
        case .started, .thinking, .textDelta, .messageCompleted, .toolCallRequested, .fileChanged, .approvalRequested:
            break
        }
        sessions[sessionId] = runtimeSession
    }

    private func clearProcess(sessionId: UUID) {
        sessions[sessionId]?.process = nil
    }

    private func removeMCPConfiguration(sessionId: UUID) {
        guard let fileURL = sessions[sessionId]?.mcpConfigurationURL else { return }
        mcpConfigurationFactory.removeConfiguration(at: fileURL)
        sessions[sessionId]?.mcpConfigurationURL = nil
    }

    private func markFailed(sessionId: UUID) {
        sessions[sessionId]?.session.state = .failed
        sessions[sessionId]?.session.finishedAt = Date()
    }
}
