//
// CLIAgentProcessModels.swift
// WorkHarness
//
// Created by Auto (Codex) on 23.07.2026.
//

import Foundation

struct CLIAgentProcessConfiguration: Equatable {
    var executableURL: URL
    var arguments: [String]
    var environment: [String: String]?
    var workingDirectoryURL: URL?
    var timeout: TimeInterval?

    init(
        executableURL: URL,
        arguments: [String] = [],
        environment: [String: String]? = nil,
        workingDirectoryURL: URL? = nil,
        timeout: TimeInterval? = nil
    ) {
        self.executableURL = executableURL
        self.arguments = arguments
        self.environment = environment
        self.workingDirectoryURL = workingDirectoryURL
        self.timeout = timeout
    }
}

enum CLIAgentProcessEvent: Equatable {
    case started(ProcessStart)
    case stdout(String)
    case stderr(String)
    case finished(ProcessExit)
}

enum CLIAgentProcessError: LocalizedError, Equatable {
    case executableNotFound(String)
    case invalidTimeout(TimeInterval)
    case launchFailed(String)
    case inputClosed
    case inputWriteFailed(String)

    var errorDescription: String? {
        switch self {
        case .executableNotFound(let path):
            "CLI agent executable was not found: \(path)"
        case .invalidTimeout:
            "CLI agent timeout must be greater than zero."
        case .launchFailed(let message):
            "CLI agent failed to launch: \(message)"
        case .inputClosed:
            "CLI agent input is closed."
        case .inputWriteFailed(let message):
            "CLI agent input failed: \(message)"
        }
    }
}

@MainActor
protocol CLIAgentProcessTransport: AnyObject {
    func start(_ configuration: CLIAgentProcessConfiguration) throws -> CLIAgentProcessSession
}
