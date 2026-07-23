//
// ClaudeMCPConfigurationFactory.swift
// WorkHarness
//
// Created by Auto (Codex) on 23.07.2026.
//

import Foundation

struct ClaudeMCPRunConfiguration: Equatable {
    let fileURL: URL
    let gatewayURL: URL
}

@MainActor
protocol ClaudeMCPConfigurationFactoryProtocol: AnyObject {
    func makeConfiguration(runId: UUID) throws -> ClaudeMCPRunConfiguration
    func removeConfiguration(at fileURL: URL)
}

@MainActor
final class ClaudeMCPConfigurationFactory: ClaudeMCPConfigurationFactoryProtocol {
    struct GatewaySettings {
        let baseURL: URL
        let authorizationToken: String?
    }

    private struct Configuration: Encodable {
        struct Server: Encodable {
            let type: String
            let url: String
            let headers: [String: String]?
        }

        let mcpServers: [String: Server]
    }

    private let fileManager: FileManager
    private let baseDirectoryURL: URL
    private let gatewaySettings: () -> GatewaySettings

    init(
        fileManager: FileManager = .default,
        baseDirectoryURL: URL? = nil,
        gatewayBaseURL: URL = URL(string: "http://127.0.0.1:8787")!,
        authorizationToken: String? = nil
    ) {
        self.fileManager = fileManager
        self.baseDirectoryURL = baseDirectoryURL
            ?? fileManager.temporaryDirectory.appendingPathComponent("WorkHarness/ClaudeMCP", isDirectory: true)
        self.gatewaySettings = {
            GatewaySettings(baseURL: gatewayBaseURL, authorizationToken: authorizationToken)
        }
    }

    init(
        fileManager: FileManager = .default,
        baseDirectoryURL: URL? = nil,
        gatewaySettings: @escaping () -> GatewaySettings
    ) {
        self.fileManager = fileManager
        self.baseDirectoryURL = baseDirectoryURL
            ?? fileManager.temporaryDirectory.appendingPathComponent("WorkHarness/ClaudeMCP", isDirectory: true)
        self.gatewaySettings = gatewaySettings
    }

    func makeConfiguration(runId: UUID) throws -> ClaudeMCPRunConfiguration {
        let runDirectoryURL = baseDirectoryURL
            .appendingPathComponent(runId.uuidString, isDirectory: true)
        try fileManager.createDirectory(
            at: runDirectoryURL,
            withIntermediateDirectories: true
        )

        let settings = gatewaySettings()
        let gatewayURL = settings.baseURL
            .appendingPathComponent("mcp")
            .appendingPathComponent("runs")
            .appendingPathComponent(runId.uuidString)
        let configuration = Configuration(mcpServers: [
            "workharness": Configuration.Server(
                type: "http",
                url: gatewayURL.absoluteString,
                headers: settings.authorizationToken.map { ["Authorization": "Bearer \($0)"] }
            )
        ])
        let data = try JSONEncoder().encode(configuration)
        let fileURL = runDirectoryURL.appendingPathComponent("\(UUID().uuidString).json")
        try data.write(to: fileURL, options: .atomic)
        return ClaudeMCPRunConfiguration(fileURL: fileURL, gatewayURL: gatewayURL)
    }

    func removeConfiguration(at fileURL: URL) {
        try? fileManager.removeItem(at: fileURL)
        let runDirectoryURL = fileURL.deletingLastPathComponent()
        if (try? fileManager.contentsOfDirectory(atPath: runDirectoryURL.path).isEmpty) == true {
            try? fileManager.removeItem(at: runDirectoryURL)
        }
    }
}
