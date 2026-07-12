//
// RemoteControlService.swift
// WorkHarness
//
// Created by Auto (Codex) on 10.07.2026.
//

import Foundation
import Network

@MainActor
protocol RemoteControlServiceProtocol: BaseServiceProtocol {
    var isRunning: Bool { get }
    var port: UInt16 { get }
    func start() throws
    func stop()
    func reload() throws
}

@MainActor
final class RemoteControlService: RemoteControlServiceProtocol {
    private let runRepository: RunRepository
    private let runService: RunServiceProtocol
    private let projectService: ProjectServiceProtocol
    private let approvalService: ApprovalServiceProtocol
    private let appSettingsService: AppSettingsServiceProtocol
    private var listener: NWListener
    private var token: String

    private(set) var isRunning = false
    private(set) var port: UInt16

    init(
        runRepository: RunRepository,
        runService: RunServiceProtocol,
        projectService: ProjectServiceProtocol,
        approvalService: ApprovalServiceProtocol,
        appSettingsService: AppSettingsServiceProtocol,
        port: UInt16? = nil,
        token: String? = nil
    ) {
        self.runRepository = runRepository
        self.runService = runService
        self.projectService = projectService
        self.approvalService = approvalService
        self.appSettingsService = appSettingsService
        self.port = port ?? UInt16(clamping: appSettingsService.remoteControlPort)
        self.token = token ?? RemoteControlService.token(from: appSettingsService.remoteControlToken)
        if appSettingsService.remoteControlToken.isEmpty {
            appSettingsService.remoteControlToken = self.token
        }
        self.listener = Self.makeListener(port: self.port)
        configureListener()
    }

    var service: AppService { .remoteControl }

    func start() throws {
        guard appSettingsService.remoteControlEnabled, !isRunning else { return }
        listener.stateUpdateHandler = { [weak self] state in
            Task { @MainActor [weak self] in
                self?.isRunning = state == .ready
            }
        }
        listener.newConnectionHandler = { [weak self] connection in
            connection.start(queue: .main)
            Task { @MainActor [weak self] in
                self?.receive(on: connection)
            }
        }
        listener.start(queue: .main)
    }

    func reload() throws {
        stop()
        port = UInt16(clamping: appSettingsService.remoteControlPort)
        token = Self.token(from: appSettingsService.remoteControlToken)
        if appSettingsService.remoteControlToken.isEmpty {
            appSettingsService.remoteControlToken = token
        }
        listener = Self.makeListener(port: port)
        configureListener()
        try start()
    }

    func stop() {
        listener.cancel()
        isRunning = false
    }

