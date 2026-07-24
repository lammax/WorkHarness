//
// MCPServerProcessSupervisor.swift
// WorkHarness
//
// Created by Auto (Codex) on 23.07.2026.
//

import Foundation

@MainActor
protocol MCPServerProcessSupervisorProtocol: AnyObject {
    func ensureRunning(endpoint: URL) async throws
}

@MainActor
final class MCPServerProcessSupervisor: MCPServerProcessSupervisorProtocol {
    private let serverBasePath: () -> String
    private let session: URLSession
    private var processesByPort: [Int: Process] = [:]

    init(
        serverBasePath: @escaping () -> String,
        session: URLSession = .shared
    ) {
        self.serverBasePath = serverBasePath
        self.session = session
    }

    deinit {
        for process in processesByPort.values where process.isRunning {
            process.terminate()
        }
    }

    func ensureRunning(endpoint: URL) async throws {
        guard let port = endpoint.port,
              let executableName = Self.executableNamesByPort[port] else {
            throw MCPServerProcessSupervisorError.unknownEndpoint(endpoint.absoluteString)
        }
        if await isHealthy(endpoint: endpoint) {
            return
        }

        if processesByPort[port]?.isRunning != true {
            let executableURL = URL(fileURLWithPath: serverBasePath(), isDirectory: true)
                .appendingPathComponent(".build/debug", isDirectory: true)
                .appendingPathComponent(executableName)
            guard FileManager.default.isExecutableFile(atPath: executableURL.path) else {
                throw MCPServerProcessSupervisorError.executableNotFound(executableURL.path)
            }

            let process = Process()
            process.executableURL = executableURL
            process.currentDirectoryURL = executableURL
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent()
            process.environment = ProcessInfo.processInfo.environment.merging([
                "HOME": FileManager.default.homeDirectoryForCurrentUser.path
            ]) { current, _ in current }
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            try process.run()
            processesByPort[port] = process
        }

        for _ in 0..<Self.healthCheckAttempts {
            if await isHealthy(endpoint: endpoint) {
                return
            }
            try await Task.sleep(for: .milliseconds(Self.healthCheckDelayMilliseconds))
        }

        let process = processesByPort.removeValue(forKey: port)
        if process?.isRunning == true {
            process?.terminate()
        }
        throw MCPServerProcessSupervisorError.startupTimedOut(executableName)
    }

    private func isHealthy(endpoint: URL) async -> Bool {
        guard var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false) else {
            return false
        }
        components.path = "/health"
        guard let healthURL = components.url else {
            return false
        }

        var request = URLRequest(url: healthURL)
        request.timeoutInterval = 0.5
        do {
            let (_, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else { return false }
            return (200...299).contains(httpResponse.statusCode)
        } catch {
            return false
        }
    }

    private nonisolated static let healthCheckAttempts = 30
    private nonisolated static let healthCheckDelayMilliseconds = 100
    private nonisolated static let executableNamesByPort = [
        3003: "RAGMCPServer",
        3005: "FileOperationsMCPServer",
        3008: "DeveloperToolsMCPServer",
        3009: "MobileAutomationMCPServer"
    ]
}

private enum MCPServerProcessSupervisorError: LocalizedError {
    case unknownEndpoint(String)
    case executableNotFound(String)
    case startupTimedOut(String)

    var errorDescription: String? {
        switch self {
        case .unknownEndpoint(let endpoint):
            "No local MCP server is registered for endpoint: \(endpoint)"
        case .executableNotFound(let path):
            "MCP server executable was not found. Build MCP_server first: \(path)"
        case .startupTimedOut(let executable):
            "MCP server did not become ready: \(executable)"
        }
    }
}
