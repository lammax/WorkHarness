//
// ACPAgentFactory.swift
// WorkHarness
//
// Created by Auto (Codex) on 10.07.2026.
//

import Foundation

struct ACPAgentDefinition: Equatable {
    var id: String
    var displayName: String
    var subprocess: ACPSubprocessConfiguration

    init(id: String, displayName: String, subprocess: ACPSubprocessConfiguration) {
        self.id = id
        self.displayName = displayName
        self.subprocess = subprocess
    }
}

@MainActor
final class ACPAgentFactory: AgentFactory {
    private let definition: ACPAgentDefinition

    init(definition: ACPAgentDefinition) {
        self.definition = definition
    }

    func makeRuntime() -> AgentRuntime {
        let transport = ACPSubprocessTransport(configuration: definition.subprocess)
        let client = ACPSubprocessClient(
            id: definition.id,
            displayName: definition.displayName,
            transport: transport,
            workingDirectory: definition.subprocess.workingDirectoryURL
        )
        return ACPClientRuntime(client: client)
    }
}

enum ACPAgentDefinitions {
    static func cursor() -> ACPAgentDefinition? {
        guard let executableURL = findExecutable(named: "cursor-agent") else { return nil }
        return ACPAgentDefinition(
            id: "cursor.acp",
            displayName: "Cursor ACP",
            subprocess: ACPSubprocessConfiguration(
                executableURL: executableURL,
                arguments: ["acp"]
            )
        )
    }

    private static func findExecutable(named name: String) -> URL? {
        let candidates = ProcessInfo.processInfo.environment["PATH"]?
            .split(separator: ":")
            .map { URL(fileURLWithPath: String($0)).appendingPathComponent(name) } ?? []
        let userHome = URL(fileURLWithPath: "/Users/\(NSUserName())")
        let fallbacks = [
            userHome.appendingPathComponent(".local/bin/\(name)"),
            URL(fileURLWithPath: "/opt/homebrew/bin/\(name)"),
            URL(fileURLWithPath: "/usr/local/bin/\(name)")
        ]

        let allCandidates = candidates + fallbacks
        return allCandidates.first(where: {
            FileManager.default.isExecutableFile(atPath: $0.path)
        }) ?? allCandidates.first(where: {
            FileManager.default.fileExists(atPath: $0.path)
        })
    }
}
