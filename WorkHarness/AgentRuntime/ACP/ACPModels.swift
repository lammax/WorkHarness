//
// ACPModels.swift
// WorkHarness
//
// Created by Auto (Codex) on 10.07.2026.
//

import Foundation

struct ACPMessage: Codable, Equatable {
    var jsonrpc: String = "2.0"
    var id: Int
    var method: String
    var params: [String: String]
}

enum ACPEvent: Equatable {
    case connected(AgentCapabilities)
    case started
    case thinking(String)
    case textDelta(String)
    case messageCompleted(String)
    case toolCallRequested(name: String, input: String)
    case toolCallUpdated(name: String, input: String)
    case fileChanged(path: String)
    case approvalRequested(summary: String)
    case tokenUsage(TokenUsage)
    case artifactCreated(RunArtifact)
    case finished(AgentResponse)
    case failed(String)
}

enum ACPError: LocalizedError, Equatable {
    case notConnected
    case sessionNotFound(UUID)
    case unsupported(String)
    case transport(String)

    var errorDescription: String? {
        switch self {
        case .notConnected: "ACP client is not connected."
        case .sessionNotFound(let id): "ACP session was not found: \(id.uuidString)."
        case .unsupported(let message): "ACP operation is unsupported: \(message)"
        case .transport(let message): "ACP transport failed: \(message)"
        }
    }
}

@MainActor
protocol ACPTransport: AnyObject {
    func connect() async throws -> ACPConnection
}

@MainActor
protocol ACPConnection: AnyObject {
    func send(_ message: ACPMessage) async throws
    func request(method: String, params: [String: Any]) async throws -> [String: Any]
    func respond(requestId: Int, result: [String: Any]) async throws
    func setRequestHandler(_ handler: @escaping @MainActor (Int, String, [String: Any]) -> Void)
    func events() -> AsyncThrowingStream<ACPEvent, Error>
    func close() async
}

extension ACPConnection {
    func respond(requestId: Int, result: [String: Any]) async throws {}
    func setRequestHandler(_ handler: @escaping @MainActor (Int, String, [String: Any]) -> Void) {}
}

@MainActor
protocol ACPClient: AnyObject {
    var id: String { get }
    var displayName: String { get }
    func connect() async throws -> AgentSession
    func configure(modelId: String?)
    func disconnect(sessionId: UUID) async
    func run(task: AgentTask, sessionId: UUID) async throws -> AsyncThrowingStream<ACPEvent, Error>
    func cancel(sessionId: UUID) async
    func pause(sessionId: UUID) async throws
    func resume(sessionId: UUID) async throws
}
