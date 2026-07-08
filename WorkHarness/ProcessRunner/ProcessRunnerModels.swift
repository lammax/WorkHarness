//
// ProcessRunnerModels.swift
// WorkHarness
//
// Created by Auto (Codex) on 08.07.2026.
//

import Foundation

struct ProcessRunRequest: Equatable {
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

enum ProcessRunEvent: Equatable {
    case started(ProcessStart)
    case stdout(String)
    case stderr(String)
    case finished(ProcessExit)
}

struct ProcessStart: Equatable {
    var processIdentifier: Int32
    var executablePath: String
    var arguments: [String]
}

struct ProcessExit: Equatable {
    var status: ProcessExitStatus
    var exitCode: Int32?
}

enum ProcessExitStatus: String, Codable, Equatable {
    case succeeded
    case failed
    case cancelled
    case timedOut
}

enum ProcessRunnerError: LocalizedError, Equatable {
    case executableNotFound(String)
    case launchFailed(String)
    case invalidTimeout(TimeInterval)

    var errorDescription: String? {
        switch self {
        case .executableNotFound(let path):
            "Executable was not found: \(path)"
        case .launchFailed(let message):
            "Process failed to launch: \(message)"
        case .invalidTimeout:
            "Timeout must be greater than zero."
        }
    }
}
