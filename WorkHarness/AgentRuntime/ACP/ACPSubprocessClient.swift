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
    private var workingDirectory: URL?
    private let approvalService: ApprovalServiceProtocol?
    private var connection: ACPConnection?
    private var sessions: [UUID: AgentSession] = [:]
    private var remoteSessionIDs: [UUID: String] = [:]
    private var modelId: String?
    private var runId: UUID?

    init(
        id: String,
        displayName: String,
        transport: ACPTransport,
        workingDirectory: URL? = nil,
        approvalService: ApprovalServiceProtocol? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.transport = transport
        self.workingDirectory = workingDirectory
        self.approvalService = approvalService
    }

    func configure(modelId: String?) {
        self.modelId = modelId
    }

    func configure(modelId: String?, runId: UUID?) {
        self.modelId = modelId
        self.runId = runId
    }

    func configure(modelId: String?, runId: UUID?, workingDirectory: String?) {
        self.modelId = modelId
        self.runId = runId
        self.workingDirectory = workingDirectory.map {
            URL(fileURLWithPath: $0, isDirectory: true)
        }
    }

    func connect() async throws -> AgentSession {
        let connection = try await transport.connect()
        self.connection = connection
        connection.setRequestHandler { [weak self, weak connection] requestId, method, params in
            Task { @MainActor in
                await self?.handleAgentRequest(
                    requestId: requestId,
                    method: method,
                    params: params,
                    connection: connection
                )
            }
        }

        let initializeResult = try await connection.request(method: "initialize", params: [
            "protocolVersion": 1,
            "clientCapabilities": [
                "fs": ["readTextFile": false, "writeTextFile": false],
                "terminal": false
            ],
            "clientInfo": ["name": "WorkHarness", "version": "0.1.0"]
        ])

        if let authMethods = initializeResult["authMethods"] as? [[String: Any]],
           authMethods.contains(where: { ($0["id"] as? String) == "cursor_login" }) {
            _ = try? await connection.request(method: "authenticate", params: ["methodId": "cursor_login"])
        }

        let sessionResult = try await connection.request(method: "session/new", params: [
            "cwd": workingDirectory?.path ?? FileManager.default.currentDirectoryPath,
            "mcpServers": []
        ])
        guard let remoteSessionID = sessionResult["sessionId"] as? String else {
            throw ACPError.transport("Cursor ACP did not return a sessionId.")
        }

        if let modelId {
            _ = try await connection.request(method: "session/set_config_option", params: [
                "sessionId": remoteSessionID,
                "configId": "model",
                "value": modelId
            ])
        }

        let capabilities = Self.capabilities(from: initializeResult["agentCapabilities"] as? [String: Any])
        let session = AgentSession(agentId: id, state: .connected, capabilities: capabilities)
        sessions[session.id] = session
        remoteSessionIDs[session.id] = remoteSessionID
        return session
    }

    func disconnect(sessionId: UUID) async {
        await connection?.close()
        connection = nil
        sessions.removeValue(forKey: sessionId)
        remoteSessionIDs.removeValue(forKey: sessionId)
    }

    func run(task: AgentTask, sessionId: UUID) async throws -> AsyncThrowingStream<ACPEvent, Error> {
        guard sessions[sessionId] != nil, let remoteSessionID = remoteSessionIDs[sessionId], let connection else {
            throw ACPError.sessionNotFound(sessionId)
        }

        let sourceEvents = connection.events()
        let events = AsyncThrowingStream<ACPEvent, Error> { continuation in
            Task { @MainActor in
                do {
                    for try await event in sourceEvents {
                        continuation.yield(event)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            Task { @MainActor in
                do {
                    let result = try await connection.request(method: "session/prompt", params: [
                        "sessionId": remoteSessionID,
                        "prompt": [["type": "text", "text": task.prompt]]
                    ])
                    let stopReason = result["stopReason"] as? String ?? "completed"
                    continuation.yield(.finished(AgentResponse(message: stopReason, tokenUsage: nil, artifacts: [])))
                    continuation.finish()
                } catch {
                    continuation.yield(.failed(error.localizedDescription))
                    continuation.finish(throwing: error)
                }
            }
        }
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
        guard let connection, let remoteSessionID = remoteSessionIDs[sessionId] else { throw ACPError.notConnected }
        _ = try await connection.request(method: method, params: ["sessionId": remoteSessionID])
    }

    private func handleAgentRequest(
        requestId: Int,
        method: String,
        params: [String: Any],
        connection: ACPConnection?
    ) async {
        guard let connection else { return }

        switch method {
        case "session/request_permission":
            let optionId = await permissionOptionId(params: params)
            try? await connection.respond(requestId: requestId, result: [
                "outcome": [
                    "outcome": "selected",
                    "optionId": optionId
                ]
            ])
        case "cursor/ask_question":
            try? await connection.respond(requestId: requestId, result: ["answers": []])
        case "cursor/create_plan":
            try? await connection.respond(requestId: requestId, result: [:])
        default:
            try? await connection.respond(requestId: requestId, result: [:])
        }
    }

    private func permissionOptionId(params: [String: Any]) async -> String {
        let options = params["options"] as? [[String: Any]] ?? []
        let allowOption = options.first(where: { option in
            let kind = (option["kind"] as? String ?? "").lowercased()
            let id = (option["optionId"] as? String ?? "").lowercased()
            return kind.contains("allow") || id.contains("allow")
        })?["optionId"] as? String ?? "allow-once"

        guard let approvalService, let runId else { return allowOption }
        do {
            let request = try approvalService.requestApproval(
                runId: runId,
                title: params["title"] as? String ?? "Approve Cursor action",
                summary: params["description"] as? String ?? "Cursor requested permission to continue.",
                mode: .askBeforeShell
            )
            let decision = await approvalService.waitForDecision(requestId: request.id)
            guard decision == .granted else {
                return options.first(where: { option in
                    let kind = (option["kind"] as? String ?? "").lowercased()
                    let id = (option["optionId"] as? String ?? "").lowercased()
                    return kind.contains("reject") || id.contains("reject")
                })?["optionId"] as? String ?? "reject-once"
            }
            return allowOption
        } catch {
            return options.first(where: { option in
                let kind = (option["kind"] as? String ?? "").lowercased()
                let id = (option["optionId"] as? String ?? "").lowercased()
                return kind.contains("reject") || id.contains("reject")
            })?["optionId"] as? String ?? "reject-once"
        }
    }

    private static func capabilities(from values: [String: Any]?) -> AgentCapabilities {
        guard let values else { return AgentCapabilities() }
        var capabilities: Set<AgentCapability> = [.canStreamTokens, .canUseTools]
        if values["promptCapabilities"] != nil { capabilities.insert(.canPlan) }
        if values["sessionCapabilities"] != nil { capabilities.insert(.canReadGit) }
        return AgentCapabilities(capabilities)
    }
}