    private func receive(on connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self, weak connection] data, _, _, _ in
            guard let data, let connection else { return }
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let runId = self.streamRunID(from: data) {
                    self.startEventStream(runId: runId, on: connection)
                    return
                }
                let response = self.handle(data: data)
                connection.send(content: response, completion: .contentProcessed { _ in
                    connection.cancel()
                })
            }
        }
    }

    private func configureListener() {
        if !appSettingsService.remoteControlAllowLAN {
            listener.parameters.requiredInterfaceType = .loopback
        }
        listener.parameters.allowLocalEndpointReuse = true
    }

    private func streamRunID(from data: Data) -> UUID? {
        guard let request = String(data: data, encoding: .utf8),
              let requestLine = request.split(separator: "\r\n", omittingEmptySubsequences: false).first,
              requestLine.hasPrefix("GET "),
              request.contains("\r\nAuthorization: Bearer \(token)\r\n") || request.contains("\r\nauthorization: Bearer \(token)\r\n") else { return nil }
        let path = requestLine.split(separator: " ").dropFirst().first.map(String.init) ?? ""
        let components = path.split(separator: "/").map(String.init)
        guard components.count == 3, components[0] == "runs", components[2] == "stream" else { return nil }
        return UUID(uuidString: components[1])
    }

    private func startEventStream(runId: UUID, on connection: NWConnection) {
        guard runRepository.run(withId: runId) != nil else {
            connection.send(content: HTTPResponse.json(status: 404, body: ["error": "Run not found"]), completion: .contentProcessed { _ in
                connection.cancel()
            })
            return
        }

        let header = Data("HTTP/1.1 200 OK\r\nContent-Type: text/event-stream\r\nCache-Control: no-cache\r\nConnection: keep-alive\r\n\r\n".utf8)
        connection.send(content: header, completion: .contentProcessed { [weak self, weak connection] _ in
            guard let connection else { return }
            Task { @MainActor [weak self] in
                await self?.pumpEventStream(runId: runId, on: connection)
            }
        })
    }

    private func pumpEventStream(runId: UUID, on connection: NWConnection) async {
        var sentEventCount = 0
        while !Task.isCancelled {
            guard let run = runRepository.run(withId: runId) else { break }
            let newEvents = run.events.dropFirst(sentEventCount)
            for event in newEvents {
                guard let payload = try? JSONEncoder().encode(event),
                      let json = String(data: payload, encoding: .utf8) else { continue }
                connection.send(content: Data("data: \(json)\n\n".utf8), completion: .contentProcessed { _ in })
                sentEventCount += 1
            }
            if [.completed, .failed, .cancelled].contains(run.status) {
                connection.send(content: Data("event: done\ndata: {\"status\":\"\(run.status.rawValue)\"}\n\n".utf8), completion: .contentProcessed { _ in
                    connection.cancel()
                })
                return
            }
            try? await Task.sleep(nanoseconds: 250_000_000)
        }
        connection.cancel()
    }

    private func handle(data: Data) -> Data {
        guard let request = String(data: data, encoding: .utf8),
              let requestLine = request.split(separator: "\r\n", omittingEmptySubsequences: false).first else {
            return HTTPResponse.badRequest
        }

        let lines = request.split(separator: "\r\n", omittingEmptySubsequences: false).map(String.init)
        let headerLines = lines.dropFirst().prefix { !$0.isEmpty }
        let headers = Dictionary(uniqueKeysWithValues: headerLines.compactMap { line -> (String, String)? in
            let parts = line.split(separator: ":", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { return nil }
            return (parts[0].lowercased(), parts[1].trimmingCharacters(in: .whitespaces))
        })

        guard headers["authorization"] == "Bearer \(token)" else {
            return HTTPResponse.json(status: 401, body: ["error": "Unauthorized"])
        }

        let parts = requestLine.split(separator: " ").map(String.init)
        guard parts.count >= 2 else { return HTTPResponse.badRequest }
        let method = parts[0]
        let path = parts[1].split(separator: "?").first.map(String.init) ?? parts[1]

        switch (method, path) {
        case ("GET", "/health"):
            return HTTPResponse.json(status: 200, body: ["status": "ok", "version": "0.1.0"])
        case ("GET", "/capabilities"):
            return HTTPResponse.json(status: 200, value: RemoteCapabilitiesResponse(
                version: "0.1.0",
                port: port,
                allowsLAN: appSettingsService.remoteControlAllowLAN,
                endpoints: [
                    "health",
                    "capabilities",
                    "project",
                    "runs",
                    "runs/{id}",
                    "runs/{id}/events",
                    "runs/{id}/stream",
                    "approvals",
                    "approvals/{id}/approve",
                    "approvals/{id}/reject",
                    "runs",
                    "runs/{id}/cancel"
                ]
            ))
        case ("GET", "/runs"):
            return HTTPResponse.json(status: 200, value: runRepository.runs)
        case ("GET", "/project"):
            return HTTPResponse.json(status: 200, value: projectService.currentProject)
        case ("GET", "/approvals"):
            return HTTPResponse.json(status: 200, value: approvalService.pendingRequests)
        default:
            if method == "GET", let runRequest = runRequest(path: path) {
                guard let run = runRepository.run(withId: runRequest.id) else {
                    return HTTPResponse.json(status: 404, body: ["error": "Run not found"])
                }
                if runRequest.eventsOnly {
                    return HTTPResponse.json(status: 200, value: run.events)
                }
                return HTTPResponse.json(status: 200, value: run)
            }
            if method == "POST", let approvalAction = approvalAction(path: path) {
                do {
                    if approvalAction.action == "approve" {
                        try approvalService.approve(requestId: approvalAction.id)
                    } else {
                        try approvalService.reject(requestId: approvalAction.id)
                    }
                    return HTTPResponse.json(status: 200, body: ["status": approvalAction.action])
                } catch {
                    return HTTPResponse.json(status: 404, body: ["error": error.localizedDescription])
                }
            }
            if method == "POST", path == "/runs" {
                guard let goal = startGoal(from: request), !goal.isEmpty else {
                    return HTTPResponse.json(status: 400, body: ["error": "A non-empty goal is required"])
                }
                Task { @MainActor [runService] in
                    _ = await runService.startRun(goal: goal, mode: .remoteTask)
                }
                return HTTPResponse.json(status: 202, body: ["status": "accepted"])
            }
            if method == "POST", let runId = runID(path: path), path.hasSuffix("/cancel") {
                guard runRepository.run(withId: runId) != nil else {
                    return HTTPResponse.json(status: 404, body: ["error": "Run not found"])
                }
                Task { @MainActor [runService] in
                    await runService.cancelRun(runId: runId)
                }
                return HTTPResponse.json(status: 202, body: ["status": "cancellation-requested"])
            }
            return HTTPResponse.json(status: 404, body: ["error": "Not found"])
        }
    }

    private func startGoal(from request: String) -> String? {
        guard let body = request.components(separatedBy: "\r\n\r\n").dropFirst().first,
              let data = body.data(using: .utf8),
              let payload = try? JSONDecoder().decode(RemoteStartRequest.self, from: data) else { return nil }
        return payload.goal.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func runID(path: String) -> UUID? {
        let components = path.split(separator: "/").map(String.init)
        guard components.count == 3, components[0] == "runs", components[2] == "cancel" else { return nil }
        return UUID(uuidString: components[1])
    }

    private func approvalAction(path: String) -> (id: UUID, action: String)? {
        let components = path.split(separator: "/").map(String.init)
        guard components.count == 3,
              components[0] == "approvals",
              let id = UUID(uuidString: components[1]),
              ["approve", "reject"].contains(components[2]) else { return nil }
        return (id, components[2])
    }

    private func runRequest(path: String) -> (id: UUID, eventsOnly: Bool)? {
        let components = path.split(separator: "/").map(String.init)
        guard (components.count == 2 || components.count == 3),
              components[0] == "runs",
              let id = UUID(uuidString: components[1]),
              components.count == 2 || components[2] == "events" else { return nil }
        return (id, components.count == 3)
    }

    nonisolated private static func makeListener(port: UInt16) -> NWListener {
        guard let listenerPort = NWEndpoint.Port(rawValue: port) else {
            preconditionFailure("Invalid remote control port: \(port)")
        }
        return try! NWListener(using: .tcp, on: listenerPort)
    }

    nonisolated private static func token(from configuredToken: String) -> String {
        if !configuredToken.isEmpty { return configuredToken }
        if let environmentToken = ProcessInfo.processInfo.environment["WORKHARNESS_REMOTE_TOKEN"], !environmentToken.isEmpty {
            return environmentToken
        }
        return UUID().uuidString.replacingOccurrences(of: "-", with: "")
    }
}

private enum HTTPResponse {
    static let badRequest = json(status: 400, body: ["error": "Bad request"])

    static func json(status: Int, body: [String: String]) -> Data {
        (try? jsonData(status: status, data: body)) ?? Data()
    }

    static func json<T: Encodable>(status: Int, value: T) -> Data {
        (try? jsonData(status: status, data: value)) ?? Data()
    }

    private static func jsonData<T: Encodable>(status: Int, data: T) throws -> Data {
        let body = try JSONEncoder().encode(data)
        let statusText = status == 200 ? "OK" : status == 202 ? "Accepted" : status == 401 ? "Unauthorized" : status == 404 ? "Not Found" : "Bad Request"
        let header = "HTTP/1.1 \(status) \(statusText)\r\nContent-Type: application/json\r\nContent-Length: \(body.count)\r\nConnection: close\r\n\r\n"
        return Data(header.utf8) + body
    }
}

private struct RemoteStartRequest: Decodable {
    let goal: String
}

private struct RemoteCapabilitiesResponse: Encodable {
    let version: String
    let port: UInt16
    let allowsLAN: Bool
    let endpoints: [String]
}
