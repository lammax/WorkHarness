//
// CLIAgentSubprocessTransport.swift
// WorkHarness
//
// Created by Auto (Codex) on 23.07.2026.
//

import Foundation

@MainActor
final class CLIAgentSubprocessTransport: CLIAgentProcessTransport {
    func start(_ configuration: CLIAgentProcessConfiguration) throws -> CLIAgentProcessSession {
        try validate(configuration)

        let process = Process()
        let inputPipe = Pipe()
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        var didFinish = false
        var isInputClosed = false
        var timeoutTask: Task<Void, Never>?
        var continuationReference: AsyncThrowingStream<CLIAgentProcessEvent, Error>.Continuation?
        var standardOutputDecoder = UTF8StreamDecoder()
        var standardErrorDecoder = UTF8StreamDecoder()

        process.executableURL = configuration.executableURL
        process.arguments = configuration.arguments
        process.environment = environment(overrides: configuration.environment)
        process.currentDirectoryURL = configuration.workingDirectoryURL
        process.standardInput = inputPipe
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        func finish(status: ProcessExitStatus, exitCode: Int32?) {
            guard !didFinish else { return }
            didFinish = true
            timeoutTask?.cancel()
            outputPipe.fileHandleForReading.readabilityHandler = nil
            errorPipe.fileHandleForReading.readabilityHandler = nil
            try? inputPipe.fileHandleForWriting.close()
            let remainingStandardOutput = standardOutputDecoder.finish()
            if !remainingStandardOutput.isEmpty {
                continuationReference?.yield(.stdout(remainingStandardOutput))
            }
            let remainingStandardError = standardErrorDecoder.finish()
            if !remainingStandardError.isEmpty {
                continuationReference?.yield(.stderr(remainingStandardError))
            }
            continuationReference?.yield(.finished(ProcessExit(status: status, exitCode: exitCode)))
            continuationReference?.finish()
        }

        let events = AsyncThrowingStream<CLIAgentProcessEvent, Error> { continuation in
            continuationReference = continuation

            outputPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                guard !data.isEmpty else { return }
                let output = standardOutputDecoder.decode(data)
                guard !output.isEmpty else { return }
                continuation.yield(.stdout(output))
            }

            errorPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                guard !data.isEmpty else { return }
                let output = standardErrorDecoder.decode(data)
                guard !output.isEmpty else { return }
                continuation.yield(.stderr(output))
            }

            process.terminationHandler = { process in
                Task { @MainActor in
                    let status: ProcessExitStatus = process.terminationStatus == 0 ? .succeeded : .failed
                    finish(status: status, exitCode: process.terminationStatus)
                }
            }

            continuation.onTermination = { _ in
                Task { @MainActor in
                    guard !didFinish, process.isRunning else { return }
                    process.terminate()
                }
            }
        }

        do {
            try process.run()
        } catch {
            throw CLIAgentProcessError.launchFailed(error.localizedDescription)
        }

        continuationReference?.yield(.started(ProcessStart(
            processIdentifier: process.processIdentifier,
            executablePath: configuration.executableURL.path,
            arguments: configuration.arguments
        )))

        if let timeout = configuration.timeout {
            timeoutTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                guard !Task.isCancelled, !didFinish else { return }
                if process.isRunning {
                    process.terminate()
                }
                finish(status: .timedOut, exitCode: nil)
            }
        }

        return CLIAgentProcessSession(
            events: events,
            writeHandler: { data in
                guard !didFinish, !isInputClosed else {
                    throw CLIAgentProcessError.inputClosed
                }
                do {
                    try inputPipe.fileHandleForWriting.write(contentsOf: data)
                } catch {
                    throw CLIAgentProcessError.inputWriteFailed(error.localizedDescription)
                }
            },
            closeInputHandler: {
                guard !isInputClosed else { return }
                isInputClosed = true
                try? inputPipe.fileHandleForWriting.close()
            },
            cancelHandler: {
                guard !didFinish else { return }
                if process.isRunning {
                    process.terminate()
                }
                finish(status: .cancelled, exitCode: nil)
            }
        )
    }

    private func validate(_ configuration: CLIAgentProcessConfiguration) throws {
        if let timeout = configuration.timeout, timeout <= 0 {
            throw CLIAgentProcessError.invalidTimeout(timeout)
        }
        guard FileManager.default.isExecutableFile(atPath: configuration.executableURL.path) else {
            throw CLIAgentProcessError.executableNotFound(configuration.executableURL.path)
        }
    }

    private func environment(overrides: [String: String]?) -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        if let overrides {
            environment.merge(overrides) { _, configured in configured }
        }

        let homeDirectory = FileManager.default.homeDirectoryForCurrentUser.path
        if environment["HOME"]?.isEmpty != false {
            environment["HOME"] = homeDirectory
        }
        let standardPath = "\(homeDirectory)/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        environment["PATH"] = [standardPath, environment["PATH"] ?? ""]
            .filter { !$0.isEmpty }
            .joined(separator: ":")
        return environment
    }
}
