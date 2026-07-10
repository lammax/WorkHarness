//
// ACPSubprocessTransport.swift
// WorkHarness
//
// Created by Auto (Codex) on 10.07.2026.
//

import Foundation

struct ACPSubprocessConfiguration: Equatable {
    var executableURL: URL
    var arguments: [String]
    var environment: [String: String]?
    var workingDirectoryURL: URL?

    init(
        executableURL: URL,
        arguments: [String] = [],
        environment: [String: String]? = nil,
        workingDirectoryURL: URL? = nil
    ) {
        self.executableURL = executableURL
        self.arguments = arguments
        self.environment = environment
        self.workingDirectoryURL = workingDirectoryURL
    }
}

@MainActor
final class ACPSubprocessTransport: ACPTransport {
    private let configuration: ACPSubprocessConfiguration

    init(configuration: ACPSubprocessConfiguration) {
        self.configuration = configuration
    }

    func connect() async throws -> ACPConnection {
        try ACPSubprocessConnection(configuration: configuration)
    }
}

@MainActor
final class ACPSubprocessConnection: ACPConnection {
    private let process: Process
    private let input: FileHandle
    private let output: FileHandle
    private var continuations: [UUID: AsyncThrowingStream<ACPEvent, Error>.Continuation] = [:]
    private var responseContinuations: [Int: CheckedContinuation<[String: Any], Error>] = [:]
    private var nextRequestID = 10
    private var isClosed = false

    init(configuration: ACPSubprocessConfiguration) throws {
        guard FileManager.default.isExecutableFile(atPath: configuration.executableURL.path) else {
            throw ACPError.transport("ACP executable was not found: \(configuration.executableURL.path)")
        }

        let inputPipe = Pipe()
        let outputPipe = Pipe()
        let process = Process()
        process.executableURL = configuration.executableURL
        process.arguments = configuration.arguments
        process.environment = configuration.environment
        process.currentDirectoryURL = configuration.workingDirectoryURL
        process.standardInput = inputPipe
        process.standardOutput = outputPipe
        process.standardError = FileHandle.standardError

        do {
            try process.run()
        } catch {
            throw ACPError.transport(error.localizedDescription)
        }

        self.process = process
        self.input = inputPipe.fileHandleForWriting
        self.output = outputPipe.fileHandleForReading
        self.output.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            Task { @MainActor [weak self] in
                self?.consume(data)
            }
        }
    }

    func send(_ message: ACPMessage) async throws {
        guard !isClosed else { throw ACPError.transport("ACP connection is closed.") }
        do {
            try input.write(contentsOf: ACPCodec.encode(message))
        } catch {
            throw ACPError.transport(error.localizedDescription)
        }
    }

    func request(method: String, params: [String: Any]) async throws -> [String: Any] {
        guard !isClosed else { throw ACPError.transport("ACP connection is closed.") }
        let id = nextRequestID
        nextRequestID += 1
        let object: [String: Any] = [
            "jsonrpc": "2.0",
            "id": id,
            "method": method,
            "params": params
        ]
        let data = try JSONSerialization.data(withJSONObject: object)

        return try await withCheckedThrowingContinuation { continuation in
            responseContinuations[id] = continuation
            do {
                try input.write(contentsOf: data + Data([0x0A]))
            } catch {
                responseContinuations.removeValue(forKey: id)
                continuation.resume(throwing: ACPError.transport(error.localizedDescription))
            }
        }
    }

    func events() -> AsyncThrowingStream<ACPEvent, Error> {
        AsyncThrowingStream { continuation in
            let subscriberId = UUID()
            self.continuations[subscriberId] = continuation
            continuation.onTermination = { @Sendable [weak self] _ in
                Task { @MainActor in
                    self?.continuations.removeValue(forKey: subscriberId)
                }
            }
        }
    }

    func close() async {
        guard !isClosed else { return }
        isClosed = true
        output.readabilityHandler = nil
        if process.isRunning {
            process.terminate()
        }
        try? input.close()
        try? output.close()
        continuations.values.forEach { $0.finish() }
        continuations.removeAll()
        responseContinuations.values.forEach { $0.resume(throwing: ACPError.transport("ACP connection closed.")) }
        responseContinuations.removeAll()
    }

    private func consume(_ data: Data) {
        guard let text = String(data: data, encoding: .utf8) else {
            continuations.values.forEach { $0.yield(with: .failure(ACPError.transport("ACP output was not UTF-8."))) }
            return
        }

        for line in text.split(whereSeparator: \.isNewline) {
            guard let data = line.data(using: .utf8),
                  let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }

            if let id = object["id"] as? Int {
                if let error = object["error"] as? [String: Any] {
                    let message = error["message"] as? String ?? "Unknown ACP error."
                    responseContinuations.removeValue(forKey: id)?.resume(throwing: ACPError.transport(message))
                } else {
                    let result = object["result"] as? [String: Any] ?? [:]
                    responseContinuations.removeValue(forKey: id)?.resume(returning: result)
                }
                continue
            }

            guard let event = try? ACPCodec.decodeEvent(from: data) else { continue }
            continuations.values.forEach { $0.yield(event) }
        }
    }
}

