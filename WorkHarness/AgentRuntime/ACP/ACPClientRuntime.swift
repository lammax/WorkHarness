//
// ACPClientRuntime.swift
// WorkHarness
//
// Created by Auto (Codex) on 10.07.2026.
//

import Foundation

@MainActor
final class ACPClientRuntime: AgentRuntime {
    private let client: ACPClient
    private var sessions: [UUID: AgentSession] = [:]
    let descriptor: AgentRuntimeDescriptor

    init(client: ACPClient, descriptor: AgentRuntimeDescriptor? = nil) {
        self.client = client
        self.descriptor = descriptor ?? AgentRuntimeDescriptor(
            id: client.id,
            displayName: client.displayName,
            transport: .acp
        )
    }

    var id: String { client.id }
    var displayName: String { client.displayName }

    func configure(modelId: String?) {
        client.configure(modelId: modelId)
    }

    func configure(modelId: String?, runId: UUID?) {
        client.configure(modelId: modelId, runId: runId)
    }

    func configure(modelId: String?, runId: UUID?, workingDirectory: String?) {
        client.configure(
            modelId: modelId,
            runId: runId,
            workingDirectory: workingDirectory
        )
    }

    func connect() async throws -> AgentSession {
        let session = try await client.connect()
        sessions[session.id] = session
        return session
    }

    func disconnect(sessionId: UUID) async {
        await client.disconnect(sessionId: sessionId)
        sessions.removeValue(forKey: sessionId)
    }

    func capabilities(sessionId: UUID) -> AgentCapabilities? {
        sessions[sessionId]?.capabilities
    }

    func run(task: AgentTask, sessionId: UUID) async throws -> AgentExecution {
        guard var session = sessions[sessionId] else {
            throw ACPError.sessionNotFound(sessionId)
        }

        session.state = .running
        sessions[sessionId] = session
        let stream = try await client.run(task: task, sessionId: sessionId)

        let mappedEvents = AsyncThrowingStream<AgentEvent, Error> { continuation in
            Task { @MainActor in
                do {
                    for try await event in stream {
                        let mapped = Self.map(event)
                        continuation.yield(mapped)
                        self.update(sessionId: sessionId, for: mapped)
                    }
                    continuation.finish()
                } catch {
                    self.update(sessionId: sessionId, for: .failed(error.localizedDescription))
                    continuation.finish(throwing: error)
                }
            }
        }

        return AgentExecution(session: session, events: mappedEvents)
    }

    func cancel(sessionId: UUID) async {
        await client.cancel(sessionId: sessionId)
        sessions[sessionId]?.state = .cancelled
    }

    func pause(sessionId: UUID) async throws {
        try await client.pause(sessionId: sessionId)
        sessions[sessionId]?.state = .paused
    }

    func resume(sessionId: UUID) async throws {
        try await client.resume(sessionId: sessionId)
        sessions[sessionId]?.state = .running
    }

    private func update(sessionId: UUID, for event: AgentEvent) {
        guard var session = sessions[sessionId] else { return }
        switch event {
        case .tokenUsage(let usage):
            session.tokenUsage = usage
        case .artifactCreated(let artifact):
            session.artifacts.append(artifact)
        case .finished(let response):
            session.state = .completed
            session.finishedAt = Date()
            session.tokenUsage = response.tokenUsage ?? session.tokenUsage
            session.artifacts.append(contentsOf: response.artifacts)
        case .failed:
            session.state = .failed
            session.finishedAt = Date()
        case .started, .thinking, .textDelta, .messageCompleted, .toolCallRequested, .fileChanged, .approvalRequested:
            break
        }
        sessions[sessionId] = session
    }

    private static func map(_ event: ACPEvent) -> AgentEvent {
        switch event {
        case .connected:
            .started
        case .started:
            .started
        case .thinking(let text):
            .thinking(text)
        case .textDelta(let text):
            .textDelta(text)
        case .messageCompleted(let message):
            .messageCompleted(message)
        case .toolCallRequested(let name, let input):
            .toolCallRequested(name: name, input: input)
        case .toolCallUpdated:
            .thinking("")
        case .fileChanged(let path):
            .fileChanged(path: path)
        case .approvalRequested(let summary):
            .approvalRequested(summary: summary)
        case .tokenUsage(let usage):
            .tokenUsage(usage)
        case .artifactCreated(let artifact):
            .artifactCreated(artifact)
        case .finished(let response):
            .finished(response)
        case .failed(let message):
            .failed(message)
        }
    }
}

@MainActor
final class ACPRunEventMapper {
    private let recorder: RunRecorder

    init(recorder: RunRecorder) {
        self.recorder = recorder
    }

    func record(runId: UUID, event: AgentEvent) {
        switch event {
        case .started:
            recorder.record(runId: runId, type: .agentStarted, message: "ACP agent started.")
        case .thinking(let message):
            recorder.record(runId: runId, type: .providerStreamDelta, message: message, metadata: ["source": "acp"])
        case .textDelta(let delta):
            recorder.record(runId: runId, type: .providerStreamDelta, message: delta, metadata: ["source": "acp"])
        case .messageCompleted(let message):
            recorder.record(runId: runId, type: .assistantMessage, message: message, metadata: ["source": "acp"])
        case .toolCallRequested(let name, let input):
            recorder.record(runId: runId, type: .toolCallRequested, message: name, metadata: ["input": input, "source": "acp"])
        case .fileChanged(let path):
            recorder.record(runId: runId, type: .fileChanged, message: path, metadata: ["source": "acp"])
        case .approvalRequested(let summary):
            recorder.record(runId: runId, type: .approvalRequested, message: summary, metadata: ["source": "acp"])
        case .tokenUsage(let usage):
            recorder.record(runId: runId, type: .providerRequestFinished, message: "ACP token usage updated.", metadata: [
                "inputTokens": "\(usage.inputTokens)",
                "outputTokens": "\(usage.outputTokens)",
                "source": "acp"
            ])
        case .artifactCreated(let artifact):
            recorder.record(runId: runId, type: .finalSummary, message: artifact.name, metadata: ["artifactKind": artifact.kind, "source": "acp"])
        case .finished(let response):
            recorder.record(runId: runId, type: .agentFinished, message: response.message, metadata: ["source": "acp"])
        case .failed(let message):
            recorder.record(runId: runId, type: .runFailed, message: message, metadata: ["source": "acp"])
        }
    }
}
