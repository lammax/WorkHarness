//
// ACPSubprocessClient.swift
// WorkHarness
//
// Created by Auto (Codex) on 10.07.2026.
//

import Foundation

@MainActor
final class ACPSubprocessClient: ACPClient {
    let id: String
    let displayName: String

    private let transport: ACPTransport
    private var connection: ACPConnection?
    private var sessions: [UUID: AgentSession] = [:]

    init(id: String, displayName: String, transport: ACPTransport) {
        self.id = id
        self.displayName = displayName
        self.transport = transport
    }

    func connect() async throws -> AgentSession {
        let connection = try await transport.connect()
        self.connection = connection

        let events = connection.events()
        try await connection.send(ACPMessage(
            id: 1,
            method: "initialize",
            params: [
                "protocolVersion": "2024-11-05",
                "clientName": "WorkHarness"
            ]
        ))

        for try await event in events {
            switch event {
            case .connected(let capabilities):
                let session = AgentSession(
                    agentId: id,
                    state: .connected,
                    capabilities: capabilities
                )
                sessions[session.id] = session
                return session
            case .failed(let message):
                throw ACPError.transport(message)
            case .started, .thinking, .textDelta, .messageCompleted, .toolCallRequested, .fileChanged, .approvalRequested, .tokenUsage, .artifactCreated, .finished:
                continue
            }
        }

        throw ACPError.transport("ACP agent closed before completing initialize handshake.")
    }

    func disconnect(sessionId: UUID) async {
        await connection?.close()
        connection = nil
        sessions.removeValue(forKey: sessionId)
    }

    func run(task: AgentTask, sessionId: UUID) async throws -> AsyncThrowingStream<ACPEvent, Error> {
        guard sessions[sessionId] != nil, let connection else {
            throw ACPError.sessionNotFound(sessionId)
        }

        let events = connection.events()
        try await connection.send(ACPMessage(
            id: 2,
            method: "session/run",
            params: [
                "sessionId": sessionId.uuidString,
                "taskId": task.id.uuidString,
                "prompt": task.prompt,
                "workingDirectory": task.workingDirectory ?? ""
            ]
        ))
        sessions[sessionId]?.state = .running
        return events
    }

    func cancel(sessionId: UUID) async {
        await sendControlMessage(method: "session/cancel", sessionId: sessionId)
        sessions[sessionId]?.state = .cancelled
    }

    func pause(sessionId: UUID) async throws {
        try await sendControlMessageOrThrow(method: "session/pause", sessionId: sessionId)
        sessions[sessionId]?.state = .paused
    }

    func resume(sessionId: UUID) async throws {
        try await sendControlMessageOrThrow(method: "session/resume", sessionId: sessionId)
        sessions[sessionId]?.state = .running
    }

    private func sendControlMessage(method: String, sessionId: UUID) async {
        try? await sendControlMessageOrThrow(method: method, sessionId: sessionId)
    }

    private func sendControlMessageOrThrow(method: String, sessionId: UUID) async throws {
        guard let connection else { throw ACPError.notConnected }
        try await connection.send(ACPMessage(
            id: 3,
            method: method,
            params: ["sessionId": sessionId.uuidString]
        ))
    }
}