enum ACPCodec {
    static func encode(_ message: ACPMessage) throws -> Data {
        var data = try JSONEncoder().encode(message)
        data.append(0x0A)
        return data
    }

    static func decodeEvent(from data: Data) throws -> ACPEvent {
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let method = object["method"] as? String else {
            throw ACPError.transport("Invalid ACP event envelope.")
        }

        let params = object["params"] as? [String: Any] ?? [:]
        switch method {
        case "session/connected":
            let rawCapabilities = params["capabilities"] as? [String] ?? []
            let capabilities = AgentCapabilities(Set(rawCapabilities.compactMap(AgentCapability.init(rawValue:))))
            return .connected(capabilities)
        case "agent/started":
            return .started
        case "agent/thinking":
            return .thinking(string("message", from: params))
        case "message/delta":
            return .textDelta(string("text", from: params))
        case "message/completed":
            return .messageCompleted(string("message", from: params))
        case "tool/requested":
            return .toolCallRequested(name: string("name", from: params), input: string("input", from: params))
        case "file/changed":
            return .fileChanged(path: string("path", from: params))
        case "approval/requested":
            return .approvalRequested(summary: string("summary", from: params))
        case "session/request_permission":
            return .approvalRequested(summary: string("title", from: params))
        case "session/update":
            return try decodeSessionUpdate(params)
        case "session/finished":
            return .finished(AgentResponse(message: string("message", from: params), tokenUsage: nil, artifacts: []))
        case "session/failed":
            return .failed(string("message", from: params))
        default:
            throw ACPError.unsupported(method)
        }
    }

    private static func string(_ key: String, from params: [String: Any]) -> String {
        params[key] as? String ?? ""
    }

    private static func decodeSessionUpdate(_ params: [String: Any]) throws -> ACPEvent {
        let update = params["update"] as? [String: Any] ?? params
        switch update["sessionUpdate"] as? String {
        case "agent_message_chunk":
            let content = update["content"] as? [String: Any]
            return .textDelta(content?["text"] as? String ?? "")
        case "agent_thought_chunk":
            let content = update["content"] as? [String: Any]
            return .thinking(content?["text"] as? String ?? "")
        case "tool_call":
            return .toolCallRequested(
                name: update["title"] as? String ?? "tool",
                input: String(describing: update["rawInput"] ?? update["content"] ?? "")
            )
        case "tool_call_update":
            return .toolCallRequested(
                name: update["title"] as? String ?? "tool",
                input: String(describing: update["rawOutput"] ?? update["content"] ?? "")
            )
        default:
            throw ACPError.unsupported("session/update")
        }
    }
}
